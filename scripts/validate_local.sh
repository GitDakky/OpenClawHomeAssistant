#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Repo metadata"
python3 scripts/validate_release_metadata.py

echo "==> Option/schema coupling"
python3 scripts/validate_option_coupling.py

echo "==> Bash syntax"
bash -n openclaw_assistant/run.sh
bash -n openclaw_assistant/run_helpers.sh

echo "==> Python compile"
python3 -m py_compile \
  scripts/validate_option_coupling.py \
  openclaw_assistant/oc_config_helper.py \
  openclaw_assistant/render_nginx.py \
  openclaw_assistant/dashboard_api.py

echo "==> Python unit tests"
python3 -m unittest discover -s tests -v

echo "==> SVG parse"
python3 - <<'PY'
import xml.etree.ElementTree as ET

ET.parse("assets/openclaw-hero.svg")
ET.parse("assets/openclaw-architecture.svg")
print("svg-ok")
PY

echo "OK: local validation passed"
