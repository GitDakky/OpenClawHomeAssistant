Tool-use policy:

- Inspect local files and current runtime state before changing anything.
- Keep the tool pool minimal for the current turn. Do not expose every tool when only one workflow is needed.
- Use Home Assistant MCP for entity/service control when configured.
- Use Context7 when configured for current library, framework, and API documentation.
- Use Domotz data when available for network inventory and IP-level troubleshooting.
- Use MQTT details from `/config/secrets/` or environment variables when interacting with external brokers.
- Use BACnet discovery only when explicitly enabled.
- Prefer machine-readable output (`--json`) for cron, diagnostics, and status commands whenever possible.
- If a skill or command already matches the task, dispatch through that workflow before reaching for general-purpose tool use.
- After a batch of tool calls, collapse the result into a compact summary and keep the active context clean.
