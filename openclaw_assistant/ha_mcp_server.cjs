#!/usr/bin/env node
"use strict";

const { McpServer } = require("@modelcontextprotocol/sdk/server/mcp.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const { z } = require("zod");

const SERVER_INFO = {
  name: "gitdakky-homeassistant",
  version: "0.7.2",
};

const HA_REST_BASE = process.env.HA_REST_BASE_URL || "http://supervisor/core/api";
const HA_WS_URL = process.env.HA_WS_URL || "ws://supervisor/core/websocket";
const SUPERVISOR_TOKEN = process.env.SUPERVISOR_TOKEN || "";
const WRITE_TOOLS_ENABLED = /^(1|true|yes|on)$/i.test(process.env.HA_WRITE_TOOLS_ENABLED || "false");
const DEFAULT_LIMIT = 200;

function requireSupervisorToken() {
  if (!SUPERVISOR_TOKEN) {
    throw new Error(
      "SUPERVISOR_TOKEN is not available. Built-in Home Assistant tools require Home Assistant add-on API access."
    );
  }
}

function boolToText(value) {
  return value ? "enabled" : "disabled";
}

function canonical(value) {
  return String(value ?? "").trim().toLowerCase();
}

function splitCsv(value) {
  if (!value) {
    return [];
  }
  if (Array.isArray(value)) {
    return value.flatMap((item) => splitCsv(item));
  }
  return String(value)
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function uniqueSorted(values) {
  return [...new Set(values.filter(Boolean))].sort((left, right) => left.localeCompare(right));
}

function limitResults(items, limit) {
  const safeLimit = Number.isInteger(limit) && limit > 0 ? Math.min(limit, 1000) : DEFAULT_LIMIT;
  return items.slice(0, safeLimit);
}

function textResponse(payload) {
  return {
    content: [
      {
        type: "text",
        text: typeof payload === "string" ? payload : JSON.stringify(payload, null, 2),
      },
    ],
  };
}

async function haFetch(path, options = {}) {
  requireSupervisorToken();
  const url = `${HA_REST_BASE}${path}`;
  const headers = {
    Authorization: `Bearer ${SUPERVISOR_TOKEN}`,
    ...options.headers,
  };
  if (options.body !== undefined && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }
  const response = await fetch(url, {
    method: options.method || "GET",
    headers,
    body: options.body,
  });
  const rawText = await response.text();
  if (!response.ok) {
    throw new Error(`Home Assistant API ${response.status} for ${path}: ${rawText || response.statusText}`);
  }
  if (!rawText) {
    return null;
  }
  const contentType = response.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return JSON.parse(rawText);
  }
  return rawText;
}

async function haWsCommand(type, payload = {}) {
  requireSupervisorToken();
  if (typeof WebSocket !== "function") {
    throw new Error("WebSocket support is unavailable in this Node runtime.");
  }

  return new Promise((resolve, reject) => {
    const requestId = 1;
    const socket = new WebSocket(HA_WS_URL);
    let settled = false;

    const finish = (callback, value) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeoutId);
      try {
        socket.close();
      } catch (_) {
        // Ignore close failures on already-closing sockets.
      }
      callback(value);
    };

    const timeoutId = setTimeout(() => {
      finish(reject, new Error(`Timed out waiting for Home Assistant websocket response for ${type}`));
    }, 10000);

    socket.addEventListener("error", (event) => {
      finish(reject, new Error(`Home Assistant websocket error for ${type}: ${event.message || "unknown error"}`));
    });

    socket.addEventListener("message", (event) => {
      let message;
      try {
        message = JSON.parse(event.data);
      } catch (error) {
        finish(reject, new Error(`Invalid Home Assistant websocket payload: ${error.message}`));
        return;
      }

      if (message.type === "auth_required") {
        socket.send(JSON.stringify({ type: "auth", access_token: SUPERVISOR_TOKEN }));
        return;
      }

      if (message.type === "auth_invalid") {
        finish(reject, new Error(`Home Assistant websocket authentication failed: ${message.message || "invalid token"}`));
        return;
      }

      if (message.type === "auth_ok") {
        socket.send(JSON.stringify({ id: requestId, type, ...payload }));
        return;
      }

      if (message.id !== requestId) {
        return;
      }

      if (message.success === false) {
        finish(reject, new Error(`Home Assistant websocket ${type} failed: ${message.error?.message || "unknown error"}`));
        return;
      }

      finish(resolve, message.result);
    });
  });
}

