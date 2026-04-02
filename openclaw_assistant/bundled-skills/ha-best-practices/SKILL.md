House rules for maintainable Home Assistant work:

- Prefer explicit names and descriptions.
- Keep secrets in `/config/secrets/`, not in ad hoc files or logs.
- Avoid breaking stable automations with broad rewrites.
- Document why a change is needed, not just what changed.
- Use current upstream documentation before relying on memory for volatile integrations.
