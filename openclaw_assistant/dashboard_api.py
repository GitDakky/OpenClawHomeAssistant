#!/usr/bin/env python3
"""Local dashboard API for the Home Assistant ingress page."""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

HOST = "127.0.0.1"
PORT = int(os.environ.get("OPENCLAW_DASHBOARD_API_PORT", "48110"))
WORKSPACE_DIR = Path(os.environ.get("OPENCLAW_WORKSPACE_DIR", "/config/clawd"))
SKILLS_DIR = Path(os.environ.get("OPENCLAW_SKILLS_DIR", "/config/.openclaw/skills"))
GRAPH_DB_PATH = Path(
    os.environ.get("OPENCLAW_SYSTEM_GRAPH_PATH", "/config/.openclaw/gitdakky-system-graph.sqlite3")
)

WORKSPACE_FILES = [
    "AGENTS.md",
    "BOOTSTRAP.md",
    "HEARTBEAT.md",
    "IDENTITY.md",
    "MEMORY.md",
    "SOUL.md",
    "TOOLS.md",
    "USER.md",
]

BUNDLED_SKILL_NAMES = [
    "ha-operator",
    "ha-automations",
    "ha-voice-assist",
    "ha-diagnostics",
    "ha-network-map",
    "ha-best-practices",
    "ha-research",
    "ha-file-access",
    "domotz-operator",
    "bacnet-scout",
    "mqtt-broker",
]


