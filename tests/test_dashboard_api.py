import os
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from openclaw_assistant import dashboard_api


def sample_entity(entity_id: str, state: str, *, attributes=None, hours_ago: int = 1):
    now = datetime(2026, 4, 5, 12, 0, tzinfo=timezone.utc)
    changed = now - timedelta(hours=hours_ago)
    return {
        "entity_id": entity_id,
        "state": state,
        "attributes": attributes or {},
        "last_changed": changed.isoformat(),
        "last_updated": changed.isoformat(),
    }


class DashboardInsightTests(unittest.TestCase):
    def test_integration_status_reports_live_home_assistant_config_mount(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            config_root = Path(tmpdir)
            previous = dashboard_api.HA_CONFIG_DIR
            dashboard_api.HA_CONFIG_DIR = config_root
            try:
                status = dashboard_api.integration_status()
            finally:
                dashboard_api.HA_CONFIG_DIR = previous

        self.assertTrue(status["homeAssistantConfig"]["configured"])
        self.assertEqual(str(config_root), status["homeAssistantConfig"]["mountPath"])
        self.assertEqual(str(config_root / "configuration.yaml"), status["homeAssistantConfig"]["configurationPath"])
        self.assertEqual(str(config_root / ".storage"), status["homeAssistantConfig"]["storagePath"])

    def test_generate_insights_surfaces_home_energy_system_and_maintenance_signals(self) -> None:
        now = datetime(2026, 4, 5, 12, 0, tzinfo=timezone.utc)
        states = [
            sample_entity("person.david", "not_home", attributes={"friendly_name": "David"}, hours_ago=2),
            sample_entity(
                "sensor.server_rack_power",
                "1234",
                attributes={"friendly_name": "Server Rack Power", "device_class": "power", "unit_of_measurement": "W"},
                hours_ago=1,
            ),
            sample_entity(
                "sensor.front_door_battery",
                "18",
                attributes={"friendly_name": "Front Door Battery", "device_class": "battery", "unit_of_measurement": "%"},
                hours_ago=3,
            ),
            sample_entity(
                "weather.home",
                "sunny",
                attributes={"friendly_name": "Home Weather", "temperature": 4},
                hours_ago=1,
            ),
            sample_entity(
                "sensor.octopus_tariff_rate",
                "0.34",
                attributes={"friendly_name": "Octopus Tariff Rate", "unit_of_measurement": "GBP/kWh"},
                hours_ago=1,
            ),
            sample_entity("automation.night_setback", "off", attributes={"friendly_name": "Night Setback"}, hours_ago=5),
            sample_entity("sensor.dead_socket", "unavailable", attributes={"friendly_name": "Dead Socket"}, hours_ago=6),
            sample_entity("update.router_firmware", "on", attributes={"friendly_name": "Router Firmware"}, hours_ago=4),
            sample_entity(
                "binary_sensor.boiler_connectivity",
                "off",
                attributes={"friendly_name": "Boiler Connectivity", "device_class": "connectivity"},
                hours_ago=2,
            ),
        ]
        options = {
            "access_mode": "lan_https",
            "gateway_auth_mode": "token",
            "disable_exec_approvals": True,
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            insights = dashboard_api.generate_insights(
                states,
                options,
                {"cronStatus": {"data": {"ok": True}, "error": None}},
                now=now,
                secret_dir=Path(tmpdir),
            )

        self.assertIn("Highest live power draw: Server Rack Power at about 1234 W.", insights["homeowner"]["highlights"])
        self.assertIn("Nobody appears to be home.", insights["energy"]["highlights"])
        self.assertIn("Home Weather reports 4 degrees.", insights["energy"]["highlights"])
        self.assertIn("Octopus Tariff Rate is 0.34 GBP/kWh", insights["energy"]["highlights"])
        self.assertIn("Disabled automations: Night Setback", insights["system"]["highlights"])
        self.assertIn("Front Door Battery: 18%", insights["maintenance"]["highlights"])

    def test_build_security_insight_flags_http_exec_and_stale_secrets(self) -> None:
        now = datetime(2026, 4, 5, 12, 0, tzinfo=timezone.utc)
        options = {
            "access_mode": "lan_reverse_proxy",
            "gateway_auth_mode": "trusted-proxy",
            "gateway_public_url": "http://openclaw.example.com",
            "gateway_trusted_proxies": "",
            "enable_ha_service_calls": True,
            "disable_exec_approvals": True,
            "matrix_allow_private_network": True,
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            secret_path = Path(tmpdir) / "homeassistant.token"
            secret_path.write_text("secret", encoding="utf-8")
            old = (now - timedelta(days=220)).timestamp()
            os.utime(secret_path, (old, old))

            insight = dashboard_api.build_security_insight(options, now, Path(tmpdir))

        highlights = "\n".join(insight["highlights"])
        actions = "\n".join(insight["actions"])
        self.assertIn("gateway_public_url uses plain HTTP", highlights)
        self.assertIn("trusted-proxy mode is enabled without any trusted proxy CIDRs or IPs.", highlights)
        self.assertIn("The mutating ha_service_call tool is enabled.", highlights)
        self.assertIn("Secret rotation candidate: homeassistant.token", highlights)
        self.assertIn("Move the browser-facing gateway URL to HTTPS", actions)

    def test_generate_insights_handles_missing_home_assistant_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            insights = dashboard_api.generate_insights(
                [],
                {"access_mode": "local_only", "gateway_auth_mode": "token"},
                {},
                states_error="SUPERVISOR_TOKEN unavailable",
                now=datetime(2026, 4, 5, 12, 0, tzinfo=timezone.utc),
                secret_dir=Path(tmpdir),
            )

        self.assertEqual("off", insights["homeowner"]["status"])
        self.assertIn("SUPERVISOR_TOKEN unavailable", insights["homeowner"]["summary"])
        self.assertIn("Home Assistant state snapshot unavailable", insights["energy"]["summary"])
        self.assertEqual("good", insights["security"]["status"])


if __name__ == "__main__":
    unittest.main()
