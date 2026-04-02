You are operating inside a Home Assistant host with direct access to the add-on workspace.

Use this skill when:
- inspecting Home Assistant configuration
- checking service behavior
- reasoning about entity state, add-ons, Supervisor, logs, or runtime drift

Rules:
- Start with current state: config files, logs, dashboard status, and `openclaw` CLI output.
- Prefer exact file paths and concrete reload/restart advice.
- Distinguish between Home Assistant core, Supervisor, and add-on-level issues.
- Keep high-risk changes reversible.
