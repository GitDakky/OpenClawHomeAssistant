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
| Seeded operator brain | Preloaded workspace files (`AGENTS.md`, `IDENTITY.md`, `TOOLS.md`, `MEMORY.md`, and more) plus Home Assistant skill files |
| Operator dashboard | Live cron/heartbeat visibility, file editing for the seeded workspace and skills, and integration status cards |
| Live HA tool layer | Built-in Home Assistant tools for entities, devices, areas, automations, services, template rendering, and bounded history |
| External intelligence hooks | Optional Context7, Domotz, GitHub issue reporting, MQTT/HiveMQ, BACnet scout, and lightweight system graph scaffolding |
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
oc-onboard
```

`oc-onboard` is the managed onboarding wrapper for this add-on. It runs the normal OpenClaw wizard, then automatically recycles the local gateway if onboarding changed gateway auth or other runtime-critical settings. That avoids the token mismatch split-brain that can happen if a live gateway keeps an old in-memory token after `openclaw.json` is rewritten.

7. If the legacy OpenClaw Assistant add-on is installed, this fork will try to stop it and import its add-on config on first start.
8. Retrieve the gateway token:

```sh
jq -r '.gateway.auth.token' /config/.openclaw/openclaw.json
```

For later reconfiguration, use `oc-configure` instead of raw `openclaw configure` for the same reason.

For the full setup flow, secure-access recipes, and troubleshooting, use [DOCS.md](DOCS.md).

In most local installs, leave `gateway_public_url` empty. The landing page now derives the Gateway URL automatically from the Home Assistant host and access mode in the common local cases. Only set it when you need to override that with a reverse-proxy or Tailscale hostname.

## Live Home Assistant access

- The add-on now ships a built-in Home Assistant tool layer by default. OpenClaw can read live entities, devices, areas, automations, services, templates, and recent history without asking you to wire a separate MCP server or scrape files.
- Read access is enabled by default inside the trusted add-on context.
- Mutating Home Assistant service calls stay opt-in behind the `enable_ha_service_calls` option.
- `homeassistant_token` is now mainly for your own scripts and legacy external MCP workflows. It is no longer required for the built-in live Home Assistant read tools.

## Runtime

![OpenClaw Super Home Assistant architecture](assets/openclaw-architecture.svg)

- Home Assistant ingress for the landing page and operational entry point
- `nginx` + `ttyd` for browser-based setup and terminal access
- OpenClaw gateway for chat, skills, MCP, and the OpenAI-compatible endpoint
- Seeded OpenClaw workspace bootstrap files and GitDakky Home Assistant skill pack under persistent storage
- A lightweight local dashboard API that powers file editing, cron/heartbeat visibility, integration status, and system-graph metadata on the ingress page
- First-start state reconciliation for older single-agent OpenClaw layouts so legacy auth/session data lands in `agents/main/...`
- Persistent `/config` storage so updates do not wipe the working environment

## Seeded workspace and skills

- On first boot, the add-on seeds `/config/clawd` with `AGENTS.md`, `BOOTSTRAP.md`, `HEARTBEAT.md`, `IDENTITY.md`, `MEMORY.md`, `SOUL.md`, `TOOLS.md`, and `USER.md`.
- It also seeds `/config/.openclaw/skills/` with GitDakky-managed Home Assistant skills for operations, automations, voice, diagnostics, network mapping, MQTT, Domotz, BACnet, research, and repo issue reporting.
- If you add a fine-grained GitHub token with `Issues: write` in add-on settings, the assistant can file bugs and feature requests directly to [this repository’s Issues](https://github.com/GitDakky/OpenClawHomeAssistant/issues) via `oc-report-issue`.
- The dashboard now exposes those files directly so you can review or edit them without dropping into a shell unless you want to.

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
