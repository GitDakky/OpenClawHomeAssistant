# Voice and Escalation Policy

This file defines the first escalation policy for the fork.
It is a planning and implementation-order artifact. It does **not** mean every channel below is already shipped.

## Goal

Reach the homeowner on the right surface when the house needs a human decision, while keeping the first rollout bounded and auditable.

## Non-goals

- Pretending every transport is production-ready on day one
- Letting the house place outbound voice calls without explicit policy
- Treating chat, voice, and acknowledgement as one undifferentiated stream

## Implementation order

1. Assist-first local voice
   - Keep Home Assistant Assist as the primary low-latency local control path.
   - Focus on exposed entities, deterministic actions, and reliable operator setup first.
2. Matrix escalation
   - Start with Matrix because it is already a first-class channel in this fork.
   - Prioritize DM and room acknowledgement semantics before voice calling.
3. SIP / PBX paths
   - Add 3CX or equivalent SIP-capable routes only after acknowledgement and retry policy is stable.
4. Voice-call transport bridge
   - Use Janus as the media/control boundary only after the policy layer and session model are explicit.
5. Consumer messaging bridges
   - Treat WhatsApp or similar channels as later adapters, not as the control plane.

## Event classes

### Notify

Use for:
- low urgency status summaries
- maintenance reminders
- informational insight cards promoted into a message

Expected behavior:
- deliver once
- no retry storm
- acknowledgement optional

### Escalate

Use for:
- repeated failures
- security-relevant changes
- high-cost or high-risk conditions that need a human choice

Expected behavior:
- start on the lowest-friction available channel
- retry with bounded backoff
- move up the channel ladder if not acknowledged

### Call

Use for:
- time-sensitive events where text is likely to be missed
- alarm-like conditions with a defined human-response expectation

Expected behavior:
- require an explicit policy opt-in
- use Janus-backed media only after the voice session model is implemented

## Acknowledgement semantics

Every escalation target should eventually map to the same state machine:

1. `pending`
2. `acknowledged`
3. `snoozed`
4. `resolved`
5. `escalated`

Rules:

- The first valid human acknowledgement stops retries on that channel tier.
- `snoozed` delays the next escalation step but does not resolve the underlying event.
- `resolved` closes the event and records the actor/channel.
- Lack of acknowledgement within the policy window advances to the next configured channel.

## Channel ladder

Default order for the first implementation track:

1. Assist / Home Assistant surface
2. Matrix DM
3. Matrix room
4. SIP / PBX call path
5. Other homeowner-facing transports

This order is intentional:

- keep the first mile inside Home Assistant
- move to Matrix before telephony because the channel is already present in this fork
- treat calls as a higher-cost escalation step

## Operator guardrails

- Every policy must declare who can acknowledge an event.
- Every call-capable path must be opt-in.
- Do not represent unimplemented transports as active.
- Keep the first rollout read-mostly: recommendations and acknowledgement before autonomous outbound calling.
