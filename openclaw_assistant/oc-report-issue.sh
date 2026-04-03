#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE="${GITHUB_ISSUES_TOKEN_FILE:-/config/secrets/github_issues.token}"
REPO="${GITDAKKY_ISSUES_REPO:-GitDakky/OpenClawHomeAssistant}"
API_URL="https://api.github.com/repos/${REPO}/issues"

title=""
body=""
body_file=""
labels=""

usage() {
  cat <<'EOF'
Usage:
  oc-report-issue --title "Issue title" [--body "Markdown body" | --body-file /path/to/body.md] [--labels "bug,home-assistant"]

Notes:
  - Requires a GitHub token in /config/secrets/github_issues.token or GITHUB_ISSUES_TOKEN_FILE.
  - The token should have Issues: write access to GitDakky/OpenClawHomeAssistant.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --title)
      title="${2:-}"
      shift 2
      ;;
    --body)
      body="${2:-}"
      shift 2
      ;;
    --body-file)
      body_file="${2:-}"
      shift 2
      ;;
    --labels)
      labels="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$title" ]; then
  echo "ERROR: --title is required." >&2
  usage >&2
  exit 1
fi

if [ -n "$body_file" ]; then
  if [ ! -f "$body_file" ]; then
    echo "ERROR: Body file not found: $body_file" >&2
    exit 1
  fi
  body="$(cat "$body_file")"
fi

if [ -z "$body" ]; then
  body="$(cat)"
fi

if [ -z "$body" ]; then
  echo "ERROR: Issue body is empty. Provide --body, --body-file, or pipe markdown on stdin." >&2
  exit 1
fi

if [ ! -f "$TOKEN_FILE" ]; then
  echo "ERROR: GitHub issues token file not found at $TOKEN_FILE" >&2
  exit 1
fi

token="$(tr -d '\r\n' < "$TOKEN_FILE")"
if [ -z "$token" ]; then
  echo "ERROR: GitHub issues token file is empty at $TOKEN_FILE" >&2
  exit 1
fi

payload="$(
  jq -cn \
    --arg title "$title" \
    --arg body "$body" \
    --arg labels "$labels" '
      {
        title: $title,
        body: $body
      }
      + (if ($labels | length) > 0
         then {labels: ($labels | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)))}
         else {}
         end)
    '
)"

response_file="$(mktemp)"
http_code="$(
  curl -sS \
    -o "$response_file" \
    -w '%{http_code}' \
    -X POST "$API_URL" \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${token}" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    -d "$payload"
)"

if [ "$http_code" != "201" ]; then
  echo "ERROR: GitHub issue creation failed with HTTP ${http_code}" >&2
  cat "$response_file" >&2
  rm -f "$response_file"
  exit 1
fi

jq '{number, html_url, title, state}' "$response_file"
rm -f "$response_file"
