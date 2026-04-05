import unittest

from openclaw_assistant import render_nginx


class RenderNginxHelpersTests(unittest.TestCase):
    def test_explicit_public_url_wins(self) -> None:
        self.assertEqual(
            render_nginx.resolve_gateway_public_url(
                "https://gateway.example.com:443",
                enable_https=True,
                https_port="18790",
                lan_ip="192.168.1.10",
            ),
            "https://gateway.example.com:443",
        )

    def test_https_mode_derives_lan_gateway_url(self) -> None:
        self.assertEqual(
            render_nginx.resolve_gateway_public_url(
                "",
                enable_https=True,
                https_port="18790",
                lan_ip="192.168.1.10",
            ),
            "https://192.168.1.10:18790",
        )

    def test_non_https_mode_does_not_guess_public_url(self) -> None:
        self.assertEqual(
            render_nginx.resolve_gateway_public_url(
                "",
                enable_https=False,
                https_port="18790",
                lan_ip="192.168.1.10",
            ),
            "",
        )

    def test_trailing_slash_uses_empty_path_suffix(self) -> None:
        self.assertEqual(
            render_nginx.resolve_gateway_public_url_path("https://gateway.example.com/"),
            "",
        )

    def test_non_trailing_url_uses_root_path_suffix(self) -> None:
        self.assertEqual(
            render_nginx.resolve_gateway_public_url_path("https://gateway.example.com"),
            "/",
        )
