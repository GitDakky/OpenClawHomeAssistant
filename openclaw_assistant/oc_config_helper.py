#!/usr/bin/env python3
"""
OpenClaw config helper for Home Assistant add-on.
Safely reads/writes openclaw.json without corrupting it.
"""

import json
import os
import re
import secrets
import sys
from pathlib import Path

CONFIG_PATH = Path(os.environ.get("OPENCLAW_CONFIG_PATH", "/config/.openclaw/openclaw.json"))
EXEC_APPROVALS_PATH = Path(
    os.environ.get("OPENCLAW_EXEC_APPROVALS_PATH", "/config/.openclaw/exec-approvals.json")
)
FORCED_EXEC_APPROVAL_DEFAULTS = {
    "security": "full",
    "ask": "off",
    "askFallback": "full",
}
FORCED_TOOLS_EXEC = {
    "host": "gateway",
    "security": "full",
    "ask": "off",
    "strictInlineEval": False,
}



def read_config():
    """Read and parse openclaw.json."""
    if not CONFIG_PATH.exists():
        return None
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, IOError) as e:
        print(f"ERROR: Failed to read config: {e}", file=sys.stderr)
        return None


def read_json_file(path: Path):
    """Read and parse an arbitrary JSON file."""
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, IOError) as e:
        print(f"ERROR: Failed to read {path}: {e}", file=sys.stderr)
        return None


def write_config(cfg):
    """Write config back to file with nice formatting."""
    try:
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        CONFIG_PATH.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
        return True
    except IOError as e:
        print(f"ERROR: Failed to write config: {e}", file=sys.stderr)
        return False