async function safeOptionalWsCommand(type) {
  try {
    return await haWsCommand(type);
  } catch (_) {
    return [];
  }
}

async function getStates() {
  return (await haFetch("/states")) || [];
}

async function getRegistries() {
  const [areas, devices, entities, labels, floors] = await Promise.all([
    haWsCommand("config/area_registry/list"),
    haWsCommand("config/device_registry/list"),
    haWsCommand("config/entity_registry/list"),
    safeOptionalWsCommand("config/label_registry/list"),
    safeOptionalWsCommand("config/floor_registry/list"),
  ]);

  return {
    areas: areas || [],
    devices: devices || [],
    entities: entities || [],
    labels: labels || [],
    floors: floors || [],
  };
}

function buildMaps(registries, states) {
  const areaById = new Map(registries.areas.map((area) => [area.area_id, area]));
  const deviceById = new Map(registries.devices.map((device) => [device.id, device]));
  const entityById = new Map(registries.entities.map((entity) => [entity.entity_id, entity]));
  const labelById = new Map(registries.labels.map((label) => [label.label_id, label]));
  const floorById = new Map(registries.floors.map((floor) => [floor.floor_id, floor]));
  const stateById = new Map(states.map((state) => [state.entity_id, state]));
  const entitiesByDeviceId = new Map();

  for (const entity of registries.entities) {
    if (!entity.device_id) {
      continue;
    }
    if (!entitiesByDeviceId.has(entity.device_id)) {
      entitiesByDeviceId.set(entity.device_id, []);
    }
    entitiesByDeviceId.get(entity.device_id).push(entity);
  }

  return {
    areaById,
    deviceById,
    entityById,
    labelById,
    floorById,
    stateById,
    entitiesByDeviceId,
  };
}

function resolveAreaId(areaFilter, maps) {
  if (!areaFilter) {
    return null;
  }
  const needle = canonical(areaFilter);
  for (const area of maps.areaById.values()) {
    if (canonical(area.area_id) === needle || canonical(area.name) === needle) {
      return area.area_id;
    }
  }
  return areaFilter;
}

function resolveLabelIds(labelFilter, maps) {
  const labels = splitCsv(labelFilter);
  if (labels.length === 0) {
    return [];
  }
  return labels.map((label) => {
    const needle = canonical(label);
    for (const item of maps.labelById.values()) {
      if (canonical(item.label_id) === needle || canonical(item.name) === needle) {
        return item.label_id;
      }
    }
    return label;
  });
}

function getEntityAreaId(entity, device) {
  return entity?.area_id || device?.area_id || null;
}

function getEntityAreaName(entity, device, maps) {
  const areaId = getEntityAreaId(entity, device);
  return areaId ? maps.areaById.get(areaId)?.name || null : null;
}

function getDeviceName(device) {
  return device?.name_by_user || device?.name || null;
}

function getEntityName(state, entity) {
  return (
    state?.attributes?.friendly_name ||
    entity?.name_by_user ||
    entity?.original_name ||
    entity?.entity_id ||
    null
  );
}

function labelNamesFromIds(labelIds, maps) {
  return uniqueSorted(splitCsv(labelIds).map((labelId) => maps.labelById.get(labelId)?.name || labelId));
}

function summarizeEntity(state, entity, maps) {
  const device = entity?.device_id ? maps.deviceById.get(entity.device_id) : null;
  return {
    entity_id: state?.entity_id || entity?.entity_id || null,
    domain: (state?.entity_id || entity?.entity_id || "").split(".")[0] || null,
    state: state?.state ?? null,
    friendly_name: getEntityName(state, entity),
    platform: entity?.platform || null,
    area_id: getEntityAreaId(entity, device),
    area_name: getEntityAreaName(entity, device, maps),
    device_id: entity?.device_id || null,
    device_name: getDeviceName(device),
    labels: labelNamesFromIds(entity?.labels, maps),
    last_changed: state?.last_changed ?? null,
    last_updated: state?.last_updated ?? null,
  };
}

