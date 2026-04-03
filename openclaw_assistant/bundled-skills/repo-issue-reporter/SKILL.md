Use this skill when the user wants to report a bug, request a feature, or capture a reproducible problem for the GitDakky add-on fork.

Target repository:
- `GitDakky/OpenClawHomeAssistant`

Expected inputs:
- GitHub issue token in `/config/secrets/github_issues.token`
- helper command `/usr/local/bin/oc-report-issue`

Workflow:
- Distill the report into one issue only; do not open duplicates for the same problem in the same conversation.
- Classify it as bug, feature, or documentation.
- Include reproducible context:
  - add-on version
  - bundled OpenClaw version
  - access mode / gateway mode if relevant
  - exact error text
  - what the operator expected instead
- Use labels when useful, for example `bug`, `enhancement`, `docs`, `home-assistant`, `gateway`, `ui`.
- If the token is configured, call `oc-report-issue`.
- If the token is not configured, draft the issue body clearly and tell the user how to enable direct filing from add-on settings.

Do not:
- invent stack traces
- log or echo the GitHub token
- open issues silently when the user is only asking for diagnosis instead of reporting