def write_json_file(path: Path, payload):
    """Write a JSON file with nice formatting."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        return True
    except IOError as e:
        print(f"ERROR: Failed to write {path}: {e}", file=sys.stderr)
        return False


def parse_csv_values(raw: str) -> list[str]:
    """Parse comma/newline separated values into a clean list."""
    if not raw:
        return []
    return [item.strip() for item in re.split(r"[\n,]+", raw) if item.strip()]


def get_gateway_setting(key, default=None):
    """Get a gateway setting from config."""
    cfg = read_config()
    if cfg is None:
        return default
    return cfg.get("gateway", {}).get(key, default)


def set_gateway_setting(key, value):
    """Set a gateway setting, preserving other config."""
    cfg = read_config()
    if cfg is None:
        cfg = {}
    
    if "gateway" not in cfg:
        cfg["gateway"] = {}
    
    cfg["gateway"][key] = value
    return write_config(cfg)


def apply_gateway_settings(mode: str, remote_url: str, bind_mode: str, port: int, enable_openai_api: bool, auth_mode: str, trusted_proxies_csv: str):
    """
    Apply gateway settings to OpenClaw config.
    
    Args:
        mode: "local" or "remote"
        remote_url: remote Gateway websocket URL (used when mode=remote)
        bind_mode: "loopback", "lan", or "tailnet"
        port: Port number to listen on (must be 1-65535)
        enable_openai_api: Enable OpenAI-compatible Chat Completions endpoint
        auth_mode: Gateway auth mode (token|trusted-proxy)
        trusted_proxies_csv: Comma-separated trusted proxy IP/CIDR list
    """
    # Validate gateway mode
    if mode not in ["local", "remote"]:
        print(f"ERROR: Invalid mode '{mode}'. Must be 'local' or 'remote'")
        return False
    
    # Validate bind mode
    if bind_mode not in ["loopback", "lan", "tailnet"]:
        print(f"ERROR: Invalid bind_mode '{bind_mode}'. Must be 'loopback', 'lan', or 'tailnet'")
        return False
    
    # Validate port range
    if port < 1 or port > 65535:
        print(f"ERROR: Invalid port {port}. Must be between 1 and 65535")
        return False

    # Validate auth mode
    if auth_mode not in ["token", "trusted-proxy"]:
        print(f"ERROR: Invalid auth_mode '{auth_mode}'. Must be 'token' or 'trusted-proxy'")
        return False
    
    cfg = read_config()
    if cfg is None:
        cfg = {}
    
    if "gateway" not in cfg:
        cfg["gateway"] = {}
    
    gateway = cfg["gateway"]

    # gateway.remote settings
    if "remote" not in gateway or not isinstance(gateway.get("remote"), dict):
        gateway["remote"] = {}
    remote_cfg = gateway["remote"]

    # auth should be nested inside gateway
    if "auth" not in gateway or not isinstance(gateway.get("auth"), dict):
        gateway["auth"] = {}

    # http.endpoints.chatCompletions should be nested inside gateway
    if "http" not in gateway:
        gateway["http"] = {}
    if "endpoints" not in gateway["http"]:
        gateway["http"]["endpoints"] = {}
    if "chatCompletions" not in gateway["http"]["endpoints"]:
        gateway["http"]["endpoints"]["chatCompletions"] = {}
    
    auth = gateway["auth"]
    chat_completions = gateway["http"]["endpoints"]["chatCompletions"]

    trusted_proxies = [p.strip() for p in trusted_proxies_csv.split(",") if p.strip()]

    # OpenClaw trusted-proxy mode requires nested auth.trustedProxy config.
    # Use a sane default user header expected from reverse proxies.
    trusted_proxy_cfg_default = {"userHeader": "x-forwarded-user"}

    current_mode = gateway.get("mode", "")
    current_remote_url = remote_cfg.get("url", "")
    current_bind = gateway.get("bind", "")
    current_port = gateway.get("port", 18790)
    current_openai_api = chat_completions.get("enabled", False)
    current_auth_mode = auth.get("mode", "token")
    current_trusted_proxies = gateway.get("trustedProxies", [])
    current_trusted_proxy_cfg = auth.get("trustedProxy")
    current_token = auth.get("token")
    
    changes = []
    
    if current_mode != mode:
        gateway["mode"] = mode
        changes.append(f"mode: {current_mode} -> {mode}")

    if current_remote_url != remote_url:
        remote_cfg["url"] = remote_url
        changes.append(f"remote.url: {current_remote_url} -> {remote_url}")
    
    if current_bind != bind_mode:
        gateway["bind"] = bind_mode
        changes.append(f"bind: {current_bind} -> {bind_mode}")
    
    if current_port != port:
        gateway["port"] = port
        changes.append(f"port: {current_port} -> {port}")
    
    if current_openai_api != enable_openai_api:
        chat_completions["enabled"] = enable_openai_api
        changes.append(f"chatCompletions.enabled: {current_openai_api} -> {enable_openai_api}")
    
    if current_auth_mode != auth_mode:
        auth["mode"] = auth_mode
        changes.append(f"auth.mode: {current_auth_mode} -> {auth_mode}")

    if current_trusted_proxies != trusted_proxies:
        gateway["trustedProxies"] = trusted_proxies
        changes.append(f"trustedProxies: {current_trusted_proxies} -> {trusted_proxies}")

    if auth_mode == "trusted-proxy":
        # OpenClaw 2026.4.x rejects trusted-proxy when a shared token is also configured.
        if "token" in auth:
            del auth["token"]
            changes.append("auth.token: removed for trusted-proxy mode")
        if "password" in auth:
            del auth["password"]
            changes.append("auth.password: removed for trusted-proxy mode")
        if current_trusted_proxy_cfg != trusted_proxy_cfg_default:
            auth["trustedProxy"] = trusted_proxy_cfg_default
            changes.append("auth.trustedProxy: configured default userHeader=x-forwarded-user")
    elif auth_mode == "token":
        # If the add-on previously switched through trusted-proxy, the shared token may
        # no longer exist. Generate one so the gateway can still boot safely.
        if not isinstance(current_token, str) or not current_token.strip():
            auth["token"] = secrets.token_urlsafe(24)
            changes.append("auth.token: generated new shared token for token mode")
        if "trustedProxy" in auth:
            del auth["trustedProxy"]
            changes.append("auth.trustedProxy: removed for token mode")
    
    if changes:
        if write_config(cfg):
            print(f"INFO: Updated gateway settings: {', '.join(changes)}")
            return True
        else:
            print("ERROR: Failed to write config")
            return False
    else:
        print(f"INFO: Gateway settings already correct (mode={mode}, remoteUrl={remote_url}, bind={bind_mode}, port={port}, chatCompletions={enable_openai_api}, authMode={auth_mode}, trustedProxies={trusted_proxies})")
        return True


def set_control_ui_origins(origins_csv: str, additional_origins_csv: str = "", disable_device_auth: bool = True): 
    """
    Configure gateway.controlUi for the built-in HTTPS proxy.

    Sets:
      - allowedOrigins: the HTTPS proxy origins so the browser WebSocket
        is accepted (required since v2026.2.21).
      - dangerouslyDisableDeviceAuth: controlled by add-on option
        `controlui_disable_device_auth` (default true). When true, skips
        interactive device pairing; token auth remains enforced.

    Also removes any stale/invalid keys (e.g. pairingMode) that may have
    been written by earlier add-on versions.

    Args:
        origins_csv: Comma-separated list of default origins provided by the add-on.
        additional_origins_csv: Comma-separated list of user-provided extra origins.
    """
    cfg = read_config()
    if cfg is None:
        cfg = {}

    if "gateway" not in cfg:
        cfg["gateway"] = {}
    gateway = cfg["gateway"]

    if "controlUi" not in gateway:
        gateway["controlUi"] = {}

    control_ui = gateway["controlUi"]
    default_origins = [o.strip() for o in origins_csv.split(",") if o.strip()]
    additional_origins = [o.strip() for o in (additional_origins_csv or "").split(",") if o.strip()]
    changes = []

    # --- allowedOrigins ---
    current_origins = control_ui.get("allowedOrigins", [])
    if not isinstance(current_origins, list):
        current_origins = []

    merged_origins = []
    for origin in [*default_origins, *current_origins, *additional_origins]:
        if isinstance(origin, str) and origin and origin not in merged_origins:
            merged_origins.append(origin)

    if current_origins != merged_origins:
        control_ui["allowedOrigins"] = merged_origins
        changes.append(f"allowedOrigins: {current_origins} -> {merged_origins}")

    # --- dangerouslyDisableDeviceAuth ---
    # Optional bypass of interactive per-device pairing (error 1008: pairing required).
    # Token auth is still enforced; this only controls the approval ceremony.
    desired_device_auth_flag = True if disable_device_auth else False
    if control_ui.get("dangerouslyDisableDeviceAuth") is not desired_device_auth_flag:
        prev = control_ui.get("dangerouslyDisableDeviceAuth")
        control_ui["dangerouslyDisableDeviceAuth"] = desired_device_auth_flag
        changes.append(f"dangerouslyDisableDeviceAuth: {prev} -> {desired_device_auth_flag}")

    # --- Remove invalid keys from earlier add-on versions ---
    for stale_key in ("pairingMode",):
        if stale_key in control_ui:
            del control_ui[stale_key]
            changes.append(f"removed invalid key: {stale_key}")

    if not changes:
        status = "disabled" if desired_device_auth_flag else "enabled"
        print(f"INFO: controlUi already correct: origins={merged_origins}, deviceAuth={status}")
        return True

    if write_config(cfg):
        print(f"INFO: Updated controlUi: {', '.join(changes)}")
        return True
    print("ERROR: Failed to write config")
    return False


def configure_exec_approval_policy(disable_exec_approvals: bool):
    """
    Configure host exec approvals and tools.exec policy together.

    When enabled, force:
      - ~/.openclaw/exec-approvals.json defaults to full/off/full
      - tools.exec.host=gateway
      - tools.exec.security=full
      - tools.exec.ask=off
      - tools.exec.strictInlineEval=false

    When disabled, remove only the repo-managed overrides, leaving any
    unrelated user-managed approval config intact.
    """
    cfg = read_config()
    if cfg is None:
        cfg = {}

    approvals = read_json_file(EXEC_APPROVALS_PATH)
    if approvals is None:
        approvals = {}

    cfg_changes = []
    approvals_changes = []

    tools = cfg.get("tools")
    if not isinstance(tools, dict):
        tools = {}
        cfg["tools"] = tools

    exec_cfg = tools.get("exec")
    if not isinstance(exec_cfg, dict):
        exec_cfg = {}
        tools["exec"] = exec_cfg

    if disable_exec_approvals:
        for key, value in FORCED_TOOLS_EXEC.items():
            if exec_cfg.get(key) != value:
                exec_cfg[key] = value
                cfg_changes.append(f"tools.exec.{key}: set to {value!r}")
    else:
        for key, value in FORCED_TOOLS_EXEC.items():
            if exec_cfg.get(key) == value:
                del exec_cfg[key]
                cfg_changes.append(f"tools.exec.{key}: removed repo-managed override")
        if not exec_cfg and "exec" in tools:
            del tools["exec"]
        if not tools and "tools" in cfg:
            del cfg["tools"]

    defaults = approvals.get("defaults")
    if not isinstance(defaults, dict):
        defaults = {}
        if disable_exec_approvals:
            approvals["defaults"] = defaults

    if disable_exec_approvals:
        if not isinstance(approvals.get("version"), int):
            approvals["version"] = 1
            approvals_changes.append("version: initialized to 1")
        if not isinstance(approvals.get("agents"), dict):
            approvals["agents"] = approvals.get("agents") if isinstance(approvals.get("agents"), dict) else {}
        for key, value in FORCED_EXEC_APPROVAL_DEFAULTS.items():
            if defaults.get(key) != value:
                defaults[key] = value
                approvals_changes.append(f"defaults.{key}: set to {value!r}")
    else:
        if isinstance(defaults, dict):
            for key, value in FORCED_EXEC_APPROVAL_DEFAULTS.items():
                if defaults.get(key) == value:
                    del defaults[key]
                    approvals_changes.append(f"defaults.{key}: removed repo-managed override")
            if not defaults and "defaults" in approvals:
                del approvals["defaults"]

    cfg_ok = True
    approvals_ok = True

    if cfg_changes:
        cfg_ok = write_config(cfg)
        if not cfg_ok:
            print("ERROR: Failed to update tools.exec approval policy")
            return False

    if approvals_changes:
        approvals_ok = write_json_file(EXEC_APPROVALS_PATH, approvals)
        if not approvals_ok:
            print("ERROR: Failed to update exec approvals defaults")
            return False

    if disable_exec_approvals:
        if cfg_changes or approvals_changes:
            print(
                "INFO: Exec approvals disabled for host automation flows: "
                + ", ".join([*cfg_changes, *approvals_changes])
            )
        else:
            print("INFO: Exec approvals already disabled for host automation flows")
    else:
        if cfg_changes or approvals_changes:
            print(
                "INFO: Removed repo-managed exec approval overrides: "
                + ", ".join([*cfg_changes, *approvals_changes])
            )
        else:
            print("INFO: No repo-managed exec approval overrides were present")

    return True


def configure_matrix_channel(
    enabled: bool,
    homeserver: str,
    allow_private_network: bool,
    user_id: str,
    password: str,
    access_token: str,
    encryption: bool,
    auto_join: str,
    dm_policy: str,
    dm_allow_from_csv: str,
    group_policy: str,
    group_allow_from_csv: str,
    room_allowlist_csv: str,
):
    """Configure the Matrix channel in openclaw.json."""
    valid_auto_join = {"always", "allowlist", "off"}
    valid_dm_policies = {"pairing", "allowlist", "open", "disabled"}
    valid_group_policies = {"open", "allowlist", "disabled"}

    if auto_join not in valid_auto_join:
        print(f"ERROR: Invalid Matrix autoJoin '{auto_join}'. Must be one of {sorted(valid_auto_join)}")
        return False
    if dm_policy not in valid_dm_policies:
        print(f"ERROR: Invalid Matrix DM policy '{dm_policy}'. Must be one of {sorted(valid_dm_policies)}")
        return False
    if group_policy not in valid_group_policies:
        print(f"ERROR: Invalid Matrix group policy '{group_policy}'. Must be one of {sorted(valid_group_policies)}")
        return False

    cfg = read_config()
    if cfg is None:
        cfg = {}

    channels = cfg.get("channels")
    if not isinstance(channels, dict):
        channels = {}
        cfg["channels"] = channels

    matrix = channels.get("matrix")
    if not isinstance(matrix, dict):
        matrix = {}
        channels["matrix"] = matrix

    if not enabled:
        if matrix.get("enabled") is not False:
            matrix["enabled"] = False
            if write_config(cfg):
                print("INFO: Matrix channel disabled")
                return True
            print("ERROR: Failed to write Matrix disabled state")
            return False
        print("INFO: Matrix channel already disabled")
        return True

    if not homeserver.strip():
        print("WARN: Matrix is enabled in add-on settings but matrix_homeserver is empty; leaving channel disabled.")
        matrix["enabled"] = False
        return write_config(cfg)

    if not access_token.strip() and not (user_id.strip() and password.strip()):
        print(
            "WARN: Matrix is enabled but no usable auth was provided. "
            "Set matrix_access_token or matrix_user_id + matrix_password."
        )
        matrix["enabled"] = False
        return write_config(cfg)

    changes = []

    desired_dm_allow_from = parse_csv_values(dm_allow_from_csv)
    desired_group_allow_from = parse_csv_values(group_allow_from_csv)
    desired_room_allowlist = parse_csv_values(room_allowlist_csv)

    def set_key(target: dict, key: str, value, redact: bool = False):
        if target.get(key) != value:
            target[key] = value
            rendered = "<redacted>" if redact and value else repr(value)
            changes.append(f"{key}: set to {rendered}")

    set_key(matrix, "enabled", True)
    set_key(matrix, "homeserver", homeserver.strip())
    set_key(matrix, "allowPrivateNetwork", bool(allow_private_network))
    set_key(matrix, "encryption", bool(encryption))
    set_key(matrix, "autoJoin", auto_join)
    set_key(matrix, "groupPolicy", group_policy)

    if auto_join == "allowlist":
        set_key(matrix, "autoJoinAllowlist", desired_room_allowlist)
    elif "autoJoinAllowlist" in matrix:
        del matrix["autoJoinAllowlist"]
        changes.append("autoJoinAllowlist: removed")

    if desired_group_allow_from:
        set_key(matrix, "groupAllowFrom", desired_group_allow_from)
    elif "groupAllowFrom" in matrix:
        del matrix["groupAllowFrom"]
        changes.append("groupAllowFrom: removed")

    dm_cfg = matrix.get("dm")
    if not isinstance(dm_cfg, dict):
        dm_cfg = {}
        matrix["dm"] = dm_cfg
    set_key(dm_cfg, "policy", dm_policy)
    if dm_policy == "open" and not desired_dm_allow_from:
        desired_dm_allow_from = ["*"]
    if desired_dm_allow_from:
        set_key(dm_cfg, "allowFrom", desired_dm_allow_from)
    elif "allowFrom" in dm_cfg:
        del dm_cfg["allowFrom"]
        changes.append("dm.allowFrom: removed")

    desired_groups = {}
    for room in desired_room_allowlist:
        desired_groups[room] = {"requireMention": True}
    if desired_groups:
        existing_groups = matrix.get("groups")
        if not isinstance(existing_groups, dict):
            existing_groups = {}
        for room, entry in desired_groups.items():
            if existing_groups.get(room) != entry:
                existing_groups[room] = entry
                changes.append(f"groups.{room}: set")
        matrix["groups"] = existing_groups
    elif group_policy != "allowlist":
        # In open mode the allowlist is optional; remove only empty repo-managed groups map.
        existing_groups = matrix.get("groups")
        if isinstance(existing_groups, dict) and not existing_groups:
            del matrix["groups"]
            changes.append("groups: removed empty map")

    if user_id.strip():
        set_key(matrix, "userId", user_id.strip())
    elif "userId" in matrix:
        del matrix["userId"]
        changes.append("userId: removed")

    if access_token.strip():
        set_key(matrix, "accessToken", access_token.strip(), redact=True)
        if "password" in matrix:
            del matrix["password"]
            changes.append("password: removed because accessToken is preferred")
    elif password.strip():
        set_key(matrix, "password", password.strip(), redact=True)
        if "accessToken" in matrix:
            del matrix["accessToken"]
            changes.append("accessToken: removed because password login is configured")

    if changes:
        if write_config(cfg):
            print("INFO: Updated Matrix channel settings: " + ", ".join(changes))
            return True
        print("ERROR: Failed to write Matrix channel settings")
        return False

    print("INFO: Matrix channel settings already correct")
    return True


def main():
    """CLI entry point for use by run.sh"""
    if len(sys.argv) < 2:
        print("Usage: oc_config_helper.py <command> [args...]")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == "apply-gateway-settings":
        if len(sys.argv) != 9:
            print("Usage: oc_config_helper.py apply-gateway-settings <local|remote> <remote_url> <loopback|lan|tailnet> <port> <enable_openai_api:true|false> <auth_mode:token|trusted-proxy> <trusted_proxies_csv>")
            sys.exit(1)
        mode = sys.argv[2]
        remote_url = sys.argv[3]
        bind_mode = sys.argv[4]
        port = int(sys.argv[5])
        enable_openai_api = sys.argv[6].lower() == "true"
        auth_mode = sys.argv[7]
        trusted_proxies_csv = sys.argv[8]
        success = apply_gateway_settings(mode, remote_url, bind_mode, port, enable_openai_api, auth_mode, trusted_proxies_csv)
        sys.exit(0 if success else 1)
    
    elif cmd == "get":
        if len(sys.argv) != 3:
            print("Usage: oc_config_helper.py get <key>")
            sys.exit(1)
        key = sys.argv[2]
        value = get_gateway_setting(key)
        if value is not None:
            print(value)
        sys.exit(0)
    
    elif cmd == "set-control-ui-origins":
        if len(sys.argv) not in (3, 4, 5):
            print("Usage: oc_config_helper.py set-control-ui-origins <origins_csv> [additional_origins_csv] [disable_device_auth:true|false]")
            sys.exit(1)
        origins_csv = sys.argv[2]
        additional_origins_csv = sys.argv[3] if len(sys.argv) >= 4 else ""
        disable_device_auth = True
        if len(sys.argv) == 5:
            disable_device_auth = sys.argv[4].strip().lower() == "true"
        success = set_control_ui_origins(origins_csv, additional_origins_csv, disable_device_auth)
        sys.exit(0 if success else 1)
    
    elif cmd == "configure-exec-approvals":
        if len(sys.argv) != 3:
            print("Usage: oc_config_helper.py configure-exec-approvals <true|false>")
            sys.exit(1)
        disable_exec_approvals = sys.argv[2].strip().lower() == "true"
        success = configure_exec_approval_policy(disable_exec_approvals)
        sys.exit(0 if success else 1)

    elif cmd == "configure-matrix-channel":
        if len(sys.argv) != 15:
            print(
                "Usage: oc_config_helper.py configure-matrix-channel "
                "<enabled:true|false> <homeserver> <allow_private_network:true|false> "
                "<user_id> <password> <access_token> <encryption:true|false> <auto_join> "
                "<dm_policy> <dm_allow_from_csv> <group_policy> <group_allow_from_csv> <room_allowlist_csv>"
            )
            sys.exit(1)
        success = configure_matrix_channel(
            sys.argv[2].strip().lower() == "true",
            sys.argv[3],
            sys.argv[4].strip().lower() == "true",
            sys.argv[5],
            sys.argv[6],
            sys.argv[7],
            sys.argv[8].strip().lower() == "true",
            sys.argv[9],
            sys.argv[10],
            sys.argv[11],
            sys.argv[12],
            sys.argv[13],
            sys.argv[14],
        )
        sys.exit(0 if success else 1)

    elif cmd == "set":
        if len(sys.argv) != 4:
            print("Usage: oc_config_helper.py set <key> <value>")
            sys.exit(1)
        key = sys.argv[2]
        value = sys.argv[3]
        # Try to convert to int if it looks like a number
        try:
            value = int(value)
        except ValueError:
            pass
        success = set_gateway_setting(key, value)
        sys.exit(0 if success else 1)
    
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)


if __name__ == "__main__":
    main()
