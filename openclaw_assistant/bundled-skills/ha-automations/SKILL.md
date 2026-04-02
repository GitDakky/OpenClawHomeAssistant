Build resilient Home Assistant automations, scripts, helpers, and scheduled maintenance.

Focus:
- idempotent automations
- good trigger/condition/action structure
- failure visibility
- safe restarts and recoverability

Rules:
- Prefer explicit helper entities over hidden magic.
- If a cron or heartbeat already covers the use case, extend it instead of duplicating it.
- When touching YAML, note whether a reload is enough or a full restart is required.
