#!/usr/bin/env bash
set -euo pipefail

# Ensure Homebrew and brew-installed binaries are in PATH
# This is needed for OpenClaw skills that depend on CLI tools (gemini, aider, etc.)
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

# Home Assistant add-on options are usually rendered to /data/options.json
OPTIONS_FILE="/data/options.json"
LEGACY_ADDON_SLUG="openclaw_assistant"
SELF_ADDON_NAME="OpenClaw Super Home Assistant"
MIGRATION_FLAG="/config/.gitdakky-legacy-migration"
MIGRATED_OPTIONS_FILE="/tmp/openclaw-super-home-assistant-options.json"
DEFAULT_TERMINAL_PORT="7682"
DEFAULT_GATEWAY_PORT="18790"
DEFAULT_INGRESS_PORT="48109"
DEFAULT_DASHBOARD_API_PORT="48110"
BOOTSTRAP_SOURCE_DIR="/opt/openclaw-super/bootstrap-workspace"
BUNDLED_SKILLS_SOURCE_DIR="/opt/openclaw-super/bundled-skills"
OPENCLAW_CONFIG_PATH="/config/.openclaw/openclaw.json"
RUNTIME_RESTART_REQUEST_FILE="/tmp/openclaw-runtime-restart.request"
MANAGED_COMMAND_ACTIVE_FILE="/tmp/openclaw-managed-command.active"
RUNTIME_WRAPPER_LOG_DIR="/tmp/openclaw"
RUNTIME_WRAPPER_LOG_FILE="${RUNTIME_WRAPPER_LOG_DIR}/openclaw-super-runtime-wrapper.log"

if [ ! -f "$OPTIONS_FILE" ]; then
  echo "Missing $OPTIONS_FILE (add-on options)."
  exit 1
fi

supervisor_api() {
  local method="$1"
  local path="$2"
  shift 2

  if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
    return 1
  fi

  curl -fsSL -X "$method" \
    -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    -H "Content-Type: application/json" \
    "http://supervisor${path}" \
    "$@"
}

config_dir_has_user_state() {
  find /config -mindepth 1 -maxdepth 1 \
    ! -name '.gitdakky-legacy-migration' \
    ! -name '.gitdakky-migration-*' \
    -print -quit 2>/dev/null | grep -q .
}

maybe_migrate_legacy_addon() {
  local legacy_addons_json legacy_slug legacy_repo legacy_ref legacy_dir legacy_info legacy_name legacy_state
  local legacy_options_json stop_ok=false

  if [ -f "$MIGRATION_FLAG" ]; then
    echo "INFO: Legacy migration already evaluated for this install."
    return 0
  fi

  if config_dir_has_user_state; then
    echo "INFO: Existing ${SELF_ADDON_NAME} state detected; skipping legacy migration."
    printf 'skipped-existing\n' > "$MIGRATION_FLAG"
    return 0
  fi

  if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
    echo "INFO: Supervisor API unavailable; skipping legacy migration."
    return 0
  fi

  if [ ! -d /addon_configs ]; then
    echo "INFO: /addon_configs is not mounted; skipping legacy migration."
    return 0
  fi

  legacy_addons_json="$(supervisor_api GET /addons 2>/dev/null || true)"
  if [ -z "$legacy_addons_json" ]; then
    echo "INFO: Could not query installed add-ons; skipping legacy migration."
    return 0
  fi

  legacy_slug="$(printf '%s' "$legacy_addons_json" | jq -r '
    .data.addons[]?
    | (.slug // empty)
    | select(. == "openclaw_assistant" or endswith("_openclaw_assistant"))
  ' | head -n1)"

  legacy_repo="$(printf '%s' "$legacy_addons_json" | jq -r '
    .data.addons[]?
    | select((.slug // "") == "openclaw_assistant" or ((.slug // "") | endswith("_openclaw_assistant")))
    | (.repository // empty)
  ' | head -n1)"

  if [ -z "$legacy_slug" ] && [ -z "$legacy_repo" ]; then
    echo "INFO: No legacy OpenClaw Assistant install detected."
    return 0
  fi

  if [ -z "$legacy_slug" ]; then
    legacy_slug="$LEGACY_ADDON_SLUG"
  fi

  if [ -z "$legacy_repo" ] && [[ "$legacy_slug" == *"_${LEGACY_ADDON_SLUG}" ]]; then
    legacy_repo="${legacy_slug%_${LEGACY_ADDON_SLUG}}"
  fi

  if [ "$legacy_slug" = "$LEGACY_ADDON_SLUG" ] && [ -n "$legacy_repo" ]; then
    legacy_ref="${legacy_repo}_${LEGACY_ADDON_SLUG}"
  else
    legacy_ref="$legacy_slug"
  fi

  legacy_dir=""
  if [ -n "$legacy_repo" ]; then
    legacy_dir="/addon_configs/${legacy_repo}_${LEGACY_ADDON_SLUG}"
  else
    legacy_dir="$(find /addon_configs -maxdepth 1 -type d -name "*_${LEGACY_ADDON_SLUG}" | head -n1)"
  fi

  if [ -z "$legacy_dir" ] || [ ! -d "$legacy_dir" ]; then
    echo "INFO: Legacy add-on was detected via Supervisor API but its config directory was not found."
    printf 'skipped-no-config\n' > "$MIGRATION_FLAG"
    return 0
  fi

  legacy_info="$(supervisor_api GET "/addons/${legacy_ref}/info" 2>/dev/null || true)"
  if [ -z "$legacy_info" ] && [ "$legacy_ref" != "$LEGACY_ADDON_SLUG" ]; then
    legacy_info="$(supervisor_api GET "/addons/${LEGACY_ADDON_SLUG}/info" 2>/dev/null || true)"
  fi

  legacy_name="$(printf '%s' "$legacy_info" | jq -r '.data.name // "OpenClaw Assistant"' 2>/dev/null || echo "OpenClaw Assistant")"
  legacy_state="$(printf '%s' "$legacy_info" | jq -r '.data.state // empty' 2>/dev/null || true)"
  legacy_options_json="$(printf '%s' "$legacy_info" | jq -c '.data.options // {}' 2>/dev/null || echo '{}')"

  if [ "$legacy_state" = "started" ] || [ "$legacy_state" = "startup" ]; then
    echo "INFO: Stopping legacy add-on '${legacy_name}' (${legacy_ref}) before migration..."
    if supervisor_api POST "/addons/${legacy_ref}/stop" >/dev/null 2>&1 || \
       supervisor_api POST "/addons/${LEGACY_ADDON_SLUG}/stop" >/dev/null 2>&1; then
      stop_ok=true
      echo "INFO: Legacy add-on stopped successfully."
    else
      echo "WARN: Could not stop the legacy add-on automatically. Port conflicts may still occur."
    fi
  fi

  echo "INFO: Importing legacy add-on data from ${legacy_dir} ..."
  mkdir -p /config
  rsync -a "${legacy_dir}/" /config/

  if [ -n "$legacy_options_json" ] && [ "$legacy_options_json" != "{}" ]; then
    printf '%s\n' "$legacy_options_json" > "$MIGRATED_OPTIONS_FILE"
    supervisor_api POST /addons/self/options \
      --data "$(jq -cn --argjson options "$legacy_options_json" '{options: $options}')" >/dev/null 2>&1 || \
      echo "WARN: Could not persist migrated add-on options to Supervisor; current boot will still use them."
    OPTIONS_FILE="$MIGRATED_OPTIONS_FILE"
  fi

  {
    echo "source=${legacy_ref}"
    echo "stopped=${stop_ok}"
    echo "imported=true"
  } > "$MIGRATION_FLAG"

  echo "INFO: Legacy migration completed from '${legacy_name}'."
}

maybe_migrate_legacy_addon

# ------------------------------------------------------------------------------
# Read add-on options (only add-on-specific knobs; OpenClaw is configured via onboarding)
# ------------------------------------------------------------------------------

TZNAME=$(jq -r '.timezone // "Europe/Sofia"' "$OPTIONS_FILE")
GW_PUBLIC_URL=$(jq -r '.gateway_public_url // empty' "$OPTIONS_FILE")
HA_TOKEN=$(jq -r '.homeassistant_token // empty' "$OPTIONS_FILE")
ENABLE_BUILTIN_HA_TOOLS=$(jq -r '.enable_builtin_ha_tools // true' "$OPTIONS_FILE")
ENABLE_HA_SERVICE_CALLS=$(jq -r '.enable_ha_service_calls // false' "$OPTIONS_FILE")
ADDON_HTTP_PROXY=$(jq -r '.http_proxy // empty' "$OPTIONS_FILE")
ENABLE_TERMINAL=$(jq -r '.enable_terminal // true' "$OPTIONS_FILE")
TERMINAL_PORT_RAW="$(jq -r --arg default_port "$DEFAULT_TERMINAL_PORT" '.terminal_port // ($default_port | tonumber)' "$OPTIONS_FILE")"

# SECURITY: Validate TERMINAL_PORT to prevent nginx config injection
# Only allow numeric values in valid port range (1024-65535)
if [[ "$TERMINAL_PORT_RAW" =~ ^[0-9]+$ ]] && [ "$TERMINAL_PORT_RAW" -ge 1024 ] && [ "$TERMINAL_PORT_RAW" -le 65535 ]; then
  TERMINAL_PORT="$TERMINAL_PORT_RAW"
else
  echo "ERROR: Invalid terminal_port '$TERMINAL_PORT_RAW'. Must be numeric 1024-65535. Using default ${DEFAULT_TERMINAL_PORT}."
  TERMINAL_PORT="$DEFAULT_TERMINAL_PORT"
fi

echo "DEBUG: enable_terminal config value: '$ENABLE_TERMINAL'"
echo "DEBUG: terminal_port config value: '$TERMINAL_PORT' (validated)"

# Generic router SSH settings
ROUTER_HOST=$(jq -r '.router_ssh_host // empty' "$OPTIONS_FILE")
ROUTER_USER=$(jq -r '.router_ssh_user // empty' "$OPTIONS_FILE")
ROUTER_KEY=$(jq -r '.router_ssh_key_path // "/data/keys/router_ssh"' "$OPTIONS_FILE")

# Optional: allow disabling lock cleanup if you ever need to debug
CLEAN_LOCKS_ON_START=$(jq -r '.clean_session_locks_on_start // true' "$OPTIONS_FILE")
CLEAN_LOCKS_ON_EXIT=$(jq -r '.clean_session_locks_on_exit // true' "$OPTIONS_FILE")

# Gateway configuration
GATEWAY_MODE=$(jq -r '.gateway_mode // "local"' "$OPTIONS_FILE")
GATEWAY_REMOTE_URL=$(jq -r '.gateway_remote_url // empty' "$OPTIONS_FILE")
GATEWAY_BIND_MODE=$(jq -r '.gateway_bind_mode // "loopback"' "$OPTIONS_FILE")
GATEWAY_PORT="$(jq -r --arg default_port "$DEFAULT_GATEWAY_PORT" '.gateway_port // ($default_port | tonumber)' "$OPTIONS_FILE")"
ENABLE_OPENAI_API=$(jq -r '.enable_openai_api // false' "$OPTIONS_FILE")
GATEWAY_AUTH_MODE=$(jq -r '.gateway_auth_mode // "token"' "$OPTIONS_FILE")
GATEWAY_TRUSTED_PROXIES=$(jq -r '.gateway_trusted_proxies // empty' "$OPTIONS_FILE")
GATEWAY_ADDITIONAL_ALLOWED_ORIGINS=$(jq -r '.gateway_additional_allowed_origins // empty' "$OPTIONS_FILE")
CONTROLUI_DISABLE_DEVICE_AUTH=$(jq -r '.controlui_disable_device_auth // true' "$OPTIONS_FILE")
DISABLE_EXEC_APPROVALS=$(jq -r '.disable_exec_approvals // true' "$OPTIONS_FILE")
FORCE_IPV4_DNS=$(jq -r '.force_ipv4_dns // true' "$OPTIONS_FILE")
ACCESS_MODE=$(jq -r '.access_mode // "custom"' "$OPTIONS_FILE")
NGINX_LOG_LEVEL=$(jq -r '.nginx_log_level // "minimal"' "$OPTIONS_FILE")
AUTO_CONFIGURE_MCP=$(jq -r '.auto_configure_mcp // false' "$OPTIONS_FILE")
ENABLE_CONTEXT7=$(jq -r '.enable_context7 // false' "$OPTIONS_FILE")
CONTEXT7_API_KEY=$(jq -r '.context7_api_key // empty' "$OPTIONS_FILE")
DOMOTZ_API_KEY=$(jq -r '.domotz_api_key // empty' "$OPTIONS_FILE")
DOMOTZ_SITE_ID=$(jq -r '.domotz_site_id // empty' "$OPTIONS_FILE")
GITHUB_ISSUES_TOKEN=$(jq -r '.github_issues_token // empty' "$OPTIONS_FILE")
ENABLE_MATRIX=$(jq -r '.enable_matrix // false' "$OPTIONS_FILE")
MATRIX_HOMESERVER=$(jq -r '.matrix_homeserver // empty' "$OPTIONS_FILE")
MATRIX_ALLOW_PRIVATE_NETWORK=$(jq -r '.matrix_allow_private_network // false' "$OPTIONS_FILE")
MATRIX_USER_ID=$(jq -r '.matrix_user_id // empty' "$OPTIONS_FILE")
MATRIX_ACCESS_TOKEN=$(jq -r '.matrix_access_token // empty' "$OPTIONS_FILE")
MATRIX_PASSWORD=$(jq -r '.matrix_password // empty' "$OPTIONS_FILE")
MATRIX_ENCRYPTION=$(jq -r '.matrix_encryption // false' "$OPTIONS_FILE")
MATRIX_DM_POLICY=$(jq -r '.matrix_dm_policy // "pairing"' "$OPTIONS_FILE")
MATRIX_DM_ALLOW_FROM=$(jq -r '.matrix_dm_allow_from // empty' "$OPTIONS_FILE")
MATRIX_GROUP_POLICY=$(jq -r '.matrix_group_policy // "open"' "$OPTIONS_FILE")
MATRIX_GROUP_ALLOW_FROM=$(jq -r '.matrix_group_allow_from // empty' "$OPTIONS_FILE")
MATRIX_ROOM_ALLOWLIST=$(jq -r '.matrix_room_allowlist // empty' "$OPTIONS_FILE")
MATRIX_AUTO_JOIN=$(jq -r '.matrix_auto_join // "always"' "$OPTIONS_FILE")
MQTT_BROKER_URL=$(jq -r '.mqtt_broker_url // empty' "$OPTIONS_FILE")
MQTT_USERNAME=$(jq -r '.mqtt_username // empty' "$OPTIONS_FILE")
MQTT_PASSWORD=$(jq -r '.mqtt_password // empty' "$OPTIONS_FILE")
ENABLE_BACNET_SCOUT=$(jq -r '.enable_bacnet_scout // false' "$OPTIONS_FILE")
GW_ENV_VARS_TYPE=$(jq -r 'if .gateway_env_vars == null then "null" else (.gateway_env_vars | type) end' "$OPTIONS_FILE")
GW_ENV_VARS_RAW=$(jq -r '.gateway_env_vars // empty' "$OPTIONS_FILE")
GW_ENV_VARS_JSON=$(jq -c '.gateway_env_vars // []' "$OPTIONS_FILE")

export TZ="$TZNAME"

# ------------------------------------------------------------------------------
# Access mode presets — override individual gateway settings for common scenarios
# ------------------------------------------------------------------------------
ENABLE_HTTPS_PROXY=false
GATEWAY_INTERNAL_PORT="$GATEWAY_PORT"

case "$ACCESS_MODE" in
  local_only)
    GATEWAY_BIND_MODE="loopback"
    GATEWAY_AUTH_MODE="token"
    echo "INFO: Access mode: local_only (loopback + token, Ingress/terminal only)"
    ;;
  lan_https)
    # Gateway binds loopback on internal port; nginx terminates TLS on the external port.
    GATEWAY_BIND_MODE="loopback"
    GATEWAY_AUTH_MODE="token"
    ENABLE_HTTPS_PROXY=true
    GATEWAY_INTERNAL_PORT=$((GATEWAY_PORT + 1))
    echo "INFO: Access mode: lan_https (built-in HTTPS proxy on 0.0.0.0:${GATEWAY_PORT})"
    ;;
  lan_reverse_proxy)
    GATEWAY_BIND_MODE="lan"
    GATEWAY_AUTH_MODE="trusted-proxy"
    if [ -z "$GATEWAY_TRUSTED_PROXIES" ]; then
      echo "ERROR: access_mode=lan_reverse_proxy requires gateway_trusted_proxies to be set."
      echo "ERROR: Set it to your reverse proxy's IP/CIDR (e.g. 127.0.0.1,192.168.88.0/24)."
    fi
    echo "INFO: Access mode: lan_reverse_proxy (LAN bind + trusted-proxy auth)"
    ;;
  tailnet_https)
    GATEWAY_BIND_MODE="tailnet"
    GATEWAY_AUTH_MODE="token"
    echo "INFO: Access mode: tailnet_https (Tailscale bind + token auth)"
    ;;
  custom|*)
    echo "INFO: Access mode: custom (using individual gateway_bind_mode/auth_mode settings)"
    ;;
