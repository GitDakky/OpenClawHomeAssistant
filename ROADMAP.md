# OpenClaw Super Home Assistant Roadmap

This file is the execution backlog for the fork.
It separates what is already shipped from what is planned next, and it keeps the fork focused on staying ahead of the legacy line.

## Operating rule

- Ship hardening before glamour.
- Keep the add-on operationally better than the legacy line on release cadence, runtime reliability, migration safety, and docs.
- Treat roadmap items as not shipped unless they already appear in `README.md`, `DOCS.md`, and `openclaw_assistant/CHANGELOG.md` as delivered behavior.

## Shipped foundations

- Current OpenClaw fork packaging with Home Assistant ingress, ttyd, nginx, persistence, and migration support
- Built-in Home Assistant live tool layer
- Matrix channel wiring from add-on settings
- Dashboard/API surface for operator visibility and seeded workspace editing
- Initial read-only home intelligence rack for homeowner, energy, system, predictive-maintenance, and security summaries
- CI validation plus add-on image build/publish flow
- Canonical local validation entrypoint in `scripts/validate_local.sh`
- Regression coverage for remote gateway URL persistence and landing-page gateway URL derivation

## Track 1: Runtime hardening

### Now

- Keep OpenClaw version bumps ahead of the legacy add-on line
- Close regressions around `remote` mode, Tailscale/HTTPS, gateway URL derivation, and CLI-to-gateway behavior
- Expand deterministic validation around startup config reconciliation and persistence-sensitive changes

### Next slices

1. Add explicit validation for `gateway_remote_url` handling in startup/config sync paths beyond the helper-level unit test
2. Add deterministic checks around `gateway_public_url` override precedence and `lan_https`/`tailnet_https` operator messaging
3. Add a smoke path for migration/restart idempotence so repeated starts do not mutate state unexpectedly
4. Tighten validation for translation/config/doc coupling when add-on options change

## Track 2: Home intelligence

### Goal

Turn the add-on from a packaging shell into a house operations brain.

### Next slices

1. Predictive maintenance primitives
   - battery decline summaries
   - device outage / flapping detection
   - climate runtime drift and filter/service interval reminders
2. Homeowner insight summaries
   - what changed today
   - what is costing money
   - what is unusual
   - what should be automated next
3. Energy optimization primitives
   - tariff-aware scheduling inputs
   - solar / battery / EV coordination hooks
   - occupancy- and weather-aware recommendations
4. System optimization
   - noisy automation detection
   - dead entity / integration drift checks
   - HA and add-on operational health summaries
5. Security insight layer
   - exposed service review
   - stale secret / token hygiene checks
   - risky automation or device behavior summaries

## Track 3: Voice and communications

### Goal

Make OpenClaw the operations and escalation interface for the home, not just a text terminal behind Home Assistant.

### Next slices

1. Strengthen Assist-first voice flows already reachable through the OpenAI-compatible endpoint
2. Implement the first policy artifacts:
   - [VOICE_ESCALATION_POLICY.md](VOICE_ESCALATION_POLICY.md)
   - [JANUS_MEDIA_CONTROL_PLANE.md](JANUS_MEDIA_CONTROL_PLANE.md)
3. Design a Janus-backed media/control plane for outbound and inbound voice sessions
4. Add multi-channel escalation targets
   - Matrix voice/call surfaces
   - 3CX
   - WhatsApp voice-capable workflows
   - other homeowner-reachable channels where acknowledgement matters
5. Add policy logic for when the system should notify, call, retry, summarize, or escalate

## Track 4: Distribution and operator experience

### Goal

Make the fork the obvious install choice and the easier add-on to run correctly.

### Next slices

1. Keep installation and troubleshooting docs ahead of recurring support pain
2. Improve one-click installation and onboarding flows
3. Keep companion integration guidance aligned with real gateway/access behavior
4. Continue separating the fork identity clearly from the legacy add-on

## Selection rule for the next task

When choosing the next implementation slice:

1. Prefer a hardening item over a roadmap item if it fixes an operational risk visible in the legacy issue tracker.
2. Prefer the smallest slice that improves reliability and can be verified locally.
3. Only take on larger intelligence or voice features after the add-on runtime path is stable enough to trust for daily use.
