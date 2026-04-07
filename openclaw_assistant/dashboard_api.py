#!/usr/bin/env python3
"""Local dashboard API for the Home Assistant ingress page."""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
from collections import Counter
from datetime import datetime, timedelta, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import shutil
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlparse
from urllib.request import Request, urlopen

HOST = "127.0.0.1"
PORT = int(os.environ.get("OPENCLAW_DASHBOARD_API_PORT", "48110"))
WORKSPACE_DIR = Path(os.environ.get("OPENCLAW_WORKSPACE_DIR", "/config/clawd"))
SKILLS_DIR = Path(os.environ.get("OPENCLAW_SKILLS_DIR", "/config/.openclaw/skills"))
GRAPH_DB_PATH = Path(
    os.environ.get("OPENCLAW_SYSTEM_GRAPH_PATH", "/config/.openclaw/gitdakky-system-graph.sqlite3")
)
OPTIONS_FILE = Path(os.environ.get("OPENCLAW_OPTIONS_FILE", "/data/options.json"))
SECRETS_DIR = Path(os.environ.get("OPENCLAW_SECRETS_DIR", "/config/secrets"))
HA_CONFIG_DIR = Path(os.environ.get("HOME_ASSISTANT_CONFIG_DIR", "/ha-config"))
SUPERVISOR_CORE_API = os.environ.get("OPENCLAW_SUPERVISOR_CORE_API", "http://supervisor/core/api")
STALE_SECRET_DAYS = int(os.environ.get("OPENCLAW_STALE_SECRET_DAYS", "180"))
RECENT_CHANGE_HOURS = int(os.environ.get("OPENCLAW_RECENT_CHANGE_HOURS", "18"))
LOW_BATTERY_THRESHOLD = float(os.environ.get("OPENCLAW_LOW_BATTERY_THRESHOLD", "25"))

WORKSPACE_FILES = [
    "AGENTS.md",
    "BOOTSTRAP.md",
    "HEARTBEAT.md",
    "IDENTITY.md",
    "MEMORY.md",
    "SOUL.md",
    "TOOLS.md",
    "USER.md",
]

BUNDLED_SKILL_NAMES = [
    "ha-operator",
    "ha-automations",
    "ha-voice-assist",
    "ha-diagnostics",
    "ha-network-map",
    "ha-best-practices",
    "ha-research",
    "ha-file-access",
    "domotz-operator",
    "bacnet-scout",
    "mqtt-broker",
    "repo-issue-reporter",
]