esac

# Reduce risk of secrets ending up in logs
set +x

# Optional outbound proxy from add-on settings.
# If set, apply it to both HTTP and HTTPS for Node/undici/OpenClaw tooling.
if [ -n "$ADDON_HTTP_PROXY" ]; then
  if [[ "$ADDON_HTTP_PROXY" =~ ^https?://[^[:space:]]+$ ]]; then
    # Keep local traffic direct to avoid accidental proxying of loopback/LAN services.
    DEFAULT_NO_PROXY="localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,.local"

    export HTTP_PROXY="$ADDON_HTTP_PROXY"
    export HTTPS_PROXY="$ADDON_HTTP_PROXY"
    export http_proxy="$ADDON_HTTP_PROXY"
    export https_proxy="$ADDON_HTTP_PROXY"
    export NO_PROXY="${NO_PROXY:+${NO_PROXY},}${DEFAULT_NO_PROXY}"
    export no_proxy="${no_proxy:+${no_proxy},}${DEFAULT_NO_PROXY}"
    echo "INFO: Outbound HTTP/HTTPS proxy enabled from add-on configuration."
    echo "INFO: Applied NO_PROXY defaults for localhost/private network ranges."
  else
    echo "WARN: Invalid http_proxy value in add-on options; expected URL like http://host:port"
  fi
fi

# Optional network hardening/workaround: force IPv4-first DNS ordering for Node.js.
# Helps in environments where IPv6 resolves but has no working egress.
if [ "$FORCE_IPV4_DNS" = "true" ] || [ "$FORCE_IPV4_DNS" = "1" ]; then
  if [ -n "${NODE_OPTIONS:-}" ]; then
    export NODE_OPTIONS="${NODE_OPTIONS} --dns-result-order=ipv4first"
  else
    export NODE_OPTIONS="--dns-result-order=ipv4first"
  fi
  echo "INFO: Enabled IPv4-first DNS ordering (NODE_OPTIONS=--dns-result-order=ipv4first)"
fi

# Home Assistant maps addon_config to /addon_configs/{REPO}_{SLUG} on the host.
export HOME=/config

# Explicitly set OpenClaw directories to ensure they persist across add-on updates
# This prevents loss of installed skills, configuration, and workspace state
export OPENCLAW_CONFIG_DIR=/config/.openclaw
export OPENCLAW_WORKSPACE_DIR=/config/clawd
export XDG_CONFIG_HOME=/config
export OPENCLAW_SKILLS_DIR=/config/.openclaw/skills
export OPENCLAW_SYSTEM_GRAPH_PATH=/config/.openclaw/gitdakky-system-graph.sqlite3
export HA_REST_BASE_URL="http://supervisor/core/api"
export HA_WS_URL="ws://supervisor/core/websocket"
export HA_WRITE_TOOLS_ENABLED="$ENABLE_HA_SERVICE_CALLS"

mkdir -p /config/.openclaw /config/.openclaw/identity /config/clawd /config/keys /config/secrets

seed_managed_workspace_files() {
  if [ ! -d "$BOOTSTRAP_SOURCE_DIR" ]; then
    echo "WARN: Managed workspace bootstrap directory missing at $BOOTSTRAP_SOURCE_DIR"
    return 0
  fi

  mkdir -p "$OPENCLAW_WORKSPACE_DIR"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --ignore-existing "${BOOTSTRAP_SOURCE_DIR}/" "${OPENCLAW_WORKSPACE_DIR}/" 2>/dev/null || true
  else
    find "$BOOTSTRAP_SOURCE_DIR" -maxdepth 1 -type f -name '*.md' -print0 | while IFS= read -r -d '' source_file; do
      target_file="${OPENCLAW_WORKSPACE_DIR}/$(basename "$source_file")"
      [ -f "$target_file" ] || cp "$source_file" "$target_file"
    done
  fi
  echo "INFO: Seeded managed workspace bootstrap files into ${OPENCLAW_WORKSPACE_DIR}"
}

seed_managed_workspace_files

DEFAULT_AGENT_ID="main"
DEFAULT_AGENT_ROOT="/config/.openclaw/agents/${DEFAULT_AGENT_ID}"
DEFAULT_AGENT_STATE_DIR="${DEFAULT_AGENT_ROOT}/agent"
DEFAULT_AGENT_SESSIONS_DIR="${DEFAULT_AGENT_ROOT}/sessions"
LEGACY_AGENT_STATE_DIR="/config/.openclaw/agent"
LEGACY_SESSIONS_DIR="/config/.openclaw/sessions"
LEGACY_STATE_MIGRATION_MARKER="/config/.openclaw/.gitdakky-agent-layout-migration"

ensure_default_agent_layout() {
  mkdir -p "$DEFAULT_AGENT_STATE_DIR" "$DEFAULT_AGENT_SESSIONS_DIR"
  chmod 700 "$DEFAULT_AGENT_ROOT" "$DEFAULT_AGENT_STATE_DIR" "$DEFAULT_AGENT_SESSIONS_DIR" 2>/dev/null || true
}

legacy_agent_state_needs_migration() {
  if [ -d "$LEGACY_AGENT_STATE_DIR" ] && [ ! -f "$DEFAULT_AGENT_STATE_DIR/auth-profiles.json" ] && [ -f "$LEGACY_AGENT_STATE_DIR/auth-profiles.json" ]; then
    return 0
  fi

  if [ -d "$LEGACY_SESSIONS_DIR" ] && find "$LEGACY_SESSIONS_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
    if ! find "$DEFAULT_AGENT_SESSIONS_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .; then
      return 0
    fi
  fi

  return 1
}

run_safe_doctor_state_migration() {
  local log_file="/tmp/openclaw-doctor-migration.log"

  if ! legacy_agent_state_needs_migration; then
    return 0
  fi

  echo "INFO: Running safe OpenClaw doctor migration for legacy agent/session layout..."
  if openclaw doctor --non-interactive >"$log_file" 2>&1; then
    echo "INFO: OpenClaw doctor completed safe migrations."
  else
    echo "WARN: openclaw doctor --non-interactive did not complete cleanly; falling back to direct state sync."
    tail -n 20 "$log_file" 2>/dev/null || true
  fi
}

fallback_sync_default_agent_state() {
  local migrated_any=false

  ensure_default_agent_layout

  if [ -d "$LEGACY_AGENT_STATE_DIR" ]; then
    echo "INFO: Syncing legacy agent state into ${DEFAULT_AGENT_STATE_DIR} ..."
    rsync -a --ignore-existing "${LEGACY_AGENT_STATE_DIR}/" "${DEFAULT_AGENT_STATE_DIR}/"
    migrated_any=true
  fi

  if [ -d "$LEGACY_SESSIONS_DIR" ]; then
    echo "INFO: Syncing legacy sessions into ${DEFAULT_AGENT_SESSIONS_DIR} ..."
    rsync -a --ignore-existing "${LEGACY_SESSIONS_DIR}/" "${DEFAULT_AGENT_SESSIONS_DIR}/"
    migrated_any=true
  fi

  if [ -f "$DEFAULT_AGENT_STATE_DIR/auth-profiles.json" ]; then
    chmod 600 "$DEFAULT_AGENT_STATE_DIR/auth-profiles.json" 2>/dev/null || true
  fi

  if [ "$migrated_any" = true ]; then
    {
      echo "migrated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "source_agent_dir=${LEGACY_AGENT_STATE_DIR}"
      echo "source_sessions_dir=${LEGACY_SESSIONS_DIR}"
    } > "$LEGACY_STATE_MIGRATION_MARKER"
  fi
}

reconcile_default_agent_state() {
  ensure_default_agent_layout

  if ! legacy_agent_state_needs_migration; then
    return 0
  fi

  run_safe_doctor_state_migration

  if legacy_agent_state_needs_migration; then
    echo "INFO: Legacy state still present after doctor; copying missing files into agents/${DEFAULT_AGENT_ID}/..."
    fallback_sync_default_agent_state
  fi
}

# ------------------------------------------------------------------------------
# Sync built-in OpenClaw skills from image to persistent storage
# On each startup, copy new/updated built-in skills so they survive rebuilds.
# We sync them to /config/.openclaw/skills and symlink back.
# NOTE: We cannot use `npm root -g` here because HOME=/config may contain a
# persisted .npmrc with a custom prefix from a previous run. Instead, we
# resolve the real image path by temporarily overriding HOME.
# ------------------------------------------------------------------------------
IMAGE_SKILLS_DIR="$(HOME=/root npm root -g 2>/dev/null)/openclaw/skills"
PERSISTENT_SKILLS_DIR="/config/.openclaw/skills"

if [ -d "$IMAGE_SKILLS_DIR" ] && [ ! -L "$IMAGE_SKILLS_DIR" ]; then
  mkdir -p "$PERSISTENT_SKILLS_DIR"
  # Sync skills: --update replaces older files so upgrades propagate,
  # but doesn't delete user-added files in persistent storage.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --update "$IMAGE_SKILLS_DIR/" "$PERSISTENT_SKILLS_DIR/" 2>/dev/null || true
  else
    cp -ru "$IMAGE_SKILLS_DIR/"* "$PERSISTENT_SKILLS_DIR/" 2>/dev/null || true
  fi
  # Replace image skills dir with symlink to persistent copy
  rm -rf "$IMAGE_SKILLS_DIR"
  ln -sf "$PERSISTENT_SKILLS_DIR" "$IMAGE_SKILLS_DIR"
  echo "INFO: Synced built-in skills to persistent storage at $PERSISTENT_SKILLS_DIR"
elif [ -L "$IMAGE_SKILLS_DIR" ]; then
  echo "INFO: Built-in skills already linked to persistent storage"
else
  echo "WARN: Built-in skills directory not found at $IMAGE_SKILLS_DIR"
fi

seed_bundled_skill_pack() {
  if [ ! -d "$BUNDLED_SKILLS_SOURCE_DIR" ]; then
    echo "WARN: Managed bundled skills directory missing at $BUNDLED_SKILLS_SOURCE_DIR"
    return 0
  fi

  mkdir -p "$PERSISTENT_SKILLS_DIR"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --ignore-existing "${BUNDLED_SKILLS_SOURCE_DIR}/" "${PERSISTENT_SKILLS_DIR}/" 2>/dev/null || true
  else
    find "$BUNDLED_SKILLS_SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' source_dir; do
      target_dir="${PERSISTENT_SKILLS_DIR}/$(basename "$source_dir")"
      [ -d "$target_dir" ] || cp -R "$source_dir" "$target_dir"
    done
  fi
  echo "INFO: Seeded GitDakky bundled skills into ${PERSISTENT_SKILLS_DIR}"
}

seed_bundled_skill_pack

# ------------------------------------------------------------------------------
# Persist user-installed node skills across Docker image rebuilds
# Redirect npm/pnpm global installs to /config/.node_global (persistent storage)
# so that skills installed via the dashboard survive container rebuilds.
# NOTE: This MUST come after the skills sync above (which needs the original npm root -g).
# ------------------------------------------------------------------------------
PERSISTENT_NODE_GLOBAL="/config/.node_global"
mkdir -p "$PERSISTENT_NODE_GLOBAL"
npm config set prefix "$PERSISTENT_NODE_GLOBAL" 2>/dev/null || true
export PATH="${PERSISTENT_NODE_GLOBAL}/bin:${PATH}"
export NODE_PATH="${PERSISTENT_NODE_GLOBAL}/lib/node_modules:${NODE_PATH:-}"

# Also configure pnpm global dir to persistent storage
export PNPM_HOME="${PERSISTENT_NODE_GLOBAL}/pnpm"
mkdir -p "$PNPM_HOME"
export PATH="${PNPM_HOME}:${PATH}"

# Protect critical runtime variables from accidental override via gateway_env_vars.
is_reserved_gateway_env_var() {
  case "$1" in
    # Critical runtime paths/process vars.
    HOME|PATH|PWD|OLDPWD|SHLVL|TZ|XDG_CONFIG_HOME|PNPM_HOME|NODE_PATH|NODE_OPTIONS|NODE_NO_WARNINGS)
      return 0
      ;;
    # Low-level injection vectors that can alter process/linker/shell behavior.
    LD_*|DYLD_*|BASH_ENV|ENV|BASH_FUNC_*)
      return 0
      ;;
    # Proxy vars managed by add-on options.
    HTTP_PROXY|HTTPS_PROXY|NO_PROXY|http_proxy|https_proxy|no_proxy)
      return 0
      ;;
    # Add-on internal control vars.
    OPENCLAW_*|HA_REST_BASE_URL|HA_WS_URL|HA_WRITE_TOOLS_ENABLED|SUPERVISOR_TOKEN)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

