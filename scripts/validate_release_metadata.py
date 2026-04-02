#!/usr/bin/env python3
"""
Small repo-level validation checks for version and metadata drift.
Keep this dependency-free so it can run in CI before the add-on image builds.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (REPO_ROOT / path).read_text(encoding="utf-8")


def extract(pattern: str, text: str, label: str) -> str:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if not match:
        raise SystemExit(f"ERROR: Could not extract {label}")
    return match.group(1)


def main() -> None:
    dockerfile = read("openclaw_assistant/Dockerfile")
    config_yaml = read("openclaw_assistant/config.yaml")
    changelog = read("openclaw_assistant/CHANGELOG.md")
    readme = read("README.md")
    docs = read("DOCS.md")
    repository_yaml = read("repository.yaml")
    issue_template_cfg = read(".github/ISSUE_TEMPLATE/config.yml")

    openclaw_version = extract(
        r"^ARG OPENCLAW_VERSION=([^\s]+)$",
        dockerfile,
        "Dockerfile OPENCLAW_VERSION",
    )
    addon_version = extract(
        r'^version:\s*"([^"]+)"$',
        config_yaml,
        "config.yaml version",
    )
    changelog_version = extract(
        r"^## \[([^\]]+)\]",
        changelog,
        "top CHANGELOG version",
    )
    addon_url = extract(r"^url:\s*(\S+)$", config_yaml, "config.yaml url")
    image_name = extract(r'^image:\s*"([^"]+)"$', config_yaml, "config.yaml image")
    repo_url = extract(r"^url:\s*(\S+)$", repository_yaml, "repository.yaml url")
    issue_docs_url = extract(
        r"^\s+url:\s*(https://\S+/DOCS\.md)$",
        issue_template_cfg,
        "issue template docs url",
    )

    errors: list[str] = []

    if addon_version != changelog_version:
        errors.append(
            f"config.yaml version ({addon_version}) does not match top CHANGELOG entry ({changelog_version})"
        )

    if repo_url != addon_url:
        errors.append(f"repository.yaml url ({repo_url}) does not match config.yaml url ({addon_url})")

    if repo_url not in issue_docs_url:
        errors.append(f"issue template docs url ({issue_docs_url}) does not point at repo url ({repo_url})")

    if image_name != "ghcr.io/gitdakky/openclaw-super-home-assistant":
        errors.append(f"config.yaml image ({image_name}) does not match expected published image")

    if "ARG BUILD_FROM" in dockerfile or "FROM ${BUILD_FROM}" in dockerfile:
        errors.append("Dockerfile still uses deprecated BUILD_FROM/build.yaml flow")

    if (REPO_ROOT / "openclaw_assistant/build.yaml").exists():
        errors.append("openclaw_assistant/build.yaml should be removed after Dockerfile migration")

    if f"Bundled OpenClaw: `{openclaw_version}`" not in readme:
        errors.append(f"README.md does not advertise bundled OpenClaw version {openclaw_version}")

    if f"Bundled OpenClaw version in this fork:** `{openclaw_version}`" not in docs:
        errors.append(f"DOCS.md does not advertise bundled OpenClaw version {openclaw_version}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)

    print(f"OK: add-on {addon_version}, bundled OpenClaw {openclaw_version}, repo metadata aligned")


if __name__ == "__main__":
    main()
