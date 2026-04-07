import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LANDING_TEMPLATE = (REPO_ROOT / "openclaw_assistant" / "landing.html.tpl").read_text(encoding="utf-8")
DOCS_TEXT = (REPO_ROOT / "DOCS.md").read_text(encoding="utf-8")


class OperatorGuidanceTests(unittest.TestCase):
    def test_landing_template_explains_when_gateway_public_url_is_needed(self) -> None:
        self.assertIn(
            "Set <code>gateway_public_url</code> only when you need to override the detected host or point at a reverse-proxy / Tailscale URL.",
            LANDING_TEMPLATE,
        )
        self.assertIn(
            "Set gateway_public_url only if you are using a reverse proxy, Tailscale hostname, or another non-default path.",
            LANDING_TEMPLATE,
        )

    def test_landing_template_explains_remote_gateway_browser_url_split(self) -> None:
        self.assertIn(
            "keep <code>gateway_remote_url</code> as the backend <code>ws://</code> or <code>wss://</code> endpoint",
            LANDING_TEMPLATE,
        )
        self.assertIn(
            "Do not paste a websocket URL into <code>gateway_public_url</code>.",
            LANDING_TEMPLATE,
        )

    def test_landing_template_keeps_tailnet_specific_override_guidance(self) -> None:
        self.assertIn(
            "Issue a certificate for the machine and set <code>gateway_public_url</code> to the final HTTPS host if the add-on cannot derive it automatically.",
            LANDING_TEMPLATE,
        )
        self.assertIn(
            "<li><b>tailnet_https</b> if your remote path is Tailscale-first</li>",
            LANDING_TEMPLATE,
        )

    def test_docs_match_gateway_public_url_override_guidance(self) -> None:
        self.assertIn(
            "In most local installs you can leave `gateway_public_url` empty.",
            DOCS_TEXT,
        )
        self.assertIn(
            "Set `gateway_public_url` only when the externally reachable hostname differs from the host you are already using in Home Assistant.",
            DOCS_TEXT,
        )

    def test_docs_distinguish_remote_gateway_and_browser_urls(self) -> None:
        self.assertIn(
            "keep `gateway_remote_url` as the backend `ws://` or `wss://` endpoint",
            DOCS_TEXT,
        )
        self.assertIn(
            "Do **not** paste a websocket URL into `gateway_public_url`.",
            DOCS_TEXT,
        )

    def test_docs_explain_companion_integration_connection_rules(self) -> None:
        self.assertIn(
            "Do not use the Home Assistant ingress page URL.",
            DOCS_TEXT,
        )
        self.assertIn(
            "connect the integration to the remote gateway itself, not to this add-on's ingress page.",
            DOCS_TEXT,
        )

    def test_docs_keep_assist_first_voice_guidance_bounded(self) -> None:
        self.assertIn(
            "Do not point Assist at the ingress page URL.",
            DOCS_TEXT,
        )
        self.assertIn(
            "Multi-channel outbound voice and call escalation are roadmap items, not current shipped behavior.",
            DOCS_TEXT,
        )

    def test_landing_and_docs_explain_live_home_assistant_config_mount(self) -> None:
        self.assertIn(
            "This fork mounts the live Home Assistant config tree at <code>/ha-config</code>.",
            LANDING_TEMPLATE,
        )
        self.assertIn(
            "Dashboard editing targets the add-on workspace under /config. The live Home Assistant config root is mounted separately at /ha-config.",
            LANDING_TEMPLATE,
        )
        self.assertIn(
            "This fork also mounts the real Home Assistant configuration root into the add-on at:",
            DOCS_TEXT,
        )
        self.assertIn(
            "- `/ha-config` is the live Home Assistant config tree.",
            DOCS_TEXT,
        )