function resolveEntityId(query, states, maps, domainFilter = null) {
  if (!query) {
    throw new Error("entity or entity_id is required.");
  }

  if (query.includes(".") && maps.stateById.has(query)) {
    return query;
  }

  const needle = canonical(query);
  const candidates = states.filter((state) => {
    if (domainFilter && !state.entity_id.startsWith(`${domainFilter}.`)) {
      return false;
    }
    const entity = maps.entityById.get(state.entity_id);
    return [
      state.entity_id,
      state.attributes?.friendly_name,
      entity?.name_by_user,
      entity?.original_name,
      entity?.entity_id,
    ].some((value) => canonical(value) === needle);
  });

  if (candidates.length === 1) {
    return candidates[0].entity_id;
  }

  if (candidates.length > 1) {
    throw new Error(`Multiple entities matched "${query}". Use an entity_id instead.`);
  }

  const fuzzyCandidates = states.filter((state) => {
    if (domainFilter && !state.entity_id.startsWith(`${domainFilter}.`)) {
      return false;
    }
    const entity = maps.entityById.get(state.entity_id);
    return [
      state.entity_id,
      state.attributes?.friendly_name,
      entity?.name_by_user,
      entity?.original_name,
      entity?.entity_id,
    ].some((value) => canonical(value).includes(needle));
  });

  if (fuzzyCandidates.length === 1) {
    return fuzzyCandidates[0].entity_id;
  }

  throw new Error(`No unique entity matched "${query}".`);
}

function resolveDevice(deviceQuery, maps) {
  if (!deviceQuery) {
    throw new Error("device or device_id is required.");
  }
  if (maps.deviceById.has(deviceQuery)) {
    return maps.deviceById.get(deviceQuery);
  }

  const needle = canonical(deviceQuery);
  const exact = [...maps.deviceById.values()].filter((device) =>
    [device.id, device.name_by_user, device.name, ...(device.identifiers || []).flat()].some(
      (value) => canonical(value) === needle
    )
  );
  if (exact.length === 1) {
    return exact[0];
  }
  if (exact.length > 1) {
    throw new Error(`Multiple devices matched "${deviceQuery}". Use a device_id instead.`);
  }

  const fuzzy = [...maps.deviceById.values()].filter((device) =>
    [device.id, device.name_by_user, device.name, ...(device.identifiers || []).flat()].some(
      (value) => canonical(value).includes(needle)
    )
  );
  if (fuzzy.length === 1) {
    return fuzzy[0];
  }
  throw new Error(`No unique device matched "${deviceQuery}".`);
}

function entityMatchesFilters(state, entity, maps, filters) {
  const device = entity?.device_id ? maps.deviceById.get(entity.device_id) : null;

  if (filters.domain) {
    const domain = (state?.entity_id || entity?.entity_id || "").split(".")[0];
    if (canonical(domain) !== canonical(filters.domain)) {
      return false;
    }
  }

  if (filters.integration) {
    if (canonical(entity?.platform) !== canonical(filters.integration)) {
      return false;
    }
  }

  if (filters.area_id) {
    if (getEntityAreaId(entity, device) !== filters.area_id) {
      return false;
    }
  }

  if (filters.device_id) {
    if (entity?.device_id !== filters.device_id) {
      return false;
    }
  }

  if (filters.label_ids.length > 0) {
    const entityLabels = new Set(splitCsv(entity?.labels));
    if (!filters.label_ids.every((labelId) => entityLabels.has(labelId))) {
      return false;
    }
  }

  if (filters.unavailable_only && state?.state !== "unavailable") {
    return false;
  }

  if (filters.search) {
    const haystack = [
      state?.entity_id,
      state?.attributes?.friendly_name,
      entity?.name_by_user,
      entity?.original_name,
      entity?.platform,
      getDeviceName(device),
      getEntityAreaName(entity, device, maps),
      ...labelNamesFromIds(entity?.labels, maps),
    ]
      .filter(Boolean)
      .join(" ");
    if (!canonical(haystack).includes(canonical(filters.search))) {
      return false;
    }
  }

  return true;
}