def bool_env(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def load_addon_options() -> dict[str, Any]:
    if not OPTIONS_FILE.exists():
        return {}
    try:
        return json.loads(OPTIONS_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def read_preview(path: Path, max_chars: int = 1200) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")[:max_chars]


def run_json_command(command: list[str], timeout: int = 4) -> tuple[Any | None, str | None]:
    try:
        proc = subprocess.run(
            command,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except Exception as exc:  # pragma: no cover - defensive
        return None, str(exc)

    if proc.returncode != 0:
        error = proc.stderr.strip() or proc.stdout.strip() or f"exit {proc.returncode}"
        return None, error

    try:
        return json.loads(proc.stdout or "null"), None
    except json.JSONDecodeError as exc:
        return None, f"invalid JSON: {exc}"


def run_text_command(command: list[str], timeout: int = 4) -> tuple[str | None, str | None]:
    try:
        proc = subprocess.run(
            command,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except Exception as exc:  # pragma: no cover - defensive
        return None, str(exc)

    if proc.returncode != 0:
        error = proc.stderr.strip() or proc.stdout.strip() or f"exit {proc.returncode}"
        return None, error
    return (proc.stdout or "").strip(), None


def ha_api_get_json(path: str, timeout: int = 4) -> tuple[Any | None, str | None]:
    token = os.environ.get("SUPERVISOR_TOKEN", "").strip()
    if not token:
        return None, "SUPERVISOR_TOKEN unavailable"

    request = Request(
        f"{SUPERVISOR_CORE_API}{path}",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            raw = response.read().decode("utf-8")
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        return None, f"http {exc.code}: {detail or exc.reason}"
    except URLError as exc:
        return None, str(exc.reason)
    except Exception as exc:  # pragma: no cover - defensive
        return None, str(exc)

    try:
        return json.loads(raw or "null"), None
    except json.JSONDecodeError as exc:
        return None, f"invalid JSON: {exc}"


def fetch_homeassistant_states() -> tuple[list[dict[str, Any]], str | None]:
    data, error = ha_api_get_json("/states", timeout=6)
    if error:
        return [], error
    if not isinstance(data, list):
        return [], "unexpected Home Assistant states payload"
    return [item for item in data if isinstance(item, dict)], None


def system_ips() -> list[str]:
    output, error = run_text_command(["hostname", "-I"], timeout=2)
    if error or not output:
        return []
    return [token for token in output.split() if token]


def parse_timestamp(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def entity_domain(entity: dict[str, Any]) -> str:
    entity_id = str(entity.get("entity_id", ""))
    return entity_id.split(".", 1)[0] if "." in entity_id else ""


def friendly_name(entity: dict[str, Any]) -> str:
    return str(entity.get("attributes", {}).get("friendly_name") or entity.get("entity_id") or "unknown")


def display_state(entity: dict[str, Any]) -> str:
    state = str(entity.get("state", "")).replace("_", " ")
    attrs = entity.get("attributes", {})
    if entity_domain(entity) == "climate":
        hvac_action = str(attrs.get("hvac_action", "")).strip()
        if hvac_action:
            return f"{state} ({hvac_action.replace('_', ' ')})"
    return state


def parse_number(value: Any) -> float | None:
    try:
        if value is None:
            return None
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def format_age(when: datetime | None, now: datetime) -> str:
    if when is None:
        return "unknown"
    delta = max(now - when, timedelta())
    minutes = int(delta.total_seconds() // 60)
    if minutes < 60:
        return f"{minutes}m ago"
    hours = minutes // 60
    if hours < 48:
        return f"{hours}h ago"
    return f"{hours // 24}d ago"


def recent_changes(states: list[dict[str, Any]], now: datetime, limit: int = 4) -> list[str]:
    interesting_domains = {
        "alarm_control_panel",
        "binary_sensor",
        "climate",
        "cover",
        "device_tracker",
        "fan",
        "light",
        "lock",
        "person",
        "switch",
        "vacuum",
    }
    items: list[tuple[datetime, str]] = []
    cutoff = now - timedelta(hours=RECENT_CHANGE_HOURS)
    for entity in states:
        domain = entity_domain(entity)
        changed_at = parse_timestamp(str(entity.get("last_changed", "")))
        if domain not in interesting_domains or changed_at is None or changed_at < cutoff:
            continue
        state = str(entity.get("state", "")).lower()
        if state in {"unknown", "unavailable", ""}:
            continue
        items.append((changed_at, f"{friendly_name(entity)} is {display_state(entity)} ({format_age(changed_at, now)})"))
    items.sort(key=lambda item: item[0], reverse=True)
    return [text for _, text in items[:limit]]


def low_battery_entities(states: list[dict[str, Any]], threshold: float = LOW_BATTERY_THRESHOLD) -> list[tuple[float, str]]:
    matches: list[tuple[float, str]] = []
    for entity in states:
        domain = entity_domain(entity)
        attrs = entity.get("attributes", {})
        if domain not in {"sensor", "binary_sensor"}:
            continue
        device_class = str(attrs.get("device_class", "")).lower()
        entity_id = str(entity.get("entity_id", "")).lower()
        if device_class == "battery":
            value = parse_number(entity.get("state"))
            if value is not None and value <= threshold:
                matches.append((value, friendly_name(entity)))
        elif "battery" in entity_id and str(entity.get("state", "")).lower() in {"on", "low"}:
            matches.append((0.0, friendly_name(entity)))
    return sorted(matches, key=lambda item: item[0])


def top_power_entities(states: list[dict[str, Any]], limit: int = 4) -> list[tuple[float, str]]:
    matches: list[tuple[float, str]] = []
    for entity in states:
        if entity_domain(entity) != "sensor":
            continue
        attrs = entity.get("attributes", {})
        unit = str(attrs.get("unit_of_measurement", ""))
        device_class = str(attrs.get("device_class", "")).lower()
        if device_class != "power" and unit not in {"W", "kW"}:
            continue
        value = parse_number(entity.get("state"))
        if value is None:
            continue
        watts = value * 1000 if unit == "kW" else value
        if watts <= 50:
            continue
        matches.append((watts, friendly_name(entity)))
    matches.sort(key=lambda item: item[0], reverse=True)
    return matches[:limit]


def occupancy_summary(states: list[dict[str, Any]]) -> str | None:
    people = [entity for entity in states if entity_domain(entity) == "person"]
    if people:
        home_count = sum(1 for entity in people if str(entity.get("state", "")).lower() == "home")
        if home_count == 0:
            return "Nobody appears to be home."
        return f"{home_count} tracked person{'s are' if home_count != 1 else ' is'} home."

    occupancy = [
        entity
        for entity in states
        if entity_domain(entity) == "binary_sensor"
        and str(entity.get("attributes", {}).get("device_class", "")).lower() in {"occupancy", "motion", "presence"}
    ]
    if occupancy:
        active = sum(1 for entity in occupancy if str(entity.get("state", "")).lower() == "on")
        if active == 0:
            return "No occupancy sensors are active right now."
        return f"{active} occupancy or motion sensor{'s are' if active != 1 else ' is'} active."
    return None


def weather_summary(states: list[dict[str, Any]]) -> str | None:
    for entity in states:
        if entity_domain(entity) != "weather":
            continue
        temperature = parse_number(entity.get("attributes", {}).get("temperature"))
        if temperature is not None:
            return f"{friendly_name(entity)} reports {temperature:g} degrees."
    return None


def tariff_summary(states: list[dict[str, Any]]) -> str | None:
    for entity in states:
        if entity_domain(entity) != "sensor":
            continue
        entity_id = str(entity.get("entity_id", "")).lower()
        attrs = entity.get("attributes", {})
        unit = str(attrs.get("unit_of_measurement", "")).lower()
        if not any(token in entity_id for token in {"tariff", "rate", "price"}):
            continue
        if "kwh" not in unit and "wh" not in unit:
            continue
        value = parse_number(entity.get("state"))
        if value is not None:
            return f"{friendly_name(entity)} is {value:g} {attrs.get('unit_of_measurement', '')}".strip()
    return None


def unavailable_entities(states: list[dict[str, Any]], limit: int = 5) -> tuple[int, list[str]]:
    broken = [entity for entity in states if str(entity.get("state", "")).lower() in {"unknown", "unavailable"}]
    highlights = [friendly_name(entity) for entity in broken[:limit]]
    return len(broken), highlights


def disabled_automations(states: list[dict[str, Any]], limit: int = 5) -> list[str]:
    disabled = [
        friendly_name(entity)
        for entity in states
        if entity_domain(entity) == "automation" and str(entity.get("state", "")).lower() == "off"
    ]
    return disabled[:limit]


def recent_attention_entities(states: list[dict[str, Any]], now: datetime, limit: int = 4) -> list[str]:
    interesting_classes = {"connectivity", "problem"}
    cutoff = now - timedelta(hours=24)
    findings: list[tuple[datetime, str]] = []
    for entity in states:
        if entity_domain(entity) != "binary_sensor":
            continue
        device_class = str(entity.get("attributes", {}).get("device_class", "")).lower()
        changed_at = parse_timestamp(str(entity.get("last_changed", "")))
        if device_class not in interesting_classes or changed_at is None or changed_at < cutoff:
            continue
        findings.append((changed_at, f"{friendly_name(entity)} last changed {format_age(changed_at, now)}"))
    findings.sort(key=lambda item: item[0], reverse=True)
    return [text for _, text in findings[:limit]]


def available_updates(states: list[dict[str, Any]], limit: int = 4) -> list[str]:
    pending = [
        friendly_name(entity)
        for entity in states
        if entity_domain(entity) == "update" and str(entity.get("state", "")).lower() == "on"
    ]
    return pending[:limit]


def secret_age_findings(secret_dir: Path, now: datetime, stale_days: int = STALE_SECRET_DAYS) -> list[str]:
    findings: list[str] = []
    if not secret_dir.exists():
        return findings
    cutoff = now - timedelta(days=stale_days)
    for path in sorted(secret_dir.glob("*")):
        if not path.is_file():
            continue
        modified = datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc)
        if modified <= cutoff:
            findings.append(f"{path.name} last changed {format_age(modified, now)}")
    return findings


def disk_summary() -> tuple[int, str]:
    target = "/config" if Path("/config").exists() else str(Path.cwd())
    usage = shutil.disk_usage(target)
    pct = int((usage.used / usage.total) * 100) if usage.total else 0
    free_gb = usage.free / (1024 ** 3)
    return pct, f"{free_gb:.1f} GB free"


def insight_card(
    title: str,
    summary: str,
    status: str,
    pills: list[str] | None = None,
    highlights: list[str] | None = None,
    actions: list[str] | None = None,
) -> dict[str, Any]:
    return {
        "title": title,
        "summary": summary,
        "status": status,
        "pills": pills or [],
        "highlights": highlights or [],
        "actions": actions or [],
    }


def generate_insights(
    states: list[dict[str, Any]],
    options: dict[str, Any],
    schedule: dict[str, Any] | None = None,
    *,
    states_error: str | None = None,
    now: datetime | None = None,
    secret_dir: Path = SECRETS_DIR,
) -> dict[str, Any]:
    now = now or datetime.now(timezone.utc)
    schedule = schedule or {}

    if states_error:
        unavailable_card = insight_card(
            "Homeowner Summary",
            f"Home Assistant state snapshot unavailable: {states_error}",
            "off",
            actions=["Check add-on API access and confirm Home Assistant is reachable from the add-on."],
        )
        return {
            "homeowner": unavailable_card,
            "energy": insight_card("Energy", unavailable_card["summary"], "off", actions=unavailable_card["actions"]),
            "system": insight_card("System", unavailable_card["summary"], "off", actions=unavailable_card["actions"]),
            "maintenance": insight_card("Maintenance", unavailable_card["summary"], "off", actions=unavailable_card["actions"]),
            "security": build_security_insight(options, now, secret_dir),
        }

    recent = recent_changes(states, now)
    unavailable_count, unavailable_names = unavailable_entities(states)
    batteries = low_battery_entities(states)
    top_power = top_power_entities(states)
    occupancy = occupancy_summary(states)
    weather = weather_summary(states)
    tariff = tariff_summary(states)
    disabled = disabled_automations(states)
    updates = available_updates(states)
    attention = recent_attention_entities(states, now)
    disk_pct, disk_text = disk_summary()
    cron_error = schedule.get("cronStatus", {}).get("error")

    homeowner_highlights = recent[:2]
    if unavailable_count:
        homeowner_highlights.append(
            f"{unavailable_count} entity{'ies are' if unavailable_count != 1 else ' is'} unavailable or unknown."
        )
    if top_power:
        watts, name = top_power[0]
        homeowner_highlights.append(f"Highest live power draw: {name} at about {watts:.0f} W.")
    homeowner_actions: list[str] = []
    if batteries:
        homeowner_actions.append("Create or tune low-battery notifications before the next failure window.")
    if top_power:
        homeowner_actions.append("Review whether the highest current loads need schedule or occupancy-based control.")
    if unavailable_count:
        homeowner_actions.append("Fix unavailable entities before building new automations on top of them.")
    if not homeowner_actions:
        homeowner_actions.append("Snapshot looks stable; the next useful step is a daily summary automation.")
    homeowner_summary = (
        "Recent state changes, oddities, and high-load devices are summarized here so the house does not feel like a raw telemetry dump."
    )

    energy_highlights = []
    if occupancy:
        energy_highlights.append(occupancy)
    if weather:
        energy_highlights.append(weather)
    if tariff:
        energy_highlights.append(tariff)
    energy_highlights.extend([f"{name}: {watts:.0f} W" for watts, name in top_power[:3]])
    energy_actions: list[str] = []
    if top_power and occupancy and "Nobody appears to be home" in occupancy:
        energy_actions.append("Review whether away-mode automations should shut down the current discretionary loads.")
    if top_power:
        energy_actions.append("Use the top live loads as the first candidates for tariff-aware or occupancy-aware scheduling.")
    if tariff:
        energy_actions.append("Compare current tariff sensors with the biggest live loads before automating schedule shifts.")
    elif top_power:
        energy_actions.append("If you track tariff sensors, connect them to these live loads before enabling automation.")
    if weather:
        energy_actions.append("Use weather context to decide whether climate pre-heating or pre-cooling should move to cheaper periods.")
    if not energy_actions:
        energy_actions.append("Expose power, tariff, or weather entities first if you want stronger energy recommendations.")

    system_highlights = []
    if unavailable_count:
        system_highlights.append(f"Unavailable entities: {', '.join(unavailable_names[:3])}")
    if disabled:
        system_highlights.append(f"Disabled automations: {', '.join(disabled[:3])}")
    if cron_error:
        system_highlights.append(f"Cron scheduler error: {cron_error}")
    system_highlights.append(f"Add-on disk usage: {disk_pct}% used ({disk_text})")
    system_actions: list[str] = []
    if unavailable_count:
        system_actions.append("Audit unavailable entities and broken integrations before expanding automations.")
    if disabled:
        system_actions.append("Confirm disabled automations are intentional and not quiet regressions.")
    if cron_error:
        system_actions.append("Inspect cron visibility before relying on scheduled automations.")
    if disk_pct >= 85:
        system_actions.append("Run oc-cleanup before the next image update or rebuild.")
    if not system_actions:
        system_actions.append("System looks operationally quiet; keep watching for disabled automations and dead entities.")

    maintenance_highlights = [f"{name}: {value:.0f}%" for value, name in batteries[:4]]
    maintenance_highlights.extend(updates[:2])
    maintenance_highlights.extend(attention[:2])
    maintenance_actions: list[str] = []
    if batteries:
        maintenance_actions.append("Prioritize battery replacements for the lowest remaining sensors first.")
    if updates:
        maintenance_actions.append("Review pending firmware or integration updates before they stack up.")
    if attention:
        maintenance_actions.append("Investigate recently flipping connectivity or problem sensors for early failure signs.")
    if not maintenance_actions:
        maintenance_actions.append("No obvious maintenance pressure is visible from the current Home Assistant snapshot.")

    return {
        "homeowner": insight_card(
            "Homeowner Summary",
            homeowner_summary,
            "warn" if unavailable_count or top_power else "good",
            pills=[
                f"{len(recent)} recent change{'s' if len(recent) != 1 else ''}",
                f"{unavailable_count} odd signal{'s' if unavailable_count != 1 else ''}",
                f"{len(homeowner_actions)} next step{'s' if len(homeowner_actions) != 1 else ''}",
            ],
            highlights=homeowner_highlights[:4],
            actions=homeowner_actions[:3],
        ),
        "energy": insight_card(
            "Energy",
            "A bounded read-only energy view that combines live loads with occupancy, weather, and tariff hints where available.",
            "warn" if top_power else "off",
            pills=[
                f"{len(top_power)} active load{'s' if len(top_power) != 1 else ''}",
                "occupancy visible" if occupancy else "occupancy missing",
                "tariff visible" if tariff else "tariff missing",
            ],
            highlights=energy_highlights[:4],
            actions=energy_actions[:3],
        ),
        "system": insight_card(
            "System",
            "Read-only operational drift signals from Home Assistant and the add-on runtime.",
            "warn" if unavailable_count or disabled or cron_error or disk_pct >= 85 else "good",
            pills=[
                f"{unavailable_count} unavailable",
                f"{len(disabled)} automation{'s' if len(disabled) != 1 else ''} off",
                f"disk {disk_pct}%",
            ],
            highlights=system_highlights[:4],
            actions=system_actions[:3],
        ),
        "maintenance": insight_card(
            "Predictive Maintenance",
            "Battery decline, update backlog, and unstable sensors are surfaced first so maintenance stays ahead of failure.",
            "warn" if batteries or updates or attention else "good",
            pills=[
                f"{len(batteries)} low battery",
                f"{len(updates)} update{'s' if len(updates) != 1 else ''}",
                f"{len(attention)} unstable signal{'s' if len(attention) != 1 else ''}",
            ],
            highlights=maintenance_highlights[:4],
            actions=maintenance_actions[:3],
        ),
        "security": build_security_insight(options, now, secret_dir),
    }


def build_security_insight(options: dict[str, Any], now: datetime, secret_dir: Path) -> dict[str, Any]:
    findings: list[str] = []
    actions: list[str] = []

    access_mode = str(options.get("access_mode", "custom"))
    auth_mode = str(options.get("gateway_auth_mode", "token"))
    public_url = str(options.get("gateway_public_url", "")).strip()
    trusted_proxies = str(options.get("gateway_trusted_proxies", "")).strip()

    if public_url.startswith("http://"):
        findings.append("gateway_public_url uses plain HTTP for the browser-facing control path.")
        actions.append("Move the browser-facing gateway URL to HTTPS before exposing it beyond localhost.")
    if access_mode == "lan_reverse_proxy" and auth_mode == "trusted-proxy" and not trusted_proxies:
        findings.append("trusted-proxy mode is enabled without any trusted proxy CIDRs or IPs.")
        actions.append("Set gateway_trusted_proxies so only the intended reverse proxy can inject identity headers.")
    if bool(options.get("enable_ha_service_calls", False)):
        findings.append("The mutating ha_service_call tool is enabled.")
        actions.append("Keep Home Assistant write tools behind explicit user approval and review prompts.")
    if bool(options.get("disable_exec_approvals", True)):
        findings.append("Host exec approvals are disabled for unattended automation.")
        actions.append("Use unattended exec only on trusted installs where the safety tradeoff is intentional.")

    stale_secrets = secret_age_findings(secret_dir, now)
    if stale_secrets:
        findings.extend([f"Secret rotation candidate: {item}" for item in stale_secrets[:3]])
        actions.append("Rotate the oldest stored secrets if they no longer match your current trust boundary.")
    if bool(options.get("matrix_allow_private_network", False)):
        findings.append("Matrix private-network access is enabled for a self-hosted homeserver path.")

    if not findings:
        findings.append("No obvious operator-side exposure flags are visible from the current add-on settings.")

    return insight_card(
        "Security",
        "Plain-language exposure checks from add-on settings, secret age, and write-capable surfaces.",
        "warn" if len(findings) > 1 or stale_secrets else "good",
        pills=[
            f"{len(findings)} finding{'s' if len(findings) != 1 else ''}",
            f"auth {auth_mode}",
            access_mode or "access unset",
        ],
        highlights=findings[:5],
        actions=actions[:3] or ["Revisit this card after changing auth, proxy, or write-capable options."],
    )


def ensure_graph_db() -> None:
    GRAPH_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(GRAPH_DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS nodes (
              id INTEGER PRIMARY KEY,
              kind TEXT NOT NULL,
              name TEXT NOT NULL UNIQUE,
              label TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS edges (
              id INTEGER PRIMARY KEY,
              source_name TEXT NOT NULL,
              relation TEXT NOT NULL,
              target_name TEXT NOT NULL,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL,
              UNIQUE(source_name, relation, target_name)
            )
            """
        )
        conn.commit()


def upsert_node(conn: sqlite3.Connection, kind: str, name: str, label: str, metadata: dict[str, Any]) -> None:
    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        INSERT INTO nodes (kind, name, label, metadata_json, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(name) DO UPDATE SET
          kind=excluded.kind,
          label=excluded.label,
          metadata_json=excluded.metadata_json,
          updated_at=excluded.updated_at
        """,
        (kind, name, label, json.dumps(metadata, sort_keys=True), now),
    )


def upsert_edge(conn: sqlite3.Connection, source: str, relation: str, target: str, metadata: dict[str, Any] | None = None) -> None:
    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        INSERT INTO edges (source_name, relation, target_name, metadata_json, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(source_name, relation, target_name) DO UPDATE SET
          metadata_json=excluded.metadata_json,
          updated_at=excluded.updated_at
        """,
        (source, relation, target, json.dumps(metadata or {}, sort_keys=True), now),
    )


def refresh_graph_snapshot() -> dict[str, Any]:
    ensure_graph_db()
    with sqlite3.connect(GRAPH_DB_PATH) as conn:
        upsert_node(
            conn,
            "service",
            "openclaw-super-home-assistant",
            "OpenClaw Super Home Assistant",
            {
                "bundledVersion": os.environ.get("OPENCLAW_BUNDLED_VERSION", "unknown"),
                "gatewayMode": os.environ.get("GATEWAY_MODE", ""),
                "accessMode": os.environ.get("ACCESS_MODE", ""),
            },
        )
        upsert_node(conn, "workspace", str(WORKSPACE_DIR), "OpenClaw Workspace", {"path": str(WORKSPACE_DIR)})
        upsert_edge(conn, "openclaw-super-home-assistant", "uses_workspace", str(WORKSPACE_DIR))
        upsert_node(
            conn,
            "config-root",
            str(HA_CONFIG_DIR),
            "Home Assistant Config Root",
            {
                "path": str(HA_CONFIG_DIR),
                "mounted": HA_CONFIG_DIR.exists(),
                "configurationPath": str(HA_CONFIG_DIR / "configuration.yaml"),
                "storagePath": str(HA_CONFIG_DIR / ".storage"),
            },
        )
        upsert_edge(conn, "openclaw-super-home-assistant", "can_access_home_assistant_config", str(HA_CONFIG_DIR))

        for ip in system_ips():
            node_name = f"ip:{ip}"
            upsert_node(conn, "ip", node_name, ip, {"address": ip})
            upsert_edge(conn, "openclaw-super-home-assistant", "has_ip", node_name)

        integrations = [
            ("context7", bool_env("CONTEXT7_ENABLED"), {"configured": bool_env("CONTEXT7_ENABLED")}),
            (
                "domotz",
                bool_env("DOMOTZ_ENABLED"),
                {"configured": bool_env("DOMOTZ_ENABLED"), "siteId": os.environ.get("DOMOTZ_SITE_ID", "")},
            ),
            (
                "matrix",
                bool_env("MATRIX_ENABLED"),
                {
                    "configured": bool_env("MATRIX_ENABLED"),
                    "homeserver": os.environ.get("MATRIX_HOMESERVER", ""),
                    "userId": os.environ.get("MATRIX_USER_ID", ""),
                },
            ),
            (
                "mqtt",
                bool_env("MQTT_ENABLED"),
                {"configured": bool_env("MQTT_ENABLED"), "brokerUrl": os.environ.get("MQTT_BROKER_URL", "")},
            ),
            (
                "github-issues",
                bool_env("GITHUB_ISSUES_ENABLED"),
                {"configured": bool_env("GITHUB_ISSUES_ENABLED"), "repo": os.environ.get("GITDAKKY_ISSUES_REPO", "")},
            ),
            ("bacnet", bool_env("BACNET_SCOUT_ENABLED"), {"configured": bool_env("BACNET_SCOUT_ENABLED")}),
            (
                "home-assistant-mcp",
                bool_env("HA_MCP_ENABLED"),
                {"configured": bool_env("HA_MCP_ENABLED")},
            ),
        ]
        for name, configured, metadata in integrations:
            upsert_node(conn, "integration", name, name.replace("-", " ").title(), metadata)
            if configured:
                upsert_edge(conn, "openclaw-super-home-assistant", "uses_integration", name)

        conn.commit()
        node_count = conn.execute("SELECT COUNT(*) FROM nodes").fetchone()[0]
        edge_count = conn.execute("SELECT COUNT(*) FROM edges").fetchone()[0]

    return {
        "path": str(GRAPH_DB_PATH),
        "exists": GRAPH_DB_PATH.exists(),
        "nodeCount": node_count,
        "edgeCount": edge_count,
    }


def workspace_entries() -> list[dict[str, Any]]:
    entries = []
    for name in WORKSPACE_FILES:
        path = WORKSPACE_DIR / name
        entries.append(
            {
                "key": f"workspace:{name}",
                "name": name,
                "path": str(path),
                "exists": path.exists(),
                "preview": read_preview(path),
                "size": path.stat().st_size if path.exists() else 0,
            }
        )
    return entries


def skill_entries() -> list[dict[str, Any]]:
    entries = []
    for name in BUNDLED_SKILL_NAMES:
        path = SKILLS_DIR / name / "SKILL.md"
        entries.append(
            {
                "key": f"skill:{name}",
                "name": name,
                "path": str(path),
                "exists": path.exists(),
                "preview": read_preview(path, max_chars=800),
                "size": path.stat().st_size if path.exists() else 0,
            }
        )
    return entries


def integration_status() -> dict[str, Any]:
    return {
        "context7": {
            "configured": bool_env("CONTEXT7_ENABLED"),
            "secretPath": "/config/secrets/context7.api_key",
        },
        "domotz": {
            "configured": bool_env("DOMOTZ_ENABLED"),
            "siteId": os.environ.get("DOMOTZ_SITE_ID", ""),
            "secretPath": "/config/secrets/domotz.api_key",
        },
        "matrix": {
            "configured": bool_env("MATRIX_ENABLED"),
            "homeserver": os.environ.get("MATRIX_HOMESERVER", ""),
            "userId": os.environ.get("MATRIX_USER_ID", ""),
            "accessTokenConfigured": bool_env("MATRIX_ACCESS_TOKEN_CONFIGURED"),
            "passwordConfigured": bool_env("MATRIX_PASSWORD_CONFIGURED"),
            "dmPolicy": os.environ.get("MATRIX_DM_POLICY", ""),
            "groupPolicy": os.environ.get("MATRIX_GROUP_POLICY", ""),
            "autoJoin": os.environ.get("MATRIX_AUTO_JOIN", ""),
            "secretPaths": [
                "/config/secrets/matrix.access_token",
                "/config/secrets/matrix.password",
            ],
        },
        "mqtt": {
            "configured": bool_env("MQTT_ENABLED"),
            "brokerUrl": os.environ.get("MQTT_BROKER_URL", ""),
            "usernameConfigured": bool_env("MQTT_USERNAME_CONFIGURED"),
            "passwordConfigured": bool_env("MQTT_PASSWORD_CONFIGURED"),
            "secretPaths": [
                "/config/secrets/mqtt.broker_url",
                "/config/secrets/mqtt.username",
                "/config/secrets/mqtt.password",
            ],
        },
        "githubIssues": {
            "configured": bool_env("GITHUB_ISSUES_ENABLED"),
            "repo": os.environ.get("GITDAKKY_ISSUES_REPO", "GitDakky/OpenClawHomeAssistant"),
            "secretPath": "/config/secrets/github_issues.token",
            "command": "oc-report-issue",
        },
        "bacnet": {
            "configured": bool_env("BACNET_SCOUT_ENABLED"),
            "notes": "Opt-in BACnet discovery scaffolding is enabled when the add-on option is on.",
        },
        "homeAssistantMcp": {
            "configured": bool_env("HA_MCP_ENABLED"),
            "tokenPath": "/config/secrets/homeassistant.token",
        },
        "homeAssistantConfig": {
            "configured": HA_CONFIG_DIR.exists(),
            "mountPath": str(HA_CONFIG_DIR),
            "configurationPath": str(HA_CONFIG_DIR / "configuration.yaml"),
            "storagePath": str(HA_CONFIG_DIR / ".storage"),
            "customComponentsPath": str(HA_CONFIG_DIR / "custom_components"),
            "packagesPath": str(HA_CONFIG_DIR / "packages"),
        },
    }


def schedule_state() -> dict[str, Any]:
    cron_status, cron_status_error = run_json_command(["openclaw", "cron", "status", "--json"])
    cron_jobs, cron_jobs_error = run_json_command(["openclaw", "cron", "list", "--json", "--all"])
    cron_runs, cron_runs_error = run_text_command(["openclaw", "cron", "runs", "--limit", "8"])
    heartbeat_last, heartbeat_error = run_text_command(["openclaw", "system", "heartbeat", "last"])
    return {
        "cronStatus": {"data": cron_status, "error": cron_status_error},
        "cronJobs": {"data": cron_jobs, "error": cron_jobs_error},
        "cronRuns": {"data": cron_runs, "error": cron_runs_error},
        "heartbeatLast": {"data": heartbeat_last, "error": heartbeat_error},
    }


def resolve_file_key(file_key: str) -> Path | None:
    if file_key.startswith("workspace:"):
        name = file_key.split(":", 1)[1]
        if name in WORKSPACE_FILES:
            return WORKSPACE_DIR / name
        return None
    if file_key.startswith("skill:"):
        name = file_key.split(":", 1)[1]
        if name in BUNDLED_SKILL_NAMES:
            return SKILLS_DIR / name / "SKILL.md"
        return None
    return None


class Handler(BaseHTTPRequestHandler):
    server_version = "OpenClawDashboard/1.0"

    def log_message(self, format: str, *args: Any) -> None:  # pragma: no cover - keep logs quiet
        return

    def send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/state":
            schedule = schedule_state()
            options = load_addon_options()
            states, states_error = fetch_homeassistant_states()
            payload = {
                "generatedAt": datetime.now(timezone.utc).isoformat(),
                "workspaceFiles": workspace_entries(),
                "skillFiles": skill_entries(),
                "integrations": integration_status(),
                "schedule": schedule,
                "graph": refresh_graph_snapshot(),
                "insights": generate_insights(states, options, schedule, states_error=states_error),
            }
            self.send_json(HTTPStatus.OK, payload)
            return

        if parsed.path == "/api/file":
            file_key = parse_qs(parsed.query).get("key", [""])[0]
            target = resolve_file_key(file_key)
            if target is None:
                self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Unknown file key"})
                return
            content = target.read_text(encoding="utf-8") if target.exists() else ""
            self.send_json(
                HTTPStatus.OK,
                {
                    "key": file_key,
                    "path": str(target),
                    "content": content,
                    "exists": target.exists(),
                },
            )
            return

        self.send_json(HTTPStatus.NOT_FOUND, {"error": "Not found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/api/file":
            self.send_json(HTTPStatus.NOT_FOUND, {"error": "Not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Invalid Content-Length"})
            return

        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Invalid JSON"})
            return

        file_key = str(payload.get("key", ""))
        content = payload.get("content", "")
        if not isinstance(content, str):
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Content must be a string"})
            return

        target = resolve_file_key(file_key)
        if target is None:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Unknown file key"})
            return

        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        self.send_json(
            HTTPStatus.OK,
            {
                "key": file_key,
                "path": str(target),
                "savedAt": datetime.now(timezone.utc).isoformat(),
            },
        )


def main() -> None:
    ensure_graph_db()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.daemon_threads = True
    print(f"INFO: Dashboard API listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
