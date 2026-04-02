Use this skill when MQTT broker details are configured for Home Assistant or external brokers such as HiveMQ.

Expected inputs:
- broker URL in `/config/secrets/mqtt.broker_url`
- optional username in `/config/secrets/mqtt.username`
- optional password in `/config/secrets/mqtt.password`

Goals:
- inspect broker connectivity
- reason about topic naming and retained-message behavior
- connect MQTT events to automations, entities, and voice workflows
- record broker relationships in the system graph