async function listEntities(args) {
  const [states, registries] = await Promise.all([getStates(), getRegistries()]);
  const maps = buildMaps(registries, states);
  const filters = {
    domain: args.domain || null,
    integration: args.integration || null,
    area_id: resolveAreaId(args.area, maps),
    device_id: args.device ? resolveDevice(args.device, maps).id : null,
    label_ids: resolveLabelIds(args.label, maps),
    search: args.search || null,
    unavailable_only: Boolean(args.unavailable_only),
  };

  const items = states
    .filter((state) => entityMatchesFilters(state, maps.entityById.get(state.entity_id), maps, filters))
    .map((state) => summarizeEntity(state, maps.entityById.get(state.entity_id), maps))
    .sort((left, right) => left.entity_id.localeCompare(right.entity_id));

  return {
    filters: {
      domain: filters.domain,
      integration: filters.integration,
      area: filters.area_id,
      device: filters.device_id,
      labels: filters.label_ids,
      unavailable_only: filters.unavailable_only,
      search: filters.search,
    },
    total: items.length,
    items: limitResults(items, args.limit),
  };
}

async function getEntity(args) {
  const [states, registries] = await Promise.all([getStates(), getRegistries()]);
  const maps = buildMaps(registries, states);
  const entityId = resolveEntityId(args.entity_id || args.entity, states, maps);
  const state = maps.stateById.get(entityId);
  if (!state) {
    throw new Error(`Entity ${entityId} was not found in Home Assistant state.`);
  }
  const entity = maps.entityById.get(entityId);
  const device = entity?.device_id ? maps.deviceById.get(entity.device_id) : null;
  return {
    entity: summarizeEntity(state, entity, maps),
    attributes: state.attributes || {},
    context: state.context || null,
    device: device
      ? {
          id: device.id,
          name: getDeviceName(device),
          manufacturer: device.manufacturer || null,
          model: device.model || null,
          area_id: device.area_id || null,
          area_name: device.area_id ? maps.areaById.get(device.area_id)?.name || null : null,
        }
      : null,
    registry: entity || null,
  };
}

async function listDevices(args) {
  const [states, registries] = await Promise.all([getStates(), getRegistries()]);
  const maps = buildMaps(registries, states);
  const targetAreaId = resolveAreaId(args.area, maps);
  const searchNeedle = canonical(args.search);
  const integrationNeedle = canonical(args.integration);

  const items = registries.devices
    .filter((device) => {
      if (targetAreaId && device.area_id !== targetAreaId) {
        return false;
      }
      if (args.manufacturer && canonical(device.manufacturer) !== canonical(args.manufacturer)) {
        return false;
      }
      if (args.model && canonical(device.model) !== canonical(args.model)) {
        return false;
      }

      const linkedEntities = maps.entitiesByDeviceId.get(device.id) || [];
      const platforms = uniqueSorted(linkedEntities.map((entity) => entity.platform));
      if (integrationNeedle && !platforms.some((platform) => canonical(platform) === integrationNeedle)) {
        return false;
      }

      if (searchNeedle) {
        const haystack = [
          device.id,
          getDeviceName(device),
          device.manufacturer,
          device.model,
          targetAreaId ? maps.areaById.get(targetAreaId)?.name : maps.areaById.get(device.area_id)?.name,
          ...platforms,
        ]
          .filter(Boolean)
          .join(" ");
        if (!canonical(haystack).includes(searchNeedle)) {
          return false;
        }
      }
      return true;
    })
    .map((device) => {
      const linkedEntities = (maps.entitiesByDeviceId.get(device.id) || []).map((entity) =>
        summarizeEntity(maps.stateById.get(entity.entity_id), entity, maps)
      );
      return {
        device_id: device.id,
        name: getDeviceName(device),
        manufacturer: device.manufacturer || null,
        model: device.model || null,
        area_id: device.area_id || null,
        area_name: device.area_id ? maps.areaById.get(device.area_id)?.name || null : null,
        floor_id: device.area_id ? maps.areaById.get(device.area_id)?.floor_id || null : null,
        floor_name: device.area_id
          ? maps.floorById.get(maps.areaById.get(device.area_id)?.floor_id || "")?.name || null
          : null,
        integration_platforms: uniqueSorted(linkedEntities.map((entity) => entity.platform)),
        entity_count: linkedEntities.length,
        unavailable_entities: linkedEntities.filter((entity) => entity.state === "unavailable").length,
      };
    })
    .sort((left, right) => (left.name || left.device_id).localeCompare(right.name || right.device_id));

  return {
    total: items.length,
    items: limitResults(items, args.limit),
  };
}

