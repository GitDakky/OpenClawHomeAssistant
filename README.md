# OpenClaw Super Home Assistant

![OpenClaw Super Home Assistant hero](assets/openclaw-hero.svg)

OpenClaw Super Home Assistant is the GitDakky fork of the OpenClaw Home Assistant app. It runs **OpenClaw** inside **HAOS** with a secure gateway, embedded terminal, browser automation stack, and persistent workspace.

This fork exists to keep pace with OpenClaw releases and improve the operator experience around them. Faster updates. Cleaner docs. Better presentation. No leftover filler.

[Documentation](DOCS.md) · [Security](SECURITY.md) · [Changelog](openclaw_assistant/CHANGELOG.md) · [Issues](https://github.com/GitDakky/OpenClawHomeAssistant/issues)

## Bundled version

- Bundled OpenClaw: `2026.4.1`
- Previous add-on lineage pin: `2026.3.13`
- Check the live version inside the add-on with `openclaw --version`
- Published image: `ghcr.io/gitdakky/openclaw-super-home-assistant`

## Contribute

Do not buy me a coffee. Do not sponsor this repo. If you want to help, open an issue, send a fix, improve the docs, test releases, or contribute code.

## Fork mission

- Keep this add-on close to current OpenClaw releases instead of lagging behind.
- Make the Home Assistant experience operationally sound: ingress, HTTPS, token auth, reverse proxy, Tailscale, ttyd, persistence.
- Replace throwaway repo presentation with branding that looks deliberate.
- Ship a real CI/CD path: validate every change, build the add-on image in CI, and publish the multi-arch image from `main`.
- Be unmistakably separate from the legacy add-on so users do not confuse the fork with the abandoned line.

## What this add-on gives you

| Capability | What it gives you |
|---|---|
| Secure gateway access | Token auth, `lan_https`, reverse proxy support, and tailnet-friendly modes |
| Embedded terminal | `ttyd` inside Home Assistant for onboarding, recovery, and live ops |
| Automation runtime | OpenClaw gateway, skills, MCP support, and OpenAI-compatible API access |
| Unattended automation mode | Optional `disable_exec_approvals` switch for trusted installs that must suppress host exec approval prompts |
| Browser tooling | Chromium bundled for automation and web-driven workflows |
| Persistent state | Config, skills, agent workspace, keys, and tokens survive add-on updates |
| Useful CLI stack | `git`, `jq`, `python3`, `ripgrep`, `curl`, `pnpm`, Homebrew, and more |

## Install in 60 seconds

1. In Home Assistant, open **Settings -> Apps**.
2. Click **Install App** in the blue button at the bottom-right.
3. Paste this repository URL:
   - `https://github.com/GitDakky/OpenClawHomeAssistant`
4. Exit the dialog, select **OpenClaw Super Home Assistant** from the list, and click **Install**.
5. Look for the GitDakky fork branding with the lobster-in-cape crest so you do not pick the legacy add-on by mistake.
6. Start the app, open the embedded terminal, and run:

```sh
openclaw onboard
```

7. If the legacy OpenClaw Assistant add-on is installed, this fork will try to stop it and import its add-on config on first start.
8. Retrieve the gateway token:

```sh
jq -r '.gateway.auth.token' /config/.openclaw/openclaw.json
```

For the full setup flow, secure-access recipes, and troubleshooting, use [DOCS.md](DOCS.md).

## Runtime

![OpenClaw Super Home Assistant architecture](assets/openclaw-architecture.svg)

- Home Assistant ingress for the landing page and operational entry point
- `nginx` + `ttyd` for browser-based setup and terminal access
- OpenClaw gateway for chat, skills, MCP, and the OpenAI-compatible endpoint
- First-start state reconciliation for older single-agent OpenClaw layouts so legacy auth/session data lands in `agents/main/...`
- Persistent `/config` storage so updates do not wipe the working environment

## Supported architectures

| Architecture | Supported |
|---|---|
| `amd64` | Yes |
| `aarch64` | Yes |
| `armv7` | No |

## Migration

- This fork uses a distinct app name, slug, and image so it does not masquerade as the legacy add-on.
- Clean installs now default to different host-network ports from the legacy add-on: gateway `18790`, terminal `7682`, ingress `48109`.
- On a first boot, if the legacy `openclaw_assistant` install is detected and this fork has no existing state, it will try to stop the old add-on and import its add-on config automatically.
- On startup, the add-on now also reconciles older OpenClaw `agent/` and `sessions/` layouts into the current `agents/main/...` structure before the gateway comes up.
- If the legacy add-on is still running and automatic migration fails, stop or uninstall the old add-on before starting this fork to avoid host-network port conflicts.

## First-start recovery

- If a freshly hatched agent reports missing provider keys from `agents/main/agent/auth-profiles.json`, restart the add-on once so the legacy-to-current state reconciliation can run.
- If local terminal or TUI access shows `pairing required` on a loopback-style install, restart once and retry. This fork now auto-approves same-host local operator pairing requests after the gateway starts.
- Full operator guidance lives in [DOCS.md](DOCS.md).

## Read next

- [DOCS.md](DOCS.md): installation, configuration, access modes, MCP, persistence, troubleshooting
- [SECURITY.md](SECURITY.md): risk model, exposure guidance, and safe operating practices
- [openclaw_assistant/CHANGELOG.md](openclaw_assistant/CHANGELOG.md): release notes for add-on versions
- [MAINTENANCE.md](MAINTENANCE.md): how this fork pins, bumps, validates, and releases OpenClaw updates

## Companion integration

The companion integration lives here:

- [OpenClawHomeAssistantIntegration](https://github.com/techartdev/OpenClawHomeAssistantIntegration)

It can connect to this add-on or to any other reachable OpenClaw gateway.
