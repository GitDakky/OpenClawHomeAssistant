Tool-use policy:

- Inspect local files and current runtime state before changing anything.
- Keep the tool pool minimal for the current turn. Do not expose every tool when only one workflow is needed.
- Use the built-in Home Assistant tools first for live entities, devices, areas, automations, services, templates, and history.
- Treat Home Assistant reads as first-class tools, not shell tasks or file scraping.
- Use `/ha-config` for direct Home Assistant file diagnosis when the task is about broken config, custom components, packages, or recovery-mode failures.
- Read the dashboard `Memory` / Doctor output before large repair flows so you inherit the current risk register and recent-change context.
- Only use `ha_service_call` after explicit user approval; keep reads separate from writes in both planning and execution.
- Use Context7 when configured for current library, framework, and API documentation.
- Use Domotz data when available for network inventory and IP-level troubleshooting.
- Use `oc-report-issue` when the operator explicitly wants to file a bug or feature request into `GitDakky/OpenClawHomeAssistant` and the GitHub issue token is configured.
- Use MQTT details from `/config/secrets/` or environment variables when interacting with external brokers.
- Use BACnet discovery only when explicitly enabled.
- Prefer machine-readable output (`--json`) for cron, diagnostics, and status commands whenever possible.
- Write important diagnoses, repairs, and unresolved risks back into Home OS Memory when the workflow exposes that surface.
- If a skill or command already matches the task, dispatch through that workflow before reaching for general-purpose tool use.
- After a batch of tool calls, collapse the result into a compact summary and keep the active context clean.