async function getDevice(args) {
  const [states, registries] = await Promise.all([getStates(), getRegistries()]);
  const maps = buildMaps(registries, states);
  const device = resolveDevice(args.device_id || args.device, maps);
  const linkedEntities = (maps.entitiesByDeviceId.get(device.id) || []).map((entity) => {
    const state = maps.stateById.get(entity.entity_id);
    return {
      ...summarizeEntity(state, entity, maps),
      attributes: state?.attributes || {},
    };
  });
  return {
    device: {
      id: device.id,
      name: getDeviceName(device),
      manufacturer: device.manufacturer || null,
      model: device.model || null,
      sw_version: device.sw_version || null,
      hw_version: device.hw_version || null,
      area_id: device.area_id || null,
      area_name: device.area_id ? maps.areaById.get(device.area_id)?.name || null : null,
      labels: labelNamesFromIds(device.labels, maps),
      identifiers: device.identifiers || [],
      connections: device.connections || [],
      config_entries: device.config_entries || [],
    },
    entities: linkedEntities.sort((left, right) => left.entity_id.localeCompare(right.entity_id)),
  };
}

async function listAutomations(args) {
  const states = await getStates();
  const automationStates = states
    .filter((state) => state.entity_id.startsWith("automation."))
    .filter((state) => {
      if (!args.search) {
        return true;
      }
      const haystack = [state.entity_id, state.attributes?.friendly_name, state.attributes?.id]
        .filter(Boolean)
        .join(" ");
      return canonical(haystack).includes(canonical(args.search));
    })
    .map((state) => ({
      entity_id: state.entity_id,
      state: state.state,
      friendly_name: state.attributes?.friendly_name || state.entity_id,
      id: state.attributes?.id || null,
      last_triggered: state.attributes?.last_triggered || null,
      mode: state.attributes?.mode || null,
      current: state.attributes?.current ?? null,
      last_changed: state.last_changed,
      last_updated: state.last_updated,
    }))
    .sort((left, right) => left.entity_id.localeCompare(right.entity_id));

  return {
    total: automationStates.length,
    items: limitResults(automationStates, args.limit),
  };
}

async function getAutomation(args) {
  const states = await getStates();
  const maps = buildMaps(
    {
      areas: [],
      devices: [],
      entities: [],
      labels: [],
      floors: [],
    },
    states
  );
  const entityId = resolveEntityId(args.entity_id || args.automation, states, maps, "automation");
  const state = states.find((item) => item.entity_id === entityId);
  if (!state) {
    throw new Error(`Automation ${entityId} was not found.`);
  }
  return {
    entity_id: state.entity_id,
    state: state.state,
    attributes: state.attributes || {},
    last_changed: state.last_changed,
    last_updated: state.last_updated,
    context: state.context || null,
  };
}

async function getHistory(args) {
  if (!args.entity_id) {
    throw new Error("entity_id is required for ha_history_get.");
  }

  const startTime = args.start_time || new Date(Date.now() - (args.hours || 6) * 60 * 60 * 1000).toISOString();
  const query = new URLSearchParams({
    filter_entity_id: args.entity_id,
    end_time: args.end_time || new Date().toISOString(),
  });
  if (args.minimal_response !== false) {
    query.set("minimal_response", "1");
  }
  const result = await haFetch(`/history/period/${encodeURIComponent(startTime)}?${query.toString()}`);
  return {
    entity_id: args.entity_id,
    start_time: startTime,
    end_time: query.get("end_time"),
    points: result,
  };
}

