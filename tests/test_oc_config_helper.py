import json
import tempfile
import unittest
from pathlib import Path

from openclaw_assistant import oc_config_helper


class ApplyGatewaySettingsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.config_path = Path(self.temp_dir.name) / "openclaw.json"
        self.original_config_path = oc_config_helper.CONFIG_PATH
        oc_config_helper.CONFIG_PATH = self.config_path

    def tearDown(self) -> None:
        oc_config_helper.CONFIG_PATH = self.original_config_path
        self.temp_dir.cleanup()

    def read_config(self) -> dict:
        return json.loads(self.config_path.read_text(encoding="utf-8"))

    def test_remote_mode_persists_remote_gateway_url(self) -> None:
        result = oc_config_helper.apply_gateway_settings(
            mode="remote",
            remote_url="wss://gateway.example.com:443",
            bind_mode="loopback",
            port=18790,
            enable_openai_api=False,
            auth_mode="token",
            trusted_proxies_csv="",
        )

        self.assertTrue(result)
        cfg = self.read_config()
        self.assertEqual(cfg["gateway"]["mode"], "remote")
        self.assertEqual(cfg["gateway"]["remote"]["url"], "wss://gateway.example.com:443")
        self.assertEqual(cfg["gateway"]["bind"], "loopback")
        self.assertEqual(cfg["gateway"].get("port", 18790), 18790)
        self.assertEqual(cfg["gateway"]["auth"].get("mode", "token"), "token")
        self.assertTrue(cfg["gateway"]["auth"]["token"])

    def test_trusted_proxy_mode_removes_shared_token(self) -> None:
        self.config_path.write_text(
            json.dumps(
                {
                    "gateway": {
                        "auth": {
                            "mode": "token",
                            "token": "existing-token",
                        }
                    }
                }
            ),
            encoding="utf-8",
        )

        result = oc_config_helper.apply_gateway_settings(
            mode="local",
            remote_url="",
            bind_mode="lan",
            port=18790,
            enable_openai_api=True,
            auth_mode="trusted-proxy",
            trusted_proxies_csv="127.0.0.1,192.168.1.0/24",
        )

        self.assertTrue(result)
        cfg = self.read_config()
        self.assertEqual(cfg["gateway"]["auth"]["mode"], "trusted-proxy")
        self.assertNotIn("token", cfg["gateway"]["auth"])
        self.assertEqual(
            cfg["gateway"]["auth"]["trustedProxy"],
            {"userHeader": "x-forwarded-user"},
        )
        self.assertEqual(cfg["gateway"]["trustedProxies"], ["127.0.0.1", "192.168.1.0/24"])
        self.assertTrue(cfg["gateway"]["http"]["endpoints"]["chatCompletions"]["enabled"])
