#!/usr/bin/env bash

config_dir_has_user_state() {
  local config_dir="${1:?config_dir required}"
  find "$config_dir" -mindepth 1 -maxdepth 1 \
    ! -name '.gitdakky-legacy-migration' \
    ! -name '.gitdakky-migration-*' \
    -print -quit 2>/dev/null | grep -q .
}

legacy_migration_precheck() {
  local migration_flag="${1:?migration_flag required}"
  local config_dir="${2:?config_dir required}"
  local supervisor_token="${3:-}"
  local addon_configs_dir="${4:?addon_configs_dir required}"

  if [ -f "$migration_flag" ]; then
    echo "already-evaluated"
    return 0
  fi

  if config_dir_has_user_state "$config_dir"; then
    echo "skipped-existing"
    return 0
  fi

  if [ -z "$supervisor_token" ]; then
    echo "skipped-no-supervisor"
    return 0
  fi

  if [ ! -d "$addon_configs_dir" ]; then
    echo "skipped-no-addon-configs"
    return 0
  fi

  echo "proceed"
}

legacy_agent_state_needs_migration() {
  local legacy_agent_state_dir="${1:?legacy_agent_state_dir required}"
  local legacy_sessions_dir="${2:?legacy_sessions_dir required}"
  local default_agent_state_dir="${3:?default_agent_state_dir required}"
  local default_agent_sessions_dir="${4:?default_agent_sessions_dir required}"

  if [ -d "$legacy_agent_state_dir" ] && [ ! -f "$default_agent_state_dir/auth-profiles.json" ] && [ -f "$legacy_agent_state_dir/auth-profiles.json" ]; then
    return 0
  fi

  if [ -d "$legacy_sessions_dir" ] && find "$legacy_sessions_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
    if ! find "$default_agent_sessions_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
      return 0
    fi
  fi

  return 1
}

parse_remote_gateway_url() {
  local remote_url="${1:-}"
  python3 - "$remote_url" <<'PY'
import shlex
import sys
from urllib.parse import urlparse

url = (sys.argv[1] or "").strip()
parsed = urlparse(url)

if parsed.scheme not in ("ws", "wss") or not parsed.hostname:
    escaped = url.replace('"', '\\"')
    print(f'echo "ERROR: Invalid gateway.remote.url (expected ws:// or wss://): {escaped}"')
    print("return 1")
    raise SystemExit(0)

port = parsed.port or (443 if parsed.scheme == "wss" else 80)
tls_flag = "--tls" if parsed.scheme == "wss" else ""

print(f"NODE_HOST={shlex.quote(parsed.hostname)}")
print(f"NODE_PORT={port}")
print(f"NODE_TLS_FLAG={shlex.quote(tls_flag)}")
PY
}

sync_gateway_settings_from_options() {
  local options_file="${1:?options_file required}"
  local helper_path="${2:?helper_path required}"
  local openclaw_config_path="${3:?openclaw_config_path required}"
  local effective_gw_port="${4:?effective_gw_port required}"

  local gateway_mode
  local gateway_remote_url
  local gateway_bind_mode
  local enable_openai_api
  local gateway_auth_mode
  local gateway_trusted_proxies

  gateway_mode="$(jq -r '.gateway_mode // "local"' "$options_file")"
  gateway_remote_url="$(jq -r '.gateway_remote_url // empty' "$options_file")"
  gateway_bind_mode="$(jq -r '.gateway_bind_mode // "loopback"' "$options_file")"
  enable_openai_api="$(jq -r '.enable_openai_api // false' "$options_file")"
  gateway_auth_mode="$(jq -r '.gateway_auth_mode // "token"' "$options_file")"
  gateway_trusted_proxies="$(jq -r '.gateway_trusted_proxies // empty' "$options_file")"

  OPENCLAW_CONFIG_PATH="$openclaw_config_path" python3 "$helper_path" apply-gateway-settings \
    "$gateway_mode" \
    "$gateway_remote_url" \
    "$gateway_bind_mode" \
    "$effective_gw_port" \
    "$enable_openai_api" \
    "$gateway_auth_mode" \
    "$gateway_trusted_proxies"
}
