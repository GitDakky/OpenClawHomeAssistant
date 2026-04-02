First-run checklist for this workspace:

1. Inspect `/config/.openclaw/openclaw.json` and confirm the gateway, auth mode, and forced agent defaults.
2. Read `/config/CONNECTION_NOTES.txt` for Home Assistant token path and network device SSH hints.
3. Open the dashboard file browser and review `IDENTITY.md`, `USER.md`, and `MEMORY.md`.
4. If `homeassistant_token` is configured, confirm MCP is registered and Home Assistant control is working.
5. If MQTT, Domotz, Context7, or BACnet options are configured, check their secrets files under `/config/secrets/`.
6. Read bundled skills under `/config/.openclaw/skills/` before improvising your own workflow.
7. Use `openclaw cron list --json` and `openclaw system heartbeat last` to understand scheduled behavior before editing automations.
8. Prefer secure voice-assistant paths: Assist pipeline, OpenAI-compatible endpoint, and entity exposure rules should be explicit.
9. Use the default agentic loop from `AGENTS.md`: route first, keep context/tooling narrow, prefer workflow dispatch over freeform reasoning, and emit progress while long-running work is active.
