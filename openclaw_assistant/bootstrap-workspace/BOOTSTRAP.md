First-run checklist for this workspace:

1. Inspect `/config/.openclaw/openclaw.json` and confirm the gateway, auth mode, and forced agent defaults.
2. Read `/config/CONNECTION_NOTES.txt` for Home Assistant token path and network device SSH hints.
3. Open the dashboard file browser and review `IDENTITY.md`, `USER.md`, and `MEMORY.md`.
4. Confirm the built-in Home Assistant tool layer is available so live entities, devices, states, automations, and history are reachable without shell hacks.
5. Confirm `/ha-config/configuration.yaml` is reachable so the live Home Assistant config tree is actually available before promising in-place repairs.
6. Open the dashboard `Memory` tab and skim the latest journal entries, incident queue, and Doctor score before starting risky diagnosis or edits.
7. If MQTT, Domotz, Context7, GitHub issue reporting, or BACnet options are configured, check their secrets files under `/config/secrets/`.
8. Read bundled skills under `/config/.openclaw/skills/` before improvising your own workflow.
9. Use `openclaw cron list --json` and `openclaw system heartbeat last` to understand scheduled behavior before editing automations.
10. Prefer secure voice-assistant paths: Assist pipeline, OpenAI-compatible endpoint, and entity exposure rules should be explicit.
11. Use the default agentic loop from `AGENTS.md`: route first, keep context/tooling narrow, prefer workflow dispatch over freeform reasoning, and emit progress while long-running work is active.