async function listServices(args) {
  const services = (await haFetch("/services")) || [];
  const filtered = services
    .filter((domainEntry) => {
      if (args.domain && canonical(domainEntry.domain) !== canonical(args.domain)) {
        return false;
      }
      return true;
    })
    .map((domainEntry) => ({
      domain: domainEntry.domain,
      services: Object.entries(domainEntry.services || {})
        .filter(([serviceName]) => !args.service || canonical(serviceName) === canonical(args.service))
        .map(([serviceName, serviceDef]) => ({
          service: serviceName,
          name: serviceDef.name || null,
          description: serviceDef.description || null,
          target: serviceDef.target || null,
          fields: serviceDef.fields || {},
        }))
        .sort((left, right) => left.service.localeCompare(right.service)),
    }))
    .filter((entry) => entry.services.length > 0)
    .sort((left, right) => left.domain.localeCompare(right.domain));

  return {
    total_domains: filtered.length,
    items: filtered,
  };
}

async function renderTemplate(args) {
  const result = await haFetch("/template", {
    method: "POST",
    body: JSON.stringify({
      template: args.template,
      variables: args.variables || {},
    }),
  });
  return {
    rendered: typeof result === "string" ? result : JSON.stringify(result),
  };
}

async function listAreas() {
  const registries = await getRegistries();
  return {
    total: registries.areas.length,
    items: registries.areas
      .map((area) => ({
        area_id: area.area_id,
        name: area.name,
        floor_id: area.floor_id || null,
      }))
      .sort((left, right) => left.name.localeCompare(right.name)),
  };
}

async function listLabels() {
  const registries = await getRegistries();
  return {
    total: registries.labels.length,
    items: registries.labels
      .map((label) => ({
        label_id: label.label_id,
        name: label.name,
        icon: label.icon || null,
        color: label.color || null,
      }))
      .sort((left, right) => left.name.localeCompare(right.name)),
  };
}

async function listFloors() {
  const registries = await getRegistries();
  return {
    total: registries.floors.length,
    items: registries.floors
      .map((floor) => ({
        floor_id: floor.floor_id,
        name: floor.name,
        level: floor.level ?? null,
      }))
      .sort((left, right) => left.name.localeCompare(right.name)),
  };
}

async function callService(args) {
  if (!WRITE_TOOLS_ENABLED) {
    throw new Error(
      "ha_service_call is disabled for this add-on install. Enable the Home Assistant option that allows service calls first."
    );
  }
  if (!args.confirmed) {
    throw new Error("ha_service_call requires confirmed=true after explicit user approval.");
  }

  const body = {
    ...(args.service_data || {}),
    ...(args.target ? { target: args.target } : {}),
  };
  const result = await haFetch(`/services/${encodeURIComponent(args.domain)}/${encodeURIComponent(args.service)}`, {
    method: "POST",
    body: JSON.stringify(body),
  });
  return {
    domain: args.domain,
    service: args.service,
    result,
  };
}

const server = new McpServer(SERVER_INFO, {
  capabilities: { logging: {} },
});

server.tool(
  "ha_entities_list",
  "List live Home Assistant entities and optionally filter by domain, area, device, integration, label, search text, or unavailable state.",
  {
    domain: z.string().optional(),
    area: z.string().optional(),
    device: z.string().optional(),
    integration: z.string().optional(),
    label: z.string().optional(),
    search: z.string().optional(),
    unavailable_only: z.boolean().optional(),
    limit: z.number().int().min(1).max(1000).optional(),
  },
  { title: "Home Assistant entities", readOnlyHint: true },
  async (args) => textResponse(await listEntities(args))
);

server.tool(
  "ha_entity_get",
  "Get the live state, attributes, timestamps, and related device metadata for one Home Assistant entity.",
  {
    entity_id: z.string().optional(),
    entity: z.string().optional(),
  },
  { title: "Home Assistant entity", readOnlyHint: true },
  async (args) => textResponse(await getEntity(args))
);