def bool_env(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def read_preview(path: Path, max_chars: int = 1200) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")[:max_chars]


def run_json_command(command: list[str], timeout: int = 4) -> tuple[Any | None, str | None]:
    try:
        proc = subprocess.run(
            command,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except Exception as exc:  # pragma: no cover - defensive
        return None, str(exc)

    if proc.returncode != 0:
        error = proc.stderr.strip() or proc.stdout.strip() or f"exit {proc.returncode}"
        return None, error

    try:
        return json.loads(proc.stdout or "null"), None
    except json.JSONDecodeError as exc:
        return None, f"invalid JSON: {exc}"


def run_text_command(command: list[str], timeout: int = 4) -> tuple[str | None, str | None]:
    try:
        proc = subprocess.run(
            command,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except Exception as exc:  # pragma: no cover - defensive
        return None, str(exc)

    if proc.returncode != 0:
        error = proc.stderr.strip() or proc.stdout.strip() or f"exit {proc.returncode}"
        return None, error
    return (proc.stdout or "").strip(), None


def system_ips() -> list[str]:
    output, error = run_text_command(["hostname", "-I"], timeout=2)
    if error or not output:
        return []
    return [token for token in output.split() if token]


def ensure_graph_db() -> None:
    GRAPH_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(GRAPH_DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS nodes (
              id INTEGER PRIMARY KEY,
              kind TEXT NOT NULL,
              name TEXT NOT NULL UNIQUE,
              label TEXT,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS edges (
              id INTEGER PRIMARY KEY,
              source_name TEXT NOT NULL,
              relation TEXT NOT NULL,
              target_name TEXT NOT NULL,
              metadata_json TEXT NOT NULL DEFAULT '{}',
              updated_at TEXT NOT NULL,
              UNIQUE(source_name, relation, target_name)
            )
            """
        )
        conn.commit()


def upsert_node(conn: sqlite3.Connection, kind: str, name: str, label: str, metadata: dict[str, Any]) -> None:
    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        INSERT INTO nodes (kind, name, label, metadata_json, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(name) DO UPDATE SET
          kind=excluded.kind,
          label=excluded.label,
          metadata_json=excluded.metadata_json,
          updated_at=excluded.updated_at
        """,
        (kind, name, label, json.dumps(metadata, sort_keys=True), now),
    )


def upsert_edge(conn: sqlite3.Connection, source: str, relation: str, target: str, metadata: dict[str, Any] | None = None) -> None:
    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        INSERT INTO edges (source_name, relation, target_name, metadata_json, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(source_name, relation, target_name) DO UPDATE SET
          metadata_json=excluded.metadata_json,
          updated_at=excluded.updated_at
        """,
        (source, relation, target, json.dumps(metadata or {}, sort_keys=True), now),
    )


def refresh_graph_snapshot() -> dict[str, Any]:
    ensure_graph_db()
    with sqlite3.connect(GRAPH_DB_PATH) as conn:
        upsert_node(
            conn,
            "service",
            "openclaw-super-home-assistant",
            "OpenClaw Super Home Assistant",
            {
                "bundledVersion": os.environ.get("OPENCLAW_BUNDLED_VERSION", "unknown"),
                "gatewayMode": os.environ.get("GATEWAY_MODE", ""),
                "accessMode": os.environ.get("ACCESS_MODE", ""),
            },
        )
        upsert_node(conn, "workspace", str(WORKSPACE_DIR), "OpenClaw Workspace", {"path": str(WORKSPACE_DIR)})
        upsert_edge(conn, "openclaw-super-home-assistant", "uses_workspace", str(WORKSPACE_DIR))

        for ip in system_ips():
            node_name = f"ip:{ip}"
            upsert_node(conn, "ip", node_name, ip, {"address": ip})
            upsert_edge(conn, "openclaw-super-home-assistant", "has_ip", node_name)

        integrations = [
            ("context7", bool_env("CONTEXT7_ENABLED"), {"configured": bool_env("CONTEXT7_ENABLED")}),
            (
                "domotz",
                bool_env("DOMOTZ_ENABLED"),
                {"configured": bool_env("DOMOTZ_ENABLED"), "siteId": os.environ.get("DOMOTZ_SITE_ID", "")},
            ),
            (
                "mqtt",
                bool_env("MQTT_ENABLED"),
                {"configured": bool_env("MQTT_ENABLED"), "brokerUrl": os.environ.get("MQTT_BROKER_URL", "")},
            ),
            ("bacnet", bool_env("BACNET_SCOUT_ENABLED"), {"configured": bool_env("BACNET_SCOUT_ENABLED")}),
            (
                "home-assistant-mcp",
                bool_env("HA_MCP_ENABLED"),
                {"configured": bool_env("HA_MCP_ENABLED")},
            ),
        ]
        for name, configured, metadata in integrations:
            upsert_node(conn, "integration", name, name.replace("-", " ").title(), metadata)
            if configured:
                upsert_edge(conn, "openclaw-super-home-assistant", "uses_integration", name)

        conn.commit()
        node_count = conn.execute("SELECT COUNT(*) FROM nodes").fetchone()[0]
        edge_count = conn.execute("SELECT COUNT(*) FROM edges").fetchone()[0]

    return {
        "path": str(GRAPH_DB_PATH),
        "exists": GRAPH_DB_PATH.exists(),
        "nodeCount": node_count,
        "edgeCount": edge_count,
    }


def workspace_entries() -> list[dict[str, Any]]:
    entries = []
    for name in WORKSPACE_FILES:
        path = WORKSPACE_DIR / name
        entries.append(
            {
                "key": f"workspace:{name}",
                "name": name,
                "path": str(path),
                "exists": path.exists(),
                "preview": read_preview(path),
                "size": path.stat().st_size if path.exists() else 0,
            }
        )
    return entries


def skill_entries() -> list[dict[str, Any]]:
    entries = []
    for name in BUNDLED_SKILL_NAMES:
        path = SKILLS_DIR / name / "SKILL.md"
        entries.append(
            {
                "key": f"skill:{name}",
                "name": name,
                "path": str(path),
                "exists": path.exists(),
                "preview": read_preview(path, max_chars=800),
                "size": path.stat().st_size if path.exists() else 0,
            }
        )
    return entries


def integration_status() -> dict[str, Any]:
    return {
        "context7": {
            "configured": bool_env("CONTEXT7_ENABLED"),
            "secretPath": "/config/secrets/context7.api_key",
        },
        "domotz": {
            "configured": bool_env("DOMOTZ_ENABLED"),
            "siteId": os.environ.get("DOMOTZ_SITE_ID", ""),
            "secretPath": "/config/secrets/domotz.api_key",
        },
        "mqtt": {
            "configured": bool_env("MQTT_ENABLED"),
            "brokerUrl": os.environ.get("MQTT_BROKER_URL", ""),
            "usernameConfigured": bool_env("MQTT_USERNAME_CONFIGURED"),
            "passwordConfigured": bool_env("MQTT_PASSWORD_CONFIGURED"),
            "secretPaths": [
                "/config/secrets/mqtt.broker_url",
                "/config/secrets/mqtt.username",
                "/config/secrets/mqtt.password",
            ],
        },
        "bacnet": {
            "configured": bool_env("BACNET_SCOUT_ENABLED"),
            "notes": "Opt-in BACnet discovery scaffolding is enabled when the add-on option is on.",
        },
        "homeAssistantMcp": {
            "configured": bool_env("HA_MCP_ENABLED"),
            "tokenPath": "/config/secrets/homeassistant.token",
        },
    }


def schedule_state() -> dict[str, Any]:
    cron_status, cron_status_error = run_json_command(["openclaw", "cron", "status", "--json"])
    cron_jobs, cron_jobs_error = run_json_command(["openclaw", "cron", "list", "--json", "--all"])
    cron_runs, cron_runs_error = run_text_command(["openclaw", "cron", "runs", "--limit", "8"])
    heartbeat_last, heartbeat_error = run_text_command(["openclaw", "system", "heartbeat", "last"])
    return {
        "cronStatus": {"data": cron_status, "error": cron_status_error},
        "cronJobs": {"data": cron_jobs, "error": cron_jobs_error},
        "cronRuns": {"data": cron_runs, "error": cron_runs_error},
        "heartbeatLast": {"data": heartbeat_last, "error": heartbeat_error},
    }


def resolve_file_key(file_key: str) -> Path | None:
    if file_key.startswith("workspace:"):
        name = file_key.split(":", 1)[1]
        if name in WORKSPACE_FILES:
            return WORKSPACE_DIR / name
        return None
    if file_key.startswith("skill:"):
        name = file_key.split(":", 1)[1]
        if name in BUNDLED_SKILL_NAMES:
            return SKILLS_DIR / name / "SKILL.md"
        return None
    return None


class Handler(BaseHTTPRequestHandler):
    server_version = "OpenClawDashboard/1.0"

    def log_message(self, format: str, *args: Any) -> None:  # pragma: no cover - keep logs quiet
        return

    def send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/state":
            payload = {
                "generatedAt": datetime.now(timezone.utc).isoformat(),
                "workspaceFiles": workspace_entries(),
                "skillFiles": skill_entries(),
                "integrations": integration_status(),
                "schedule": schedule_state(),
                "graph": refresh_graph_snapshot(),
            }
            self.send_json(HTTPStatus.OK, payload)
            return

        if parsed.path == "/api/file":
            file_key = parse_qs(parsed.query).get("key", [""])[0]
            target = resolve_file_key(file_key)
            if target is None:
                self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Unknown file key"})
                return
            content = target.read_text(encoding="utf-8") if target.exists() else ""
            self.send_json(
                HTTPStatus.OK,
                {
                    "key": file_key,
                    "path": str(target),
                    "content": content,
                    "exists": target.exists(),
                },
            )
            return

        self.send_json(HTTPStatus.NOT_FOUND, {"error": "Not found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/api/file":
            self.send_json(HTTPStatus.NOT_FOUND, {"error": "Not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Invalid Content-Length"})
            return

        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Invalid JSON"})
            return

        file_key = str(payload.get("key", ""))
        content = payload.get("content", "")
        if not isinstance(content, str):
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Content must be a string"})
            return

        target = resolve_file_key(file_key)
        if target is None:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Unknown file key"})
            return

        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        self.send_json(
            HTTPStatus.OK,
            {
                "key": file_key,
                "path": str(target),
                "savedAt": datetime.now(timezone.utc).isoformat(),
            },
        )


def main() -> None:
    ensure_graph_db()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    server.daemon_threads = True
    print(f"INFO: Dashboard API listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
