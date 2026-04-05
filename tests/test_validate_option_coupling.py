import unittest

from scripts import validate_option_coupling


BASE_CONFIG = """
options:
  timezone: "Europe/Sofia"
  gateway_mode: local
schema:
  timezone: str
  gateway_mode: list(local|remote)?
""".strip()


class ValidateOptionCouplingTests(unittest.TestCase):
    def test_detects_top_level_option_and_schema_changes(self) -> None:
        current = """
options:
  timezone: "Europe/Sofia"
  gateway_mode: remote
  gateway_remote_url: ""
schema:
  timezone: str
  gateway_mode: list(local|remote)?
  gateway_remote_url: str?
""".strip()

        changed = validate_option_coupling.changed_option_or_schema_keys(BASE_CONFIG, current)
        self.assertEqual(changed["options"], ["gateway_mode", "gateway_remote_url"])
        self.assertEqual(changed["schema"], ["gateway_remote_url"])

    def test_ignores_other_sections(self) -> None:
        current = """
name: OpenClaw Super Home Assistant
options:
  timezone: "Europe/Sofia"
  gateway_mode: local
schema:
  timezone: str
  gateway_mode: list(local|remote)?
arch:
  - amd64
""".strip()

        changed = validate_option_coupling.changed_option_or_schema_keys(BASE_CONFIG, current)
        self.assertEqual(changed, {})

