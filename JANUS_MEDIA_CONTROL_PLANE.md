# Janus Media and Control Plane

This file defines the design boundary for future Janus-backed voice sessions.
It is a design artifact, not a shipped feature announcement.

## Why Janus

Janus is the candidate media layer for outbound and inbound voice sessions because it can sit between OpenClaw policy logic and multiple communications adapters without forcing Home Assistant itself to become the telephony switch.

## Scope

The Janus layer is intended to handle:

- WebRTC media termination
- voice session setup and teardown
- adapter-facing media bridging
- session metadata handoff to the policy layer

The Janus layer is **not** intended to decide:

- whether a call should happen
- who should be called first
- when retries stop
- what acknowledgement means

Those decisions belong in the policy layer defined in [VOICE_ESCALATION_POLICY.md](VOICE_ESCALATION_POLICY.md).

## Proposed boundaries

### Home Assistant

- still owns local Assist and device/entity exposure
- remains the best path for immediate in-home voice
- should not be forced to become the outbound call orchestrator

### OpenClaw / add-on policy layer

- evaluates events
- chooses escalation target and channel
- creates a call or voice-session request
- records acknowledgement and resolution state

### Janus media layer

- accepts a session request from the policy layer
- negotiates WebRTC media
- bridges media toward the chosen channel adapter
- publishes session events back to the policy layer

### Channel adapters

- Matrix voice/call adapter
- SIP / 3CX adapter
- future WhatsApp or other transport-specific adapters

Adapters should be thin. They translate Janus session events into transport-specific setup, auth, and signalling.

## Session model

Each voice session should carry:

- event ID
- target channel
- target identity
- urgency
- summary text
- acknowledgement timeout
- final outcome

The policy layer should be able to say:

- create outbound session
- retry session
- hand off to next channel
- stop session on acknowledgement

## Security and trust boundaries

- Janus should not store long-lived policy secrets unless strictly required.
- Transport credentials should remain in the add-on secret store and be injected only for active adapters.
- Every outbound voice path should be explicitly enabled by the operator.
- Session logs should avoid storing full conversation audio by default.

## Risks and constraints

- NAT traversal and firewall complexity for self-hosted installs
- transport-specific auth models
- homeowner privacy expectations around recorded or relayed audio
- reliable acknowledgement propagation back into the add-on
- keeping Home Assistant voice expectations separate from call escalation behavior

## Delivery order

1. Harden Assist-first local voice
2. Finalize multi-channel escalation policy and acknowledgement model
3. Build the session-control API inside the add-on
4. Prototype Janus with one adapter only
5. Add more transports after the first adapter proves the control boundary
