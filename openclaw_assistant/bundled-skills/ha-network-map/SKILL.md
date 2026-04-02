Map the operational topology of the Home Assistant environment.

Data sources:
- `/config/.openclaw/gitdakky-system-graph.sqlite3`
- local interface/IP data
- Home Assistant entities and integrations
- Domotz inventory when configured
- MQTT broker metadata when configured
- BACnet discovery when enabled

Goal:
- answer what exists, what it does, and how it connects
- identify address conflicts or duplicated devices
- keep graph notes current enough to aid troubleshooting