server.tool(
  "ha_devices_list",
  "List Home Assistant devices and optionally filter by area, manufacturer, model, integration platform, or search text.",
  {
    area: z.string().optional(),
    manufacturer: z.string().optional(),
    model: z.string().optional(),
    integration: z.string().optional(),
    search: z.string().optional(),
    limit: z.number().int().min(1).max(1000).optional(),
  },
  { title: "Home Assistant devices", readOnlyHint: true },
  async (args) => textResponse(await listDevices(args))
);

server.tool(
  "ha_device_get",
  "Get one Home Assistant device, its metadata, and all linked entities with current live state.",
  {
    device_id: z.string().optional(),
    device: z.string().optional(),
  },
  { title: "Home Assistant device", readOnlyHint: true },
  async (args) => textResponse(await getDevice(args))
);

server.tool(
  "ha_areas_list",
  "List Home Assistant areas with IDs and floor associations.",
  {},
  { title: "Home Assistant areas", readOnlyHint: true },
  async () => textResponse(await listAreas())
);

server.tool(
  "ha_labels_list",
  "List Home Assistant labels available for entity and device filtering.",
  {},
  { title: "Home Assistant labels", readOnlyHint: true },
  async () => textResponse(await listLabels())
);

server.tool(
  "ha_floors_list",
  "List Home Assistant floors when the current HA version exposes floor registry data.",
  {},
  { title: "Home Assistant floors", readOnlyHint: true },
  async () => textResponse(await listFloors())
);

server.tool(
  "ha_automations_list",
  "List Home Assistant automations with current state, last trigger time, and quick search.",
  {
    search: z.string().optional(),
    limit: z.number().int().min(1).max(1000).optional(),
  },
  { title: "Home Assistant automations", readOnlyHint: true },
  async (args) => textResponse(await listAutomations(args))
);

server.tool(
  "ha_automation_get",
  "Get one Home Assistant automation entity with its current attributes and timestamps.",
  {
    entity_id: z.string().optional(),
    automation: z.string().optional(),
  },
  { title: "Home Assistant automation", readOnlyHint: true },
  async (args) => textResponse(await getAutomation(args))
);

server.tool(
  "ha_history_get",
  "Get bounded history for one Home Assistant entity over a recent time window.",
  {
    entity_id: z.string(),
    hours: z.number().int().min(1).max(168).optional(),
    start_time: z.string().optional(),
    end_time: z.string().optional(),
    minimal_response: z.boolean().optional(),
  },
  { title: "Home Assistant history", readOnlyHint: true },
  async (args) => textResponse(await getHistory(args))
);

server.tool(
  "ha_services_list",
  "List Home Assistant services, optionally restricted to a domain or service name.",
  {
    domain: z.string().optional(),
    service: z.string().optional(),
  },
  { title: "Home Assistant services", readOnlyHint: true },
  async (args) => textResponse(await listServices(args))
);

server.tool(
  "ha_templates_render",
  "Render a Home Assistant Jinja template against the live Home Assistant runtime.",
  {
    template: z.string(),
    variables: z.record(z.any()).optional(),
  },
  { title: "Home Assistant template", readOnlyHint: true },
  async (args) => textResponse(await renderTemplate(args))
);

if (WRITE_TOOLS_ENABLED) {
  server.tool(
    "ha_service_call",
    "Call a Home Assistant service after explicit user approval. This tool is intentionally opt-in and requires confirmed=true.",
    {
      domain: z.string(),
      service: z.string(),
      service_data: z.record(z.any()).optional(),
      target: z.record(z.any()).optional(),
      confirmed: z.boolean(),
    },
    { title: "Home Assistant service call", readOnlyHint: false, destructiveHint: true },
    async (args) => textResponse(await callService(args))
  );
}

async function main() {
  if (process.argv.includes("--help")) {
    process.stdout.write(
      [
        "GitDakky Home Assistant MCP server",
        `HA rest base: ${HA_REST_BASE}`,
        `HA websocket: ${HA_WS_URL}`,
        `HA write tools: ${boolToText(WRITE_TOOLS_ENABLED)}`,
      ].join("\n") + "\n"
    );
    return;
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : String(error));
  process.exit(1);
});
