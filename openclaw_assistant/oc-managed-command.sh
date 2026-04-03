#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-/config/.openclaw/openclaw.json}"
REQUEST_FILE="/tmp/openclaw-runtime-restart.request"
ACTIVE_FILE="/tmp/openclaw-managed-command.active"
DEFAULT_PORT="18790"

command_name="$(basename "$0")"
subcommand=""
case "$command_name" in
  oc-onboard)
    subcommand="onboard"
    ;;
  oc-configure)
    subcommand="configure"
    ;;
  *)
    echo "ERROR: Unsupported managed OpenClaw command wrapper: $command_name" >&2
    exit 1
    ;;
esac

compute_fingerprint() {
  python3 - "$CONFIG_PATH" <<'PY'
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

read_gateway_field() {
  local field="$1"
  python3 - "$CONFIG_PATH" "$field" "$DEFAULT_PORT" <<'PY'
import json
import sys
from pathlib import Path

cfg_path = Path(sys.argv[1])
field = sys.argv[2]
default_port = sys.argv[3]
if not cfg_path.exists():
    raise SystemExit(0)

try:
    data = json.loads(cfg_path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)

gateway = data.get("gateway") or {}
if field == "mode":
    print(gateway.get("mode", "local"), end="")
elif field == "port":
    print(gateway.get("port", default_port), end="")
PY
}

signal_runtime_restart() {
  local reason="$1"
  local mode port pid

  mode="$(read_gateway_field mode)"
  port="$(read_gateway_field port)"
  port="${port:-$DEFAULT_PORT}"

  if [ "$mode" = "remote" ]; then
    pid="$(pgrep -f "openclaw.*node.*run" 2>/dev/null | head -1 || true)"
  else
    pid="$(
      ss -tlnp 2>/dev/null \
        | awk -v port=":${port} " '
            $0 ~ port {
              if (match($0, /pid=[0-9]+/)) {
                print substr($0, RSTART + 4, RLENGTH - 4)
                exit
              }
            }
          ' \
        || true
    )"
    if [ -z "$pid" ]; then
      pid="$(pgrep -f "openclaw-gateway" 2>/dev/null | head -1 || true)"
    fi
  fi

  if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
    printf '%s\n' "$reason" > "$REQUEST_FILE"
    echo "INFO: Gateway config changed. Requesting managed runtime restart (PID ${pid})."
    kill -TERM "$pid" >/dev/null 2>&1 || true
  else
    echo "INFO: Gateway config changed, but no active runtime PID was found to recycle."
  fi
}

before_fingerprint="$(compute_fingerprint 2>/dev/null || true)"
printf '%s\n' "$subcommand" > "$ACTIVE_FILE"
trap 'rm -f "$ACTIVE_FILE"' EXIT INT TERM

set +e
openclaw "$subcommand" "$@"
status=$?
set -e

if [ "$status" -eq 0 ]; then
  after_fingerprint="$(compute_fingerprint 2>/dev/null || true)"
  if [ -n "$before_fingerprint" ] && [ -n "$after_fingerprint" ] && [ "$before_fingerprint" != "$after_fingerprint" ]; then
    signal_runtime_restart "managed-${subcommand}"
  fi
fi

exit "$status"
