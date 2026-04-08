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

    def test_build_doctor_snapshot_scores_config_runtime_and_risk_signals(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=timezone.utc)
        states = [
            sample_entity("sensor.dead_socket", "unavailable", attributes={"friendly_name": "Dead Socket"}, hours_ago=1),
            sample_entity(
                "sensor.front_door_battery",
                "19",
                attributes={"friendly_name": "Front Door Battery", "device_class": "battery", "unit_of_measurement": "%"},
                hours_ago=2,
            ),
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "configuration.yaml").write_text("default_config:\n", encoding="utf-8")
            (root / ".storage").mkdir()
            (root / "packages").mkdir()
            (root / "packages" / "lights.yaml").write_text("lights: {}\n", encoding="utf-8")
            (root / "custom_components" / "demo").mkdir(parents=True)
            (root / "custom_components" / "demo" / "manifest.json").write_text(
                '{"domain":"demo","name":"Demo Component","version":"1.2.3"}',
                encoding="utf-8",
            )
            secrets_dir = root / "secrets"
            secrets_dir.mkdir()
            secret_path = secrets_dir / "homeassistant.token"
            secret_path.write_text("secret", encoding="utf-8")
            old = (now - timedelta(days=200)).timestamp()
            os.utime(secret_path, (old, old))

            doctor = dashboard_api.build_doctor_snapshot(
                states,
                {"access_mode": "lan_https", "gateway_auth_mode": "token"},
                {"cronStatus": {"error": "cron unavailable"}},
                now=now,
                secret_dir=secrets_dir,
                ha_config_dir=root,
            )

        self.assertIn(doctor["status"], {"warn", "off"})
        self.assertLess(doctor["score"], 100)
        self.assertIn("configuration.yaml visible", doctor["checks"][1]["detail"])
        finding_titles = "\n".join(item["title"] for item in doctor["findings"])
        self.assertIn("OpenClaw cron visibility degraded", finding_titles)
        self.assertIn("Unavailable Home Assistant entities detected", finding_titles)
        self.assertIn("Predictive maintenance pressure visible", finding_titles)

    def test_build_memory_snapshot_persists_house_journal_without_duplicate_entries(self) -> None:
        now = datetime(2026, 4, 8, 12, 0, tzinfo=timezone.utc)
        states = [
            sample_entity("person.david", "home", attributes={"friendly_name": "David"}, hours_ago=1),
            sample_entity("sensor.dead_socket", "unavailable", attributes={"friendly_name": "Dead Socket"}, hours_ago=1),
        ]

        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            ha_root = root / "ha-config"
            ha_root.mkdir()
            (ha_root / "configuration.yaml").write_text("default_config:\n", encoding="utf-8")
            (ha_root / "secrets.yaml").write_text("api_key: value\n", encoding="utf-8")
            (ha_root / ".storage").mkdir()
            (ha_root / "packages").mkdir()
            (ha_root / "packages" / "base.yaml").write_text("base: {}\n", encoding="utf-8")

            memory_root = root / "memory"
            snapshot_one = dashboard_api.build_memory_snapshot(
                states,
                {"access_mode": "local_only", "gateway_auth_mode": "token"},
                {"cronStatus": {"data": {"ok": True}, "error": None}},
                now=now,
                secret_dir=root / "secrets",
                ha_config_dir=ha_root,
                memory_dir=memory_root,
            )
            snapshot_two = dashboard_api.build_memory_snapshot(
                states,
                {"access_mode": "local_only", "gateway_auth_mode": "token"},
                {"cronStatus": {"data": {"ok": True}, "error": None}},
                now=now,
                secret_dir=root / "secrets",
                ha_config_dir=ha_root,
                memory_dir=memory_root,
            )

            journal = (memory_root / "house-journal.md").read_text(encoding="utf-8")

        self.assertEqual(1, len(snapshot_one["journalEntries"]))
        self.assertEqual(1, len(snapshot_two["journalEntries"]))
        self.assertIn("Doctor score", snapshot_one["doctor"]["summary"])
        self.assertIn("Home OS Memory", journal)
        self.assertEqual(str(memory_root / "memory-state.json"), snapshot_one["storage"]["statePath"])
        self.assertIn("Dead Socket", "\n".join(item["detail"] for item in snapshot_one["riskRegister"]))


if __name__ == "__main__":
    unittest.main()
