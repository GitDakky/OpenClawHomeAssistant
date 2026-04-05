#!/usr/bin/env python3
"""
Validate that add-on option/schema changes are accompanied by the required
translation/docs/changelog updates.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = "openclaw_assistant/config.yaml"
REQUIRED_COMPANION_FILES = [
    "openclaw_assistant/translations/en.yaml",
    "openclaw_assistant/translations/bg.yaml",
    "openclaw_assistant/translations/de.yaml",
    "openclaw_assistant/translations/es.yaml",
    "openclaw_assistant/translations/pl.yaml",
    "openclaw_assistant/translations/pt-BR.yaml",
    "DOCS.md",
    "openclaw_assistant/CHANGELOG.md",
]


def git(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        text=True,
        capture_output=True,
    )
    if check and result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout


def maybe_git(*args: str) -> str:
    try:
        return git(*args)
    except RuntimeError:
        return ""


def read_worktree(path: str) -> str:
    return (REPO_ROOT / path).read_text(encoding="utf-8")


def read_from_ref(ref: str, path: str) -> str:
    return maybe_git("show", f"{ref}:{path}")


def extract_top_level_blocks(text: str, section_name: str) -> dict[str, str]:
    lines = text.splitlines()
    in_section = False
    current_key: str | None = None
    current_block: list[str] = []
    blocks: dict[str, str] = {}

    section_header = f"{section_name}:"
    top_level_pattern = re.compile(r"^  ([A-Za-z0-9_-]+):")

    for line in lines:
        if not in_section:
            if line == section_header:
                in_section = True
            continue

        if line and not line.startswith(" "):
            break

        match = top_level_pattern.match(line)
        if match:
            if current_key is not None:
                blocks[current_key] = "\n".join(current_block).rstrip()
            current_key = match.group(1)
            current_block = [line]
            continue

        if current_key is not None:
            current_block.append(line)

    if current_key is not None:
        blocks[current_key] = "\n".join(current_block).rstrip()

    return blocks


def changed_option_or_schema_keys(base_text: str, current_text: str) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for section in ("options", "schema"):
        before = extract_top_level_blocks(base_text, section)
        after = extract_top_level_blocks(current_text, section)
        keys = sorted({*before.keys(), *after.keys()})
        changed = [key for key in keys if before.get(key) != after.get(key)]
        if changed:
            result[section] = changed
    return result


def collect_changed_files(base_ref: str | None) -> set[str]:
    changed: set[str] = set()

    local_diff = maybe_git("diff", "--name-only", "HEAD")
    changed.update(line.strip() for line in local_diff.splitlines() if line.strip())

    if base_ref:
        base_diff = maybe_git("diff", "--name-only", f"{base_ref}...HEAD")
        changed.update(line.strip() for line in base_diff.splitlines() if line.strip())

    return changed


def main() -> None:
    base_ref = os.environ.get("VALIDATION_BASE_REF", "").strip() or None
    current_text = read_worktree(CONFIG_PATH)

    if base_ref:
        base_text = read_from_ref(base_ref, CONFIG_PATH)
    else:
        base_text = read_from_ref("HEAD", CONFIG_PATH)

    if not base_text:
        print("INFO: No base config available for option-coupling validation; skipping.")
        return

    changed = changed_option_or_schema_keys(base_text, current_text)
    if not changed:
        print("OK: No top-level add-on option/schema changes detected")
        return

    changed_files = collect_changed_files(base_ref)
    missing = [path for path in REQUIRED_COMPANION_FILES if path not in changed_files]
    if missing:
        changed_summary = ", ".join(
            f"{section}={','.join(keys)}" for section, keys in changed.items()
        )
        print(
            f"ERROR: Add-on option/schema changes detected ({changed_summary}) but required companion files were not changed:",
            file=sys.stderr,
        )
        for path in missing:
            print(f"ERROR:   missing companion update: {path}", file=sys.stderr)
        raise SystemExit(1)

    changed_summary = ", ".join(
        f"{section}={','.join(keys)}" for section, keys in changed.items()
    )
    print(f"OK: Add-on option/schema coupling satisfied ({changed_summary})")


if __name__ == "__main__":
    main()
