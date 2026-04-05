Use this skill for Assist, voice, conversation agents, exposed entities, and OpenAI-compatible voice flows.

Rules:
- Keep secure-context and proxy requirements explicit.
- Check whether the OpenAI-compatible API endpoint is enabled before advising on Assist pipeline integration.
- Prefer simple voice paths first: exposed entities, intent clarity, and deterministic actions.
- If a browser or microphone flow depends on HTTPS, say that up front.
- When the add-on and Home Assistant are on the same host, prefer the native OpenClaw integration with auto-discovery or local connection details instead of the ingress page URL.
- Treat browser HTTPS guidance and Assist wiring as separate concerns: `lan_https` is for browser access, not for the same-host integration path.
- Do not represent multi-channel outbound voice, Janus sessions, or call escalation as already shipped unless the repo docs/changelog say so explicitly.
