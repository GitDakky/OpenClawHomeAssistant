import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path
import json


REPO_ROOT = Path(__file__).resolve().parents[1]
RUN_HELPERS = REPO_ROOT / "openclaw_assistant" / "run_helpers.sh"


def run_helper_script(script: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/bash", "-lc", f"source {RUN_HELPERS} && {script}"],
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
    )


class RunHelpersTests(unittest.TestCase):
    def test_legacy_migration_precheck_skips_when_marker_exists(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            migration_flag = root / ".gitdakky-legacy-migration"
            config_dir = root / "config"
            addon_configs_dir = root / "addon_configs"
            config_dir.mkdir()
            addon_configs_dir.mkdir()
            migration_flag.write_text("done\n", encoding="utf-8")

            result = run_helper_script(
                f'legacy_migration_precheck "{migration_flag}" "{config_dir}" "token" "{addon_configs_dir}"'
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "already-evaluated")

    def test_legacy_migration_precheck_skips_when_existing_state_detected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            migration_flag = root / ".gitdakky-legacy-migration"
            config_dir = root / "config"
            addon_configs_dir = root / "addon_configs"
            config_dir.mkdir()
            addon_configs_dir.mkdir()
            (config_dir / "real-state-file").write_text("x\n", encoding="utf-8")

            result = run_helper_script(
                f'legacy_migration_precheck "{migration_flag}" "{config_dir}" "token" "{addon_configs_dir}"'
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "skipped-existing")

    def test_legacy_migration_precheck_skips_without_supervisor_or_addon_configs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            migration_flag = root / ".gitdakky-legacy-migration"
            config_dir = root / "config"
            addon_configs_dir = root / "missing-addon-configs"
            config_dir.mkdir()

            result = run_helper_script(
                f'legacy_migration_precheck "{migration_flag}" "{config_dir}" "" "{addon_configs_dir}"'
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "skipped-no-supervisor")

            addon_configs_dir.mkdir()
            result = run_helper_script(
                f'legacy_migration_precheck "{migration_flag}" "{config_dir}" "token" "{addon_configs_dir}"'
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "proceed")

    def test_parse_remote_gateway_url_supports_wss_default_port(self) -> None:
        result = run_helper_script('eval "$(parse_remote_gateway_url "wss://gateway.example.com")" && printf "%s %s %s" "$NODE_HOST" "$NODE_PORT" "$NODE_TLS_FLAG"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "gateway.example.com 443 --tls")

    def test_parse_remote_gateway_url_rejects_invalid_scheme(self) -> None:
        result = run_helper_script('eval "$(parse_remote_gateway_url "https://gateway.example.com")"')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid gateway.remote.url", result.stdout)

    def test_config_dir_has_user_state_ignores_migration_markers(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            (temp_path / ".gitdakky-legacy-migration").write_text("done\n", encoding="utf-8")
            (temp_path / ".gitdakky-migration-test").write_text("done\n", encoding="utf-8")

            result = run_helper_script(f'if config_dir_has_user_state "{temp_path}"; then echo yes; else echo no; fi')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "no")

            (temp_path / "real-user-file").write_text("state\n", encoding="utf-8")
            result = run_helper_script(f'if config_dir_has_user_state "{temp_path}"; then echo yes; else echo no; fi')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "yes")

    def test_legacy_agent_state_needs_migration_when_legacy_auth_exists(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            legacy_agent = root / "legacy-agent"
            legacy_sessions = root / "legacy-sessions"
            default_agent = root / "default-agent"
            default_sessions = root / "default-sessions"
            legacy_agent.mkdir()
            legacy_sessions.mkdir()
            default_agent.mkdir()
            default_sessions.mkdir()
            (legacy_agent / "auth-profiles.json").write_text("{}", encoding="utf-8")

            cmd = textwrap.dedent(
                f'''
                if legacy_agent_state_needs_migration "{legacy_agent}" "{legacy_sessions}" "{default_agent}" "{default_sessions}"; then
                  echo yes
                else
                  echo no
                fi
                '''
            ).strip()
            result = run_helper_script(cmd)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "yes")

    def test_legacy_agent_state_does_not_need_migration_when_default_state_exists(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            legacy_agent = root / "legacy-agent"
            legacy_sessions = root / "legacy-sessions"
            default_agent = root / "default-agent"
            default_sessions = root / "default-sessions"
            legacy_agent.mkdir()
            legacy_sessions.mkdir()
            default_agent.mkdir()
            default_sessions.mkdir()
            (legacy_agent / "auth-profiles.json").write_text("{}", encoding="utf-8")
            (default_agent / "auth-profiles.json").write_text("{}", encoding="utf-8")
            (legacy_sessions / "session.jsonl").write_text("{}", encoding="utf-8")
            (default_sessions / "session.jsonl").write_text("{}", encoding="utf-8")

            cmd = textwrap.dedent(
                f'''
                if legacy_agent_state_needs_migration "{legacy_agent}" "{legacy_sessions}" "{default_agent}" "{default_sessions}"; then
                  echo yes
                else
                  echo no
                fi
                '''
            ).strip()
            result = run_helper_script(cmd)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "no")

    def test_sync_gateway_settings_from_options_persists_remote_url(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            options_path = root / "options.json"
            config_path = root / "openclaw.json"
            options_path.write_text(
                json.dumps(
                    {
                        "gateway_mode": "remote",
                        "gateway_remote_url": "wss://gateway.example.com:443",
                        "gateway_bind_mode": "loopback",
                        "enable_openai_api": False,
                        "gateway_auth_mode": "token",
                        "gateway_trusted_proxies": "",
                    }
                ),
                encoding="utf-8",
            )
            config_path.write_text("{}", encoding="utf-8")

            cmd = textwrap.dedent(
                f'''
                sync_gateway_settings_from_options "{options_path}" "{REPO_ROOT / "openclaw_assistant" / "oc_config_helper.py"}" "{config_path}" "18790"
                '''
            ).strip()
            result = run_helper_script(cmd)
            self.assertEqual(result.returncode, 0, result.stderr)

            config = json.loads(config_path.read_text(encoding="utf-8"))
            self.assertEqual(config["gateway"]["mode"], "remote")
            self.assertEqual(config["gateway"]["remote"]["url"], "wss://gateway.example.com:443")

    def test_sync_gateway_settings_and_parse_remote_url_reject_invalid_startup_remote(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            options_path = root / "options.json"
            config_path = root / "openclaw.json"
            options_path.write_text(
                json.dumps(
                    {
                        "gateway_mode": "remote",
                        "gateway_remote_url": "https://gateway.example.com",
                        "gateway_bind_mode": "loopback",
                        "enable_openai_api": False,
                        "gateway_auth_mode": "token",
                        "gateway_trusted_proxies": "",
                    }
                ),
                encoding="utf-8",
            )
            config_path.write_text("{}", encoding="utf-8")

            cmd = textwrap.dedent(
                f'''
                sync_gateway_settings_from_options "{options_path}" "{REPO_ROOT / "openclaw_assistant" / "oc_config_helper.py"}" "{config_path}" "18790" &&
                REMOTE_URL="$(jq -r '.gateway_remote_url' "{options_path}")" &&
                eval "$(parse_remote_gateway_url "$REMOTE_URL")"
                '''
            ).strip()
            result = run_helper_script(cmd)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Invalid gateway.remote.url", result.stdout)

    def test_matrix_startup_precheck_skips_when_disabled(self) -> None:
        result = run_helper_script('matrix_startup_precheck "false" "" "" "" ""')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "disabled")

    def test_matrix_startup_precheck_requires_homeserver(self) -> None:
        result = run_helper_script('matrix_startup_precheck "true" "" "@bot:example.org" "secret" ""')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "missing-homeserver")

    def test_matrix_startup_precheck_requires_auth(self) -> None:
        result = run_helper_script('matrix_startup_precheck "true" "https://matrix.example.org" "" "" ""')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "missing-auth")

    def test_matrix_startup_precheck_accepts_access_token(self) -> None:
        result = run_helper_script('matrix_startup_precheck "true" "https://matrix.example.org" "" "" "token"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "ready")

    def test_matrix_startup_precheck_accepts_user_and_password(self) -> None:
        result = run_helper_script('matrix_startup_precheck "true" "https://matrix.example.org" "@bot:example.org" "secret" ""')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "ready")