try_export_gateway_env_var() {
  local key="$1"
  local value="$2"

  if [ -z "$key" ]; then
    return 0
  fi

  # Validate variable name format
  if ! [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "WARN: Invalid environment variable name: '$key' (must start with letter/underscore, skip)"
    return 0
  fi

  # Protect critical runtime variables from accidental override.
  if is_reserved_gateway_env_var "$key"; then
    echo "WARN: Reserved environment variable '$key' cannot be overridden via gateway_env_vars (skip)"
    return 0
  fi

  # Enforce max variable name length
  if [ ${#key} -gt $max_var_name_size ]; then
    echo "WARN: Environment variable name too long: '$key' (max $max_var_name_size chars, skip)"
    return 0
  fi

  # Enforce max variable value length
  if [ ${#value} -gt $max_var_value_size ]; then
    echo "WARN: Environment variable value too long for '$key' (max $max_var_value_size chars, skip)"
    return 0
  fi

  # Enforce limit on number of variables
  if [ $env_count -ge $max_env_vars ]; then
    echo "WARN: Maximum environment variables limit ($max_env_vars) reached (skip)"
    return 0
  fi

  export "$key=$value"
  env_count=$((env_count + 1))
  echo "INFO: Exported gateway env var: $key"
}

# Export gateway environment variables from add-on config
# These are user-defined variables that should be available to the gateway process.
# Primary format: array of {name, value} objects.
if [ "$GW_ENV_VARS_TYPE" = "array" ] || [ "$GW_ENV_VARS_TYPE" = "object" ] || { [ "$GW_ENV_VARS_TYPE" = "string" ] && [ -n "$GW_ENV_VARS_RAW" ]; }; then
  env_count=0
  max_env_vars=50
  max_var_name_size=255
  max_var_value_size=10000

  if [ "$GW_ENV_VARS_TYPE" = "array" ] && [ "$GW_ENV_VARS_JSON" != "[]" ]; then
    echo "INFO: Setting gateway environment variables from list config..."

    invalid_entries_count=$(printf '%s' "$GW_ENV_VARS_JSON" | jq '[.[] | select((type != "object") or ((.name | type) != "string") or (has("value") | not))] | length')
    if [ "$invalid_entries_count" -gt 0 ]; then
      echo "WARN: Found $invalid_entries_count invalid gateway_env_vars entries; expected objects with 'name' and 'value' keys (skip)"
    fi

    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      try_export_gateway_env_var "$key" "$value"
    done < <(printf '%s' "$GW_ENV_VARS_JSON" | jq -j '.[] | select((type == "object") and ((.name | type) == "string") and (has("value"))) | .name, "\u0000", (.value | tostring), "\u0000"')
  elif [ "$GW_ENV_VARS_TYPE" = "object" ] && [ "$GW_ENV_VARS_JSON" != "{}" ]; then
    # Backward compatibility for old map/object configuration.
    echo "INFO: Setting gateway environment variables from object config (legacy format)..."
    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      try_export_gateway_env_var "$key" "$value"
    done < <(printf '%s' "$GW_ENV_VARS_JSON" | jq -j 'to_entries[] | .key, "\u0000", (.value | tostring), "\u0000"')
  elif [ "$GW_ENV_VARS_TYPE" = "string" ] && [ -n "$GW_ENV_VARS_RAW" ]; then
    # Preferred for complex values: JSON object string in one line.
    if printf '%s' "$GW_ENV_VARS_RAW" | jq -e 'type == "object"' >/dev/null 2>&1; then
      echo "INFO: Setting gateway environment variables from JSON string config..."
      while IFS= read -r -d '' key && IFS= read -r -d '' value; do
        try_export_gateway_env_var "$key" "$value"
      done < <(printf '%s' "$GW_ENV_VARS_RAW" | jq -j 'to_entries[] | .key, "\u0000", (.value | tostring), "\u0000"')
    else
      # Supported simple format: KEY=VALUE pairs separated by ';' or newlines.
      echo "INFO: Setting gateway environment variables from KEY=VALUE string config..."
      while IFS= read -r entry; do
        entry="${entry%$'\r'}"
        trimmed="$(printf '%s' "$entry" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')"

        # Skip empty lines and comments.
        if [ -z "$trimmed" ] || [[ "$trimmed" == \#* ]]; then
          continue
        fi

        if [[ "$trimmed" != *"="* ]]; then
          echo "WARN: Invalid gateway_env_vars entry '$trimmed' (expected KEY=VALUE, skip)"
          continue
        fi

        key="${trimmed%%=*}"
        value="${trimmed#*=}"
        key="$(printf '%s' "$key" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')"

        try_export_gateway_env_var "$key" "$value"
      done < <(printf '%s' "$GW_ENV_VARS_RAW" | tr ';' '\n')
    fi
  fi

  if [ $env_count -gt 0 ]; then
    echo "INFO: Successfully exported $env_count gateway environment variable(s)"
  fi
elif [ "$GW_ENV_VARS_TYPE" != "null" ]; then
  echo "WARN: Invalid gateway_env_vars format in add-on options (expected list, string or object), skipping"
fi

# ------------------------------------------------------------------------------
# Persist Linuxbrew/Homebrew across Docker image rebuilds
# Homebrew installs to /home/linuxbrew/.linuxbrew/ which is ephemeral.
# We sync it to /config/.linuxbrew and symlink back so brew-installed CLI
# tools (gog, gh, bw, etc.) survive add-on updates.
# ------------------------------------------------------------------------------
IMAGE_BREW_DIR="/home/linuxbrew/.linuxbrew"
PERSISTENT_BREW_DIR="/config/.linuxbrew"

if [ -d "$IMAGE_BREW_DIR" ] && [ ! -L "$IMAGE_BREW_DIR" ]; then
  # Image has a real Homebrew install — sync to persistent storage
  if [ -d "$PERSISTENT_BREW_DIR" ]; then
    # Persistent copy exists: sync new/updated files from image (upgrades),
    # but preserve user-installed packages already in persistent storage.
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --update "$IMAGE_BREW_DIR/" "$PERSISTENT_BREW_DIR/" 2>/dev/null || true
    else
      cp -ru "$IMAGE_BREW_DIR/"* "$PERSISTENT_BREW_DIR/" 2>/dev/null || true
    fi
    echo "INFO: Synced Homebrew updates to persistent storage"
  else
    # First time: copy entire Homebrew install to persistent storage
    cp -a "$IMAGE_BREW_DIR" "$PERSISTENT_BREW_DIR" 2>/dev/null || true
    echo "INFO: Copied Homebrew to persistent storage at $PERSISTENT_BREW_DIR"
  fi
  # Replace image dir with symlink to persistent copy
  rm -rf "$IMAGE_BREW_DIR"
  ln -sf "$PERSISTENT_BREW_DIR" "$IMAGE_BREW_DIR"
elif [ -L "$IMAGE_BREW_DIR" ]; then
  echo "INFO: Homebrew already linked to persistent storage"
elif [ -d "$PERSISTENT_BREW_DIR" ]; then
  # Image doesn't have Homebrew (failed install?) but persistent copy exists
  mkdir -p "$(dirname "$IMAGE_BREW_DIR")"
  ln -sf "$PERSISTENT_BREW_DIR" "$IMAGE_BREW_DIR"
  echo "INFO: Restored Homebrew symlink from persistent storage"
else
  echo "INFO: Homebrew not available (install may have failed during image build)"
fi

# Back-compat: some docs/scripts assume /data; point it at /config.
if [ ! -e /data ]; then
  ln -s /config /data || true
fi

# Ensure the agents base directory exists so cleanup scans work even before first run.
# Do NOT pre-create agent-specific directories; OpenClaw creates them as needed.
mkdir -p /config/.openclaw/agents || true

# ------------------------------------------------------------------------------
# SINGLE-INSTANCE GUARD (prevents multiple gateway runs racing each other)
# ------------------------------------------------------------------------------
STARTUP_LOCK="/config/.openclaw/gateway.start.lock"
exec 9>"$STARTUP_LOCK"
if ! flock -n 9; then
  echo "ERROR: Another instance appears to be running (could not acquire $STARTUP_LOCK)."
  echo "If this is wrong, check for stuck processes or remove the lock file."
  exit 1
fi

# ------------------------------------------------------------------------------
# Session lock cleanup helpers
# ------------------------------------------------------------------------------

gateway_running() {
  pgrep -f "openclaw-gateway" >/dev/null 2>&1
}

cleanup_session_locks() {
  local agents_dir="/config/.openclaw/agents"
  local total_locks=0
  local cleaned_dirs=()

  # Scan all agent session directories, not just 'main'.
  # This is needed for users who have gateway.forcedAgentId set to a non-default agent.
  shopt -s nullglob
  local all_locks=()
  for agent_sessions_dir in "${agents_dir}"/*/sessions; do
    local agent_locks=( "${agent_sessions_dir}"/*.jsonl.lock )
    if [ ${#agent_locks[@]} -gt 0 ]; then
      all_locks+=( "${agent_locks[@]}" )
      cleaned_dirs+=( "$agent_sessions_dir" )
      total_locks=$(( total_locks + ${#agent_locks[@]} ))
    fi
  done
  shopt -u nullglob

  if [ "$total_locks" -eq 0 ]; then
    return 0
  fi

  # If gateway is running, do NOT remove locks automatically (could be real).
  if gateway_running; then
    echo "INFO: Gateway appears to be running; leaving session lock files untouched."
    echo "INFO: Locks present: $total_locks"
    return 0
  fi

  echo "INFO: Removing stale session lock files ($total_locks) across agents: ${cleaned_dirs[*]}"
  for agent_sessions_dir in "${cleaned_dirs[@]}"; do
    rm -f "${agent_sessions_dir}"/*.jsonl.lock || true
  done
}

if [ "$CLEAN_LOCKS_ON_START" = "true" ]; then
  cleanup_session_locks
else
  echo "INFO: clean_session_locks_on_start=false; skipping session lock cleanup."
fi

# ------------------------------------------------------------------------------
# Store tokens / export env vars (optional)
# ------------------------------------------------------------------------------

if [ -n "$HA_TOKEN" ]; then
  umask 077
  printf '%s' "$HA_TOKEN" > /config/secrets/homeassistant.token
fi

write_secret_file() {
  local target_path="$1"
  local secret_value="$2"

  mkdir -p "$(dirname "$target_path")"
  if [ -n "$secret_value" ]; then
    umask 077
    printf '%s' "$secret_value" > "$target_path"
  else
    rm -f "$target_path"
  fi
}

configure_external_integrations() {
  write_secret_file /config/secrets/context7.api_key "$CONTEXT7_API_KEY"
  write_secret_file /config/secrets/domotz.api_key "$DOMOTZ_API_KEY"
  write_secret_file /config/secrets/domotz.site_id "$DOMOTZ_SITE_ID"
  write_secret_file /config/secrets/github_issues.token "$GITHUB_ISSUES_TOKEN"
  write_secret_file /config/secrets/matrix.access_token "$MATRIX_ACCESS_TOKEN"
  write_secret_file /config/secrets/matrix.password "$MATRIX_PASSWORD"
  write_secret_file /config/secrets/mqtt.broker_url "$MQTT_BROKER_URL"
  write_secret_file /config/secrets/mqtt.username "$MQTT_USERNAME"
  write_secret_file /config/secrets/mqtt.password "$MQTT_PASSWORD"

  export CONTEXT7_ENABLED=false
  export DOMOTZ_ENABLED=false
  export MQTT_ENABLED=false
  export BACNET_SCOUT_ENABLED=false
  export MATRIX_ENABLED=false
  export MATRIX_ACCESS_TOKEN_CONFIGURED=false
  export MATRIX_PASSWORD_CONFIGURED=false
  export MQTT_USERNAME_CONFIGURED=false
  export MQTT_PASSWORD_CONFIGURED=false
  export HA_MCP_ENABLED=false
  export GITHUB_ISSUES_ENABLED=false
  export GITDAKKY_ISSUES_REPO="GitDakky/OpenClawHomeAssistant"

  if [ "$ENABLE_CONTEXT7" = "true" ] || [ "$ENABLE_CONTEXT7" = "1" ]; then
    export CONTEXT7_ENABLED=true
  fi
  if [ -n "$CONTEXT7_API_KEY" ]; then
    export CONTEXT7_API_KEY
    export CONTEXT7_API_KEY_FILE=/config/secrets/context7.api_key
  fi

  if [ -n "$DOMOTZ_API_KEY" ] || [ -n "$DOMOTZ_SITE_ID" ]; then
    export DOMOTZ_ENABLED=true
  fi
  if [ -n "$DOMOTZ_API_KEY" ]; then
    export DOMOTZ_API_KEY
    export DOMOTZ_API_KEY_FILE=/config/secrets/domotz.api_key
  fi
  if [ -n "$DOMOTZ_SITE_ID" ]; then
    export DOMOTZ_SITE_ID
    export DOMOTZ_SITE_ID_FILE=/config/secrets/domotz.site_id
  fi

  if [ -n "$GITHUB_ISSUES_TOKEN" ]; then
    export GITHUB_ISSUES_ENABLED=true
    export GITHUB_ISSUES_TOKEN_FILE=/config/secrets/github_issues.token
  fi

  if [ "$ENABLE_MATRIX" = "true" ] || [ "$ENABLE_MATRIX" = "1" ]; then
    export MATRIX_ENABLED=true
  fi
  export MATRIX_HOMESERVER
  export MATRIX_USER_ID
  export MATRIX_DM_POLICY
  export MATRIX_GROUP_POLICY
  export MATRIX_AUTO_JOIN
  if [ -n "$MATRIX_ACCESS_TOKEN" ]; then
    export MATRIX_ACCESS_TOKEN_FILE=/config/secrets/matrix.access_token
    export MATRIX_ACCESS_TOKEN_CONFIGURED=true
  fi
  if [ -n "$MATRIX_PASSWORD" ]; then
    export MATRIX_PASSWORD_FILE=/config/secrets/matrix.password
    export MATRIX_PASSWORD_CONFIGURED=true
  fi

  if [ -n "$MQTT_BROKER_URL" ]; then
    export MQTT_ENABLED=true
    export MQTT_BROKER_URL
    export MQTT_BROKER_URL_FILE=/config/secrets/mqtt.broker_url
  fi
  if [ -n "$MQTT_USERNAME" ]; then
    export MQTT_USERNAME
    export MQTT_USERNAME_FILE=/config/secrets/mqtt.username
    export MQTT_USERNAME_CONFIGURED=true
  fi
  if [ -n "$MQTT_PASSWORD" ]; then
    export MQTT_PASSWORD
    export MQTT_PASSWORD_FILE=/config/secrets/mqtt.password
    export MQTT_PASSWORD_CONFIGURED=true
  fi

  if [ "$ENABLE_BACNET_SCOUT" = "true" ] || [ "$ENABLE_BACNET_SCOUT" = "1" ]; then
    export BACNET_SCOUT_ENABLED=true
  fi

  if [ "$AUTO_CONFIGURE_MCP" = "true" ] && [ -n "$HA_TOKEN" ]; then
    export HA_MCP_ENABLED=true
  fi

  cat > /config/.openclaw/gitdakky-integrations.json <<EOF
{
  "context7": {
    "enabled": ${CONTEXT7_ENABLED},
    "apiKeyConfigured": $( [ -n "$CONTEXT7_API_KEY" ] && echo true || echo false )
  },
  "domotz": {
    "enabled": ${DOMOTZ_ENABLED},
    "siteId": $(printf '%s' "$DOMOTZ_SITE_ID" | jq -Rs .),
    "apiKeyConfigured": $( [ -n "$DOMOTZ_API_KEY" ] && echo true || echo false )
  },
  "githubIssues": {
    "enabled": ${GITHUB_ISSUES_ENABLED},
    "repo": "GitDakky/OpenClawHomeAssistant"
  },
  "matrix": {
    "enabled": ${MATRIX_ENABLED},
    "homeserver": $(printf '%s' "$MATRIX_HOMESERVER" | jq -Rs .),
    "userId": $(printf '%s' "$MATRIX_USER_ID" | jq -Rs .),
    "accessTokenConfigured": ${MATRIX_ACCESS_TOKEN_CONFIGURED},
    "passwordConfigured": ${MATRIX_PASSWORD_CONFIGURED},
    "dmPolicy": $(printf '%s' "$MATRIX_DM_POLICY" | jq -Rs .),
    "groupPolicy": $(printf '%s' "$MATRIX_GROUP_POLICY" | jq -Rs .),
    "autoJoin": $(printf '%s' "$MATRIX_AUTO_JOIN" | jq -Rs .)
  },
  "mqtt": {
    "enabled": ${MQTT_ENABLED},
    "brokerUrl": $(printf '%s' "$MQTT_BROKER_URL" | jq -Rs .),
    "usernameConfigured": ${MQTT_USERNAME_CONFIGURED},
    "passwordConfigured": ${MQTT_PASSWORD_CONFIGURED}
  },
  "bacnet": {
    "enabled": ${BACNET_SCOUT_ENABLED}
  }
}
EOF

  echo "INFO: Prepared external integration secrets and runtime flags."
}

configure_external_integrations


# ------------------------------------------------------------------------------
# OpenClaw config is managed by OpenClaw itself (onboarding / configure).
# This add-on intentionally does NOT create/patch /config/.openclaw/openclaw.json.
# ------------------------------------------------------------------------------

# Convenience info for later (router SSH access path & HA token file)
cat > /config/CONNECTION_NOTES.txt <<EOF
Home Assistant token (if set): /config/secrets/homeassistant.token
GitHub issues token (if set): /config/secrets/github_issues.token
Matrix access token (if set): /config/secrets/matrix.access_token
Matrix password (if set): /config/secrets/matrix.password
Router SSH (generic):
  host=${ROUTER_HOST}
  user=${ROUTER_USER}
  key=${ROUTER_KEY}
EOF


# ------------------------------------------------------------------------------
# Graceful shutdown handling (PID 1 trap) to reduce stale locks
# ------------------------------------------------------------------------------
GW_PID=""
GW_RELAY_PID=""
NGINX_PID=""
TTYD_PID=""
LOCAL_PAIRING_APPROVER_PID=""
DASHBOARD_API_PID=""
CONFIG_WATCHER_PID=""
SHUTTING_DOWN="false"

shutdown() {
  SHUTTING_DOWN="true"
  echo "Shutdown requested; stopping services..."

  if [ -n "${NGINX_PID}" ] && kill -0 "${NGINX_PID}" >/dev/null 2>&1; then
    kill -TERM "${NGINX_PID}" >/dev/null 2>&1 || true
    wait "${NGINX_PID}" || true
  fi

  if [ -n "${TTYD_PID}" ] && kill -0 "${TTYD_PID}" >/dev/null 2>&1; then
    kill -TERM "${TTYD_PID}" >/dev/null 2>&1 || true
    wait "${TTYD_PID}" || true
  fi

  if [ -n "${LOCAL_PAIRING_APPROVER_PID}" ] && kill -0 "${LOCAL_PAIRING_APPROVER_PID}" >/dev/null 2>&1; then
    kill -TERM "${LOCAL_PAIRING_APPROVER_PID}" >/dev/null 2>&1 || true
    wait "${LOCAL_PAIRING_APPROVER_PID}" 2>/dev/null || true
  fi

  if [ -n "${DASHBOARD_API_PID}" ] && kill -0 "${DASHBOARD_API_PID}" >/dev/null 2>&1; then
    kill -TERM "${DASHBOARD_API_PID}" >/dev/null 2>&1 || true
    wait "${DASHBOARD_API_PID}" 2>/dev/null || true
  fi

  if [ -n "${CONFIG_WATCHER_PID}" ] && kill -0 "${CONFIG_WATCHER_PID}" >/dev/null 2>&1; then
    kill -TERM "${CONFIG_WATCHER_PID}" >/dev/null 2>&1 || true
    wait "${CONFIG_WATCHER_PID}" 2>/dev/null || true
  fi

  if [ -n "${GW_PID}" ] && kill -0 "${GW_PID}" >/dev/null 2>&1; then
    kill -TERM "${GW_PID}" >/dev/null 2>&1 || true
    # wait reaps child PIDs; for non-child (re-tracked) PIDs it fails instantly,
    # so fall back to a timed kill -0 poll to let the gateway finish cleanly.
    if ! wait "${GW_PID}" 2>/dev/null; then
      for _i in 1 2 3 4 5; do
        kill -0 "${GW_PID}" 2>/dev/null || break
        sleep 1
      done
    fi
  fi

  stop_gw_relay

  if [ "$CLEAN_LOCKS_ON_EXIT" = "true" ]; then
    cleanup_session_locks || true
  fi
}

trap shutdown INT TERM

if ! command -v openclaw >/dev/null 2>&1; then
  echo "ERROR: openclaw is not installed."
  exit 1
fi

# Bootstrap minimal OpenClaw config ONLY if missing.
# We do not overwrite or patch existing configs; onboarding owns everything else.
if [ ! -f "$OPENCLAW_CONFIG_PATH" ]; then
  echo "INFO: OpenClaw config missing; bootstrapping minimal config at $OPENCLAW_CONFIG_PATH"
  python3 - <<'PY'
import json
import secrets
from pathlib import Path

cfg_path = Path('/config/.openclaw/openclaw.json')
cfg_path.parent.mkdir(parents=True, exist_ok=True)

cfg = {
  "gateway": {
    "mode": "local",
    "port": 18790,
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": secrets.token_urlsafe(24)
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/config/clawd"
    }
  }
}

cfg_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding='utf-8')
print("INFO: Wrote minimal OpenClaw config (gateway.mode=local, auth.token generated)")
PY
fi

reconcile_default_agent_state

# ------------------------------------------------------------------------------
# Apply gateway LAN mode settings safely using helper script
# This updates gateway.bind and gateway.port without touching other settings
# ------------------------------------------------------------------------------
export OPENCLAW_CONFIG_PATH="/config/.openclaw/openclaw.json"

# Find the helper script (copied to root in Dockerfile, or fallback to add-on dir)
HELPER_PATH="/oc_config_helper.py"
if [ ! -f "$HELPER_PATH" ] && [ -f "$(dirname "$0")/oc_config_helper.py" ]; then
  HELPER_PATH="$(dirname "$0")/oc_config_helper.py"
fi

if [ -f "$OPENCLAW_CONFIG_PATH" ]; then
  if [ -f "$HELPER_PATH" ]; then
    # In lan_https mode the gateway uses an internal port; nginx owns the external one.
    EFFECTIVE_GW_PORT="$GATEWAY_INTERNAL_PORT"
    if ! python3 "$HELPER_PATH" apply-gateway-settings "$GATEWAY_MODE" "$GATEWAY_REMOTE_URL" "$GATEWAY_BIND_MODE" "$EFFECTIVE_GW_PORT" "$ENABLE_OPENAI_API" "$GATEWAY_AUTH_MODE" "$GATEWAY_TRUSTED_PROXIES"; then
      rc=$?
      echo "ERROR: Failed to apply gateway settings via oc_config_helper.py (exit code ${rc})."
      echo "ERROR: Gateway configuration may be incorrect; aborting startup."
      exit "${rc}"
    fi
  else
    echo "WARN: oc_config_helper.py not found, cannot apply gateway settings"
    echo "INFO: Ensure the add-on image includes oc_config_helper.py and restart"
  fi
else
  echo "WARN: OpenClaw config not found at $OPENCLAW_CONFIG_PATH, cannot apply gateway settings"
  echo "INFO: Run 'openclaw onboard' first, then restart the add-on"
fi

if [ -f "$HELPER_PATH" ]; then
  if ! python3 "$HELPER_PATH" configure-exec-approvals "$DISABLE_EXEC_APPROVALS"; then
    rc=$?
    echo "ERROR: Failed to configure exec approval policy via oc_config_helper.py (exit code ${rc})."
    echo "ERROR: Host automation exec policy may be inconsistent; aborting startup."
    exit "${rc}"
  fi
else
  echo "WARN: oc_config_helper.py not found, cannot configure exec approval policy"
fi

if [ "$ENABLE_MATRIX" = "true" ] || [ "$ENABLE_MATRIX" = "1" ]; then
  if openclaw plugins inspect @openclaw/matrix --json >/dev/null 2>&1; then
    echo "INFO: Matrix plugin is available."
  else
    echo "INFO: Installing Matrix plugin @openclaw/matrix ..."
    if ! openclaw plugins install @openclaw/matrix >/tmp/openclaw-matrix-plugin-install.log 2>&1; then
      echo "WARN: Failed to install Matrix plugin automatically."
      tail -n 40 /tmp/openclaw-matrix-plugin-install.log 2>/dev/null || true
    fi
  fi
fi

if [ -f "$HELPER_PATH" ]; then
  if ! python3 "$HELPER_PATH" configure-matrix-channel \
      "$ENABLE_MATRIX" \
      "$MATRIX_HOMESERVER" \
      "$MATRIX_ALLOW_PRIVATE_NETWORK" \
      "$MATRIX_USER_ID" \
      "$MATRIX_PASSWORD" \
      "$MATRIX_ACCESS_TOKEN" \
      "$MATRIX_ENCRYPTION" \
      "$MATRIX_AUTO_JOIN" \
      "$MATRIX_DM_POLICY" \
      "$MATRIX_DM_ALLOW_FROM" \
      "$MATRIX_GROUP_POLICY" \
      "$MATRIX_GROUP_ALLOW_FROM" \
      "$MATRIX_ROOM_ALLOWLIST"; then
    rc=$?
    echo "ERROR: Failed to configure Matrix channel via oc_config_helper.py (exit code ${rc})."
    echo "ERROR: Matrix configuration may be inconsistent; aborting startup."
    exit "${rc}"
  fi
fi

if [ "$GATEWAY_AUTH_MODE" = "trusted-proxy" ]; then
  echo "NOTICE: gateway_auth_mode=trusted-proxy is enabled."
  echo "NOTICE: Direct local CLI calls to the gateway may return unauthorized (trusted_proxy_user_missing) unless identity headers are injected by your reverse proxy."
  echo "NOTICE: For local terminal CLI workflows, temporarily switch to token auth or use commands that don't require direct gateway WS auth."
fi

# ------------------------------------------------------------------------------
# TLS certificate generation for built-in HTTPS proxy (lan_https mode)
# Generates a local CA + server cert so phones/tablets get proper HTTPS.
# The CA cert can be installed once on a device for trusted access.
# ------------------------------------------------------------------------------
LAN_IP=""
if [ "$ENABLE_HTTPS_PROXY" = "true" ]; then
  CERT_DIR="/config/certs"
  mkdir -p "$CERT_DIR"

  # Detect primary LAN IP
  LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  STORED_IP=$(cat "$CERT_DIR/.cert_ip" 2>/dev/null || echo "")

  # --- Local CA (generated once, persists across restarts) ---
  if [ ! -f "$CERT_DIR/ca.key" ] || [ ! -f "$CERT_DIR/ca.crt" ]; then
    echo "INFO: Generating local CA certificate (one-time)..."
    openssl genrsa -out "$CERT_DIR/ca.key" 2048 2>/dev/null
    openssl req -new -x509 -key "$CERT_DIR/ca.key" -out "$CERT_DIR/ca.crt" \
      -days 3650 -nodes -subj "/CN=OpenClaw Local CA" 2>/dev/null
    chmod 600 "$CERT_DIR/ca.key"
    STORED_IP=""  # force server cert regeneration
    echo "INFO: Local CA created at $CERT_DIR/ca.crt"
  fi

  # --- Extra SANs from gateway_additional_allowed_origins + gateway_public_url ---
  EXTRA_SANS=""
  EXTRA_SAN_SOURCES="${GATEWAY_ADDITIONAL_ALLOWED_ORIGINS},${GW_PUBLIC_URL}"
  if [ "$EXTRA_SAN_SOURCES" != "," ]; then
    EXTRA_SANS="$(python3 - "$EXTRA_SAN_SOURCES" "${LAN_IP:-}" <<'PY'
import sys, re
from urllib.parse import urlparse
raw = sys.argv[1] if len(sys.argv) > 1 else ""
lan_ip = sys.argv[2] if len(sys.argv) > 2 else ""
entries = [e.strip() for e in raw.split(",") if e.strip()]
sans = []
seen = {"127.0.0.1", "localhost", "homeassistant", "homeassistant.local"}
if lan_ip:
    seen.add(lan_ip)
for entry in entries:
    if "://" not in entry:
        entry = "https://" + entry
    host = urlparse(entry).hostname or ""
    if host and host not in seen:
        seen.add(host)
        if re.match(r"^\d{1,3}(\.\d{1,3}){3}$", host):
            sans.append(f"IP:{host}")
        else:
            sans.append(f"DNS:{host}")
print(",".join(sans), end="")
PY
)"
  fi
  STORED_EXTRA_SANS=$(cat "$CERT_DIR/.cert_extra_sans" 2>/dev/null || echo "")

  # --- Server cert (regenerated when LAN IP or SANs change) ---
  if [ ! -f "$CERT_DIR/gateway.crt" ] || [ ! -f "$CERT_DIR/gateway.key" ] || [ "$LAN_IP" != "$STORED_IP" ] || [ "$EXTRA_SANS" != "$STORED_EXTRA_SANS" ]; then
    echo "INFO: Generating server TLS certificate for IP: ${LAN_IP:-unknown}..."
    openssl genrsa -out "$CERT_DIR/gateway.key" 2048 2>/dev/null
    openssl req -new -key "$CERT_DIR/gateway.key" -out "$CERT_DIR/gateway.csr" \
      -subj "/CN=OpenClaw Gateway" 2>/dev/null

    # SAN extension — include LAN IP, loopback, common mDNS names + user extras
    cat > "$CERT_DIR/_san.ext" <<SANEOF
subjectAltName=IP:${LAN_IP:-127.0.0.1},IP:127.0.0.1,DNS:localhost,DNS:homeassistant,DNS:homeassistant.local${EXTRA_SANS:+,${EXTRA_SANS}}
SANEOF

    openssl x509 -req -in "$CERT_DIR/gateway.csr" \
      -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
      -out "$CERT_DIR/gateway.crt" -days 3650 \
      -extfile "$CERT_DIR/_san.ext" 2>/dev/null

    rm -f "$CERT_DIR/gateway.csr" "$CERT_DIR/_san.ext" "$CERT_DIR/ca.srl"
    chmod 600 "$CERT_DIR/gateway.key"
    printf '%s' "$LAN_IP" > "$CERT_DIR/.cert_ip"
    printf '%s' "$EXTRA_SANS" > "$CERT_DIR/.cert_extra_sans"
    echo "INFO: Server TLS certificate generated (SAN: IP:${LAN_IP:-127.0.0.1}${EXTRA_SANS:+,${EXTRA_SANS}})"
  else
    echo "INFO: Reusing existing TLS certificate (IP: $STORED_IP)"
  fi

  # Make CA cert available for download via nginx
  mkdir -p /etc/nginx/html
  cp "$CERT_DIR/ca.crt" /etc/nginx/html/openclaw-ca.crt 2>/dev/null || true
  echo "INFO: CA certificate available for download at /cert/ca.crt on the HTTPS port"

fi

# ------------------------------------------------------------------
# Configure gateway.controlUi.allowedOrigins:
# - In lan_https: include HTTPS proxy defaults (LAN IP + common hostnames)
# - In all modes: also include origin from gateway_public_url when present
# - Helper merges with existing origins + user extras and deduplicates
# ------------------------------------------------------------------
if [ -f "$HELPER_PATH" ] && [ -f "$OPENCLAW_CONFIG_PATH" ]; then
  ALLOWED_ORIGINS=""

  if [ "$ENABLE_HTTPS_PROXY" = "true" ] && [ -n "$LAN_IP" ]; then
    ALLOWED_ORIGINS="https://${LAN_IP}:${GATEWAY_PORT}"
    ALLOWED_ORIGINS="${ALLOWED_ORIGINS},https://homeassistant.local:${GATEWAY_PORT}"
    ALLOWED_ORIGINS="${ALLOWED_ORIGINS},https://homeassistant:${GATEWAY_PORT}"
  fi

  if [ -n "$GW_PUBLIC_URL" ]; then
    GW_PUBLIC_ORIGIN="$(python3 - "$GW_PUBLIC_URL" <<'PY'
import sys
from urllib.parse import urlparse
u = (sys.argv[1] or '').strip()
p = urlparse(u)
if p.scheme in ('http', 'https') and p.netloc:
    print(f"{p.scheme}://{p.netloc}", end='')
PY
)"
    if [ -n "$GW_PUBLIC_ORIGIN" ]; then
      if [ -n "$ALLOWED_ORIGINS" ]; then
        ALLOWED_ORIGINS="${ALLOWED_ORIGINS},${GW_PUBLIC_ORIGIN}"
      else
        ALLOWED_ORIGINS="$GW_PUBLIC_ORIGIN"
      fi
    fi
  fi

  python3 "$HELPER_PATH" set-control-ui-origins "$ALLOWED_ORIGINS" "$GATEWAY_ADDITIONAL_ALLOWED_ORIGINS" "$CONTROLUI_DISABLE_DEVICE_AUTH" || \
    echo "WARN: Could not set controlUi settings — gateway may reject the Control UI"
fi

# ------------------------------------------------------------------------------
# Proxy shim for undici/OpenClaw startup
# Keep official OpenClaw npm release while enabling HTTP(S)_PROXY support.
# ------------------------------------------------------------------------------
OPENCLAW_GLOBAL_NODE_MODULES="$(HOME=/root npm root -g 2>/dev/null || true)"
if [ -f /usr/local/lib/openclaw-proxy-shim.cjs ]; then
  if [ -n "${NODE_OPTIONS:-}" ]; then
    export NODE_OPTIONS="--require /usr/local/lib/openclaw-proxy-shim.cjs ${NODE_OPTIONS}"
  else
    export NODE_OPTIONS="--require /usr/local/lib/openclaw-proxy-shim.cjs"
  fi
  export OPENCLAW_GLOBAL_NODE_MODULES
fi

configure_builtin_homeassistant_mcp() {
  local mcp_name="homeassistant_local"
  local mcp_payload

  if [ "$ENABLE_BUILTIN_HA_TOOLS" != "true" ] && [ "$ENABLE_BUILTIN_HA_TOOLS" != "1" ]; then
    if openclaw mcp unset "$mcp_name" >/dev/null 2>&1; then
      echo "INFO: Removed built-in Home Assistant MCP server definition."
    fi
    return 0
  fi

  if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
    echo "WARN: SUPERVISOR_TOKEN is unavailable; built-in Home Assistant tools cannot be registered."
    return 0
  fi

  if [ ! -f /opt/openclaw-super/ha_mcp_server.cjs ]; then
    echo "WARN: Built-in Home Assistant MCP server script is missing; skipping registration."
    return 0
  fi

  mcp_payload="$(jq -cn \
    --arg command "node" \
    --arg script "/opt/openclaw-super/ha_mcp_server.cjs" \
    '{command: $command, args: [$script]}'
  )"

  if openclaw mcp set "$mcp_name" "$mcp_payload" >/dev/null 2>&1; then
    echo "INFO: Registered built-in Home Assistant MCP server '$mcp_name' (service calls: $ENABLE_HA_SERVICE_CALLS)."
  else
    echo "WARN: Failed to register built-in Home Assistant MCP server '$mcp_name'."
  fi
}

# ------------------------------------------------------------------------------
# Built-in Home Assistant tool layer (preferred)
# Registers a local MCP server backed by the HA Supervisor/Core APIs so OpenClaw
# can see live entities, devices, services, automations, and history without a
# separate user-managed token flow.
# ------------------------------------------------------------------------------
configure_builtin_homeassistant_mcp

# ------------------------------------------------------------------------------
# Legacy external MCP auto-configuration (compatibility path)
# Keeps the old long-lived-token/manual-MCP workflow available only when the
# built-in HA tool layer is disabled. This avoids duplicate Home Assistant tool
# surfaces in normal installs.
# ------------------------------------------------------------------------------
if [ "$ENABLE_BUILTIN_HA_TOOLS" = "true" ] || [ "$ENABLE_BUILTIN_HA_TOOLS" = "1" ]; then
  if [ "$AUTO_CONFIGURE_MCP" = "true" ]; then
    echo "INFO: auto_configure_mcp is ignored because the built-in Home Assistant tool layer is enabled."
  fi
elif [ "$AUTO_CONFIGURE_MCP" = "true" ] && [ -n "$HA_TOKEN" ]; then
  echo "WARN: Legacy external Home Assistant MCP auto-configuration is still enabled."
  echo "WARN: This path is deprecated; prefer enable_builtin_ha_tools=true."
  if command -v mcporter >/dev/null 2>&1; then
    if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
      MCP_HA_URL="http://supervisor/core/api/mcp"
    else
      MCP_HA_URL="http://localhost:8123/api/mcp"
    fi
    MCP_FLAG="/config/.openclaw/.mcp_ha_configured"
    MCP_TOKEN_HASH=$(printf '%s' "$HA_TOKEN" | sha256sum | cut -d' ' -f1)

    if [ -f "$MCP_FLAG" ] && [ "$(cat "$MCP_FLAG" 2>/dev/null)" = "$MCP_TOKEN_HASH" ]; then
      echo "INFO: MCP Home Assistant server already configured (token unchanged)"
    else
      echo "INFO: Configuring legacy MCP for Home Assistant at $MCP_HA_URL ..."
      mcporter config remove HA 2>/dev/null || true

      if mcporter config add HA "$MCP_HA_URL" \
          --header "Authorization=Bearer $HA_TOKEN" \
          --scope home 2>&1; then
        printf '%s' "$MCP_TOKEN_HASH" > "$MCP_FLAG"
        echo "INFO: MCP server 'HA' registered — OpenClaw can now control Home Assistant"
      else
        echo "WARN: MCP auto-configuration failed. Configure manually in the terminal:"
        echo "WARN:   mcporter config add HA \"$MCP_HA_URL\" --header \"Authorization=Bearer YOUR_TOKEN\" --scope home"
      fi
    fi
  else
    echo "INFO: mcporter not available; skipping legacy MCP auto-configuration (run 'openclaw onboard' first)"
  fi
elif [ "$AUTO_CONFIGURE_MCP" = "true" ] && [ -z "$HA_TOKEN" ]; then
  echo "INFO: MCP auto-configure enabled but homeassistant_token not set — skipping"
  echo "INFO: To auto-configure, set homeassistant_token in add-on Configuration, then restart"
fi

start_openclaw_runtime() {
  echo "Starting ${SELF_ADDON_NAME} runtime (openclaw)..."
  mkdir -p "$RUNTIME_WRAPPER_LOG_DIR"
  if [ "$GATEWAY_MODE" = "remote" ]; then
    # Remote mode: do NOT start a local gateway service.
    # Start a node/client host that connects to the configured remote gateway URL.
    # Use $GATEWAY_REMOTE_URL directly from add-on options — do NOT read back via
    # 'openclaw config get' which can time out at startup or return redacted values.
    REMOTE_URL="$GATEWAY_REMOTE_URL"
    if [ -z "$REMOTE_URL" ]; then
      echo "ERROR: gateway_mode=remote but gateway_remote_url is not set in add-on options"
      echo "ERROR: Set gateway_remote_url in add-on Configuration (e.g. ws://192.168.1.10:18790), then restart"
      return 1
    fi

    NODE_HOST=""
    NODE_PORT=""
    NODE_TLS_FLAG=""
    if ! eval "$(python3 - "$REMOTE_URL" <<'PY'
import sys
from urllib.parse import urlparse
url = (sys.argv[1] or '').strip()
p = urlparse(url)
if p.scheme not in ('ws', 'wss') or not p.hostname:
    print('echo "ERROR: Invalid gateway.remote.url (expected ws:// or wss://): %s"' % url.replace('"', '\\"'))
    print('exit 1')
    raise SystemExit(0)
port = p.port or (443 if p.scheme == 'wss' else 80)
print(f'NODE_HOST={p.hostname}')
print(f'NODE_PORT={port}')
print(f'NODE_TLS_FLAG={"--tls" if p.scheme == "wss" else ""}')
PY
)"; then
      echo "ERROR: Failed to parse gateway.remote.url: $REMOTE_URL"
      return 1
    fi

    echo "INFO: gateway_mode=remote detected; starting node host to $NODE_HOST:$NODE_PORT ${NODE_TLS_FLAG}"
    echo "INFO: Managed runtime launch sets OPENCLAW_NO_RESPAWN=1 so the add-on supervises a single stable process."
    # shellcheck disable=SC2086
    nohup env OPENCLAW_NO_RESPAWN=1 openclaw node run --host "$NODE_HOST" --port "$NODE_PORT" $NODE_TLS_FLAG \
      < /dev/null >>"$RUNTIME_WRAPPER_LOG_FILE" 2>&1 &
  else
    clear_stale_gateway_listener
    echo "INFO: Managed gateway launch sets OPENCLAW_NO_RESPAWN=1 so the add-on supervises a single stable process."
    nohup env OPENCLAW_NO_RESPAWN=1 openclaw gateway < /dev/null >>"$RUNTIME_WRAPPER_LOG_FILE" 2>&1 &
  fi
  GW_PID=$!
  echo "INFO: Runtime wrapper log: ${RUNTIME_WRAPPER_LOG_FILE}"
  return 0
}

# --- Loopback relay helpers for tailnet bind mode (issue #90) ---
# When gateway.bind=tailnet the gateway only listens on the Tailscale IP.
# The local CLI always tries ws://127.0.0.1:PORT and fails with
# "Gateway not running" even though the gateway is healthy.
# These functions start/stop a lightweight Node.js TCP relay on
# 127.0.0.1:PORT -> TAILSCALE_IP:PORT so terminal CLI commands work.
# IMPORTANT: stop_gw_relay must be called before restarting the gateway;
# otherwise the relay holds the loopback port and the new gateway instance
# detects it as "already listening" and exits with code 1.
start_gw_relay() {
  if [ "$GATEWAY_BIND_MODE" != "tailnet" ]; then
    return 0
  fi
  local ts_ip
  ts_ip=$(ip -4 addr show tailscale0 2>/dev/null \
    | awk '/inet /{gsub(/\/.*/,"",$2); print $2; exit}' || true)
  if [[ "${ts_ip:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "INFO: Starting loopback relay for tailnet gateway (127.0.0.1:${GATEWAY_PORT} -> ${ts_ip}:${GATEWAY_PORT})"
    node -e "
const net = require('net');
const TARGET_HOST = '${ts_ip}';
const TARGET_PORT = ${GATEWAY_PORT};
const server = net.createServer(function(c) {
  const t = net.createConnection(TARGET_PORT, TARGET_HOST);
  c.pipe(t); t.pipe(c);
  c.on('error', function() { t.destroy(); });
  t.on('error', function() { c.destroy(); });
});
server.listen(TARGET_PORT, '127.0.0.1');" &
    GW_RELAY_PID=$!
    echo "INFO: Loopback relay started (PID ${GW_RELAY_PID})"
  else
    echo "WARN: tailnet bind mode active but Tailscale IP not found on tailscale0 interface."
    echo "WARN: Terminal CLI may show gateway as unreachable. Ensure Tailscale is running and restart."
  fi
}

stop_gw_relay() {
  if [ -n "${GW_RELAY_PID}" ] && kill -0 "${GW_RELAY_PID}" >/dev/null 2>&1; then
    kill -TERM "${GW_RELAY_PID}" >/dev/null 2>&1 || true
    wait "${GW_RELAY_PID}" 2>/dev/null || true
    GW_RELAY_PID=""
  fi
}

auto_approve_local_pairings_once() {
  local devices_json request_ids request_id approved_count=0

  if [ "$GATEWAY_MODE" != "local" ]; then
    return 0
  fi

  case "$GATEWAY_BIND_MODE" in
    loopback)
      ;;
    *)
      if [ "$ENABLE_HTTPS_PROXY" != "true" ] && [ "$ACCESS_MODE" != "local_only" ]; then
        return 0
      fi
      ;;
  esac

  devices_json="$(openclaw devices list --json 2>/dev/null || true)"
  if [ -z "$devices_json" ]; then
    return 0
  fi

  request_ids="$(printf '%s' "$devices_json" | jq -r '
    .pending[]?
    | select(
        (
          (.remoteIp // "") == "127.0.0.1"
          or (.remoteIp // "") == "::1"
          or ((.remoteIp // "") | startswith("::ffff:127."))
          or (
            (.remoteIp // "") == ""
            and (
              (.clientId // "") == "cli"
              or (.clientMode // "") == "cli"
              or (.clientId // "") == "openclaw-control-ui"
              or (.clientId // "") == "clawdbot-control-ui"
              or (.clientMode // "") == "webchat"
            )
          )
        )
        and (
          (.role // "") == "operator"
          or ((.roles // []) | index("operator"))
        )
      )
    | .requestId
  ' 2>/dev/null)" || true

  if [ -z "$request_ids" ]; then
    return 0
  fi

  while IFS= read -r request_id; do
    [ -n "$request_id" ] || continue
    if openclaw devices approve "$request_id" >/dev/null 2>&1; then
      approved_count=$((approved_count + 1))
      echo "INFO: Auto-approved same-host OpenClaw device pairing request ${request_id}."
    fi
  done <<EOF
$request_ids
EOF

  if [ "$approved_count" -gt 0 ]; then
    echo "INFO: Auto-approved ${approved_count} local device pairing request(s) for CLI/TUI access."
  fi
}

start_local_pairing_approver() {
  if [ "$GATEWAY_MODE" != "local" ]; then
    return 0
  fi

  auto_approve_local_pairings_once || true

  (
    while true; do
      sleep 8
      auto_approve_local_pairings_once || true
    done
  ) &
  LOCAL_PAIRING_APPROVER_PID=$!
}

start_dashboard_api() {
  local api_port="${DASHBOARD_API_PORT:-$DEFAULT_DASHBOARD_API_PORT}"
  if [ ! -f /dashboard_api.py ]; then
    echo "WARN: dashboard_api.py not found; operator file editor will be unavailable"
    return 0
  fi

  export OPENCLAW_DASHBOARD_API_PORT="$api_port"
  python3 /dashboard_api.py &
  DASHBOARD_API_PID=$!
  sleep 1
  if kill -0 "$DASHBOARD_API_PID" >/dev/null 2>&1; then
    echo "INFO: Dashboard API started on 127.0.0.1:${api_port}"
  else
    echo "WARN: Dashboard API failed to start; file/schedule widgets may be unavailable"
    DASHBOARD_API_PID=""
  fi
}

clear_stale_gateway_listener() {
  local listener_pid=""
  local _i=0

  if [ "$GATEWAY_MODE" = "remote" ]; then
    return 0
  fi

  listener_pid="$(
    ss -tlnp 2>/dev/null \
      | awk -v port=":${GATEWAY_INTERNAL_PORT} " '
          $0 ~ port {
            if (match($0, /pid=[0-9]+/)) {
              print substr($0, RSTART + 4, RLENGTH - 4)
              exit
            }
          }
        ' \
      || true
  )"

  if [ -z "$listener_pid" ]; then
    return 0
  fi

  echo "WARN: Gateway port ${GATEWAY_INTERNAL_PORT} is already occupied by PID ${listener_pid}; clearing stale listener before startup."
  kill -TERM "$listener_pid" >/dev/null 2>&1 || true

  for _i in 1 2 3 4 5; do
    sleep 1
    if ! ss -tlnp 2>/dev/null | grep -q ":${GATEWAY_INTERNAL_PORT} "; then
      return 0
    fi
  done

  echo "WARN: Gateway listener on ${GATEWAY_INTERNAL_PORT} did not exit after SIGTERM; forcing shutdown."
  kill -KILL "$listener_pid" >/dev/null 2>&1 || true
  sleep 1
}

# Find a running gateway daemon's PID using multiple detection methods.
# Used by the supervisor loop to detect self-restarts (SIGUSR1) without
# spawning duplicate gateway instances that collide on the port.
#
# Three tiers, tried in order of reliability:
#   1. Port ownership via `ss -tlnp` — authoritative, but only works once
#      the daemon has bound the port (can take 20+ s on Pi hardware).
#   2. Process title via `pgrep -f openclaw-gateway` — works after Node.js
#      sets process.title, which also happens late during init.
#   3. /proc cmdline scan — catches the daemon IMMEDIATELY after fork,
#      before title or port bind, by matching "openclaw" in the cmdline.
#      Excludes known PIDs (nginx, ttyd, relay, our shell, old GW_PID).
#
# Returns the PID on stdout and exit 0, or exits with code 1 if nothing found.
find_gateway_daemon_pid() {
  local pid=""

  # Tier 1: port ownership (authoritative once port is bound)
  pid=$(ss -tlnp 2>/dev/null \
    | grep ":${GATEWAY_INTERNAL_PORT} " \
    | sed -n 's/.*pid=\([0-9]*\).*/\1/p' \
    | head -1)
  [ -n "$pid" ] && { echo "$pid"; return 0; }

  # Tier 2: process title (after Node sets process.title)
  pid=$(pgrep -f "openclaw-gateway" 2>/dev/null | head -1)
  [ -n "$pid" ] && { echo "$pid"; return 0; }

  # Tier 3: scan /proc for any openclaw process we don't already know about.
  # The daemon's cmdline (e.g. node /usr/.../openclaw/...) contains "openclaw"
  # from the moment it is forked, even before process.title is set.
  local known=" ${NGINX_PID:-0} ${TTYD_PID:-0} ${GW_RELAY_PID:-0} ${GW_PID:-0} $$ "
  local f cand
  for f in /proc/[0-9]*/cmdline; do
    [ -r "$f" ] || continue
    if tr '\0' ' ' < "$f" 2>/dev/null | grep -q "openclaw"; then
      cand="${f#/proc/}"
      cand="${cand%%/*}"
      case "$known" in *" $cand "*) continue ;; esac
      echo "$cand"
      return 0
    fi
  done

  return 1
}

compute_runtime_config_fingerprint() {
  python3 - "$OPENCLAW_CONFIG_PATH" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

cfg_path = Path(sys.argv[1])
if not cfg_path.exists():
    raise SystemExit(0)

try:
    data = json.loads(cfg_path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)

gateway = data.get("gateway") or {}
payload = json.dumps(gateway, sort_keys=True, separators=(",", ":"))
print(hashlib.sha256(payload.encode("utf-8")).hexdigest(), end="")
PY
}

request_managed_runtime_restart() {
  local reason="$1"
  local target_pid=""

  if [ -z "$target_pid" ] && [ -n "${GW_PID:-}" ] && kill -0 "${GW_PID}" >/dev/null 2>&1; then
    target_pid="$GW_PID"
  fi

  if [ -z "$target_pid" ] && [ "$GATEWAY_MODE" = "remote" ]; then
    target_pid="$(pgrep -f "openclaw.*node.*run" 2>/dev/null | head -1 || true)"
  elif [ -z "$target_pid" ]; then
    target_pid="$(find_gateway_daemon_pid 2>/dev/null || true)"
  fi

  if [ -n "$target_pid" ] && kill -0 "$target_pid" >/dev/null 2>&1; then
    printf '%s\n' "$reason" > "$RUNTIME_RESTART_REQUEST_FILE"
    echo "INFO: Managed OpenClaw runtime restart requested (${reason}); signalling PID ${target_pid}."
    kill -TERM "$target_pid" >/dev/null 2>&1 || true
    return 0
  fi

  echo "INFO: OpenClaw config changed (${reason}) but no active runtime PID was found to recycle."
  return 1
}

start_runtime_config_watcher() {
  local initial_fingerprint=""

  initial_fingerprint="$(compute_runtime_config_fingerprint 2>/dev/null || true)"

  (
    local last_fingerprint="$initial_fingerprint"
    local pending_change=false
    local pending_reason="gateway-config-changed"
    local last_change_ts=0
    local current_fingerprint=""
    local now=0

    while true; do
      sleep 4

      if [ "$SHUTTING_DOWN" = "true" ]; then
        exit 0
      fi

      current_fingerprint="$(compute_runtime_config_fingerprint 2>/dev/null || true)"
      [ -n "$current_fingerprint" ] || continue

      if [ -z "$last_fingerprint" ]; then
        last_fingerprint="$current_fingerprint"
        continue
      fi

      if [ "$current_fingerprint" != "$last_fingerprint" ]; then
        last_fingerprint="$current_fingerprint"
        pending_change=true
        last_change_ts=$(date +%s)
      fi

      if [ "$pending_change" != "true" ]; then
        continue
      fi

      if [ -f "$MANAGED_COMMAND_ACTIVE_FILE" ]; then
        continue
      fi

      now=$(date +%s)
      if [ $((now - last_change_ts)) -lt 8 ]; then
        continue
      fi

      if request_managed_runtime_restart "$pending_reason"; then
        pending_change=false
      fi
    done
  ) &
  CONFIG_WATCHER_PID=$!
}

if ! start_openclaw_runtime; then
  exit 1
fi

start_gw_relay
start_local_pairing_approver
start_dashboard_api
start_runtime_config_watcher

# Start web terminal (optional)
TTYD_PID_FILE="/var/run/openclaw-ttyd.pid"

# Clean up stale ttyd process from previous run using PID file
if [ -f "$TTYD_PID_FILE" ]; then
  OLD_PID=$(cat "$TTYD_PID_FILE" 2>/dev/null || echo "")
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Stopping previous ttyd process (PID $OLD_PID)..."
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
    # Force kill if still running
    kill -9 "$OLD_PID" 2>/dev/null || true
  fi
  rm -f "$TTYD_PID_FILE"
fi

if [ "$ENABLE_TERMINAL" = "true" ] || [ "$ENABLE_TERMINAL" = "1" ]; then
  # Check if the terminal port is already in use before starting ttyd
  if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":${TERMINAL_PORT} "; then
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!  WARNING: terminal_port ${TERMINAL_PORT} IS ALREADY IN USE  !!"
    echo "!!                                                             !!"
    echo "!!  The web terminal (ttyd) may FAIL to start because port     !!"
    echo "!!  ${TERMINAL_PORT} appears to be in use by another process.  !!"
    echo "!!                                                             !!"
    echo "!!  ACTION REQUIRED: If the terminal does not work, go to      !!"
    echo "!!  Add-on Configuration and change 'terminal_port' to a free  !!"
    echo "!!  port, then restart the add-on.                             !!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo ""
  fi
  echo "Starting web terminal (ttyd) on 127.0.0.1:${TERMINAL_PORT} ..."
  ttyd -W -i 127.0.0.1 -p "${TERMINAL_PORT}" -b /terminal bash &
  TTYD_PID=$!
  echo "$TTYD_PID" > "$TTYD_PID_FILE"
  echo "ttyd started with PID $TTYD_PID"
else
  echo "Terminal disabled (enable_terminal=$ENABLE_TERMINAL)"
fi

# Start ingress reverse proxy (nginx). This provides the add-on UI inside HA.
# Token is injected server-side; never put it in the browser URL.
NGINX_PID_FILE="/var/run/openclaw-nginx.pid"

# Clean up stale nginx process from previous run (e.g., after crash/unclean restart)
if [ -f "$NGINX_PID_FILE" ]; then
  OLD_NGINX_PID=$(cat "$NGINX_PID_FILE" 2>/dev/null || echo "")
  if [ -n "$OLD_NGINX_PID" ] && kill -0 "$OLD_NGINX_PID" 2>/dev/null; then
    echo "Stopping previous nginx process (PID $OLD_NGINX_PID)..."
    kill "$OLD_NGINX_PID" 2>/dev/null || true
    sleep 1
    kill -9 "$OLD_NGINX_PID" 2>/dev/null || true
  fi
  rm -f "$NGINX_PID_FILE"
fi
# Also kill any orphaned nginx workers that might hold the ingress port
if command -v pkill >/dev/null 2>&1; then
  pkill -f "nginx.*-c /etc/nginx/nginx.conf" 2>/dev/null || true
  sleep 1
fi
# Verify the ingress port is actually free before proceeding
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":${DEFAULT_INGRESS_PORT} "; then
  echo "WARN: Port ${DEFAULT_INGRESS_PORT} still in use after cleanup; nginx may fail to start"
fi

# Render nginx config from template.
# The gateway token is NOT managed by the add-on; OpenClaw will generate/store it.
# Read directly from config file — the CLI redacts secrets since v2026.2.22+.
GW_TOKEN="$(python3 -c "
import json, os
p = os.environ.get('OPENCLAW_CONFIG_PATH', '/config/.openclaw/openclaw.json')
print(json.load(open(p)).get('gateway',{}).get('auth',{}).get('token',''), end='')
" 2>/dev/null || true)"

# Collect disk usage for landing page status card
DISK_TOTAL="" DISK_USED="" DISK_AVAIL="" DISK_PCT=""
if df -h /config >/dev/null 2>&1; then
  DISK_TOTAL=$(df -h /config | awk 'NR==2{print $2}')
  DISK_USED=$(df -h /config | awk 'NR==2{print $3}')
  DISK_AVAIL=$(df -h /config | awk 'NR==2{print $4}')
  DISK_PCT=$(df -h /config | awk 'NR==2{print $5}')
  echo "INFO: Disk usage: ${DISK_USED}/${DISK_TOTAL} (${DISK_PCT} used, ${DISK_AVAIL} free)"
  # Warn early if disk is getting full
  DISK_PCT_NUM=${DISK_PCT//%/}
  if [ "$DISK_PCT_NUM" -ge 90 ] 2>/dev/null; then
    echo "WARNING: Disk is ${DISK_PCT} full! Add-on updates may fail. Run 'oc-cleanup' in the terminal."
  elif [ "$DISK_PCT_NUM" -ge 75 ] 2>/dev/null; then
    echo "NOTICE: Disk is ${DISK_PCT} full. Consider running 'oc-cleanup' in the terminal."
  fi
fi

GW_PUBLIC_URL="$GW_PUBLIC_URL" GW_TOKEN="$GW_TOKEN" TERMINAL_PORT="$TERMINAL_PORT" \
  ENABLE_HTTPS_PROXY="$ENABLE_HTTPS_PROXY" HTTPS_PROXY_PORT="$GATEWAY_PORT" \
  GATEWAY_INTERNAL_PORT="$GATEWAY_INTERNAL_PORT" GATEWAY_PORT="$GATEWAY_PORT" \
  GATEWAY_MODE="$GATEWAY_MODE" GATEWAY_BIND_MODE="$GATEWAY_BIND_MODE" ACCESS_MODE="$ACCESS_MODE" \
  DISK_TOTAL="$DISK_TOTAL" DISK_USED="$DISK_USED" DISK_AVAIL="$DISK_AVAIL" DISK_PCT="$DISK_PCT" \
  OPENCLAW_BUNDLED_VERSION="${OPENCLAW_BUNDLED_VERSION:-unknown}" \
  DASHBOARD_API_PORT="${OPENCLAW_DASHBOARD_API_PORT:-$DEFAULT_DASHBOARD_API_PORT}" \
  NGINX_LOG_LEVEL="$NGINX_LOG_LEVEL" \
  python3 /render_nginx.py

echo "Starting ingress proxy (nginx) on :${DEFAULT_INGRESS_PORT} ..."
nginx -g 'daemon off;' &
NGINX_PID=$!
sleep 1
if kill -0 "$NGINX_PID" 2>/dev/null; then
  echo "$NGINX_PID" > "$NGINX_PID_FILE"
  echo "nginx started with PID $NGINX_PID"
else
  echo "WARN: nginx failed to start (PID $NGINX_PID exited); ingress UI may be unavailable"
fi

# Keep the add-on alive even if the managed OpenClaw runtime exits.
# Important: we launch the runtime with OPENCLAW_NO_RESPAWN=1 so OpenClaw does
# not detach into a fresh PID under the add-on supervisor. The wrapper now owns
# one stable child process and simply restarts it if it exits.
while true; do
  GW_EXIT_CODE=0
  wait "${GW_PID}" 2>/dev/null || GW_EXIT_CODE=$?

  if [ "$SHUTTING_DOWN" = "true" ]; then
    break
  fi

  if [ "$GW_EXIT_CODE" -ne 0 ] && [ -f "$RUNTIME_WRAPPER_LOG_FILE" ]; then
    echo "WARN: Managed OpenClaw runtime log tail after exit:"
    tail -n 40 "$RUNTIME_WRAPPER_LOG_FILE" 2>/dev/null || true
  fi

  if [ -f "$RUNTIME_RESTART_REQUEST_FILE" ]; then
    RESTART_REASON="$(cat "$RUNTIME_RESTART_REQUEST_FILE" 2>/dev/null || echo "managed-request")"
    rm -f "$RUNTIME_RESTART_REQUEST_FILE"
    echo "INFO: OpenClaw runtime exited for a managed restart (${RESTART_REASON}). Restarting in 1s..."
    sleep 1
  else
    echo "WARN: OpenClaw runtime exited with code ${GW_EXIT_CODE}. Restarting in 2s..."
    sleep 2
  fi

  # Stop the loopback relay BEFORE restarting the gateway (tailnet mode only).
  # The relay holds 127.0.0.1:GATEWAY_PORT — leaving it up causes the new gateway
  # to detect the port as occupied and exit with code 1, re-entering the loop.
  stop_gw_relay

  if ! start_openclaw_runtime; then
    echo "ERROR: Failed to restart OpenClaw runtime; retrying in 5s..."
    sleep 5
  else
    rm -f "$RUNTIME_RESTART_REQUEST_FILE"
    start_gw_relay
  fi
done
