#!/usr/bin/env python3
"""Codex hook guard that mechanically enforces specialist skill-harness evidence.

The guard is intentionally conservative and dependency-free. It activates only
when a project has the explicit marker
`.codex/agent-events/skill-harness-required`, which `$implement-tdd` creates
before dispatching specialist implementation work. This avoids turning a normal
`.codex/agent-events/` directory into a global tool blocker.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

REQUIRED_DIR = Path(".codex") / "agent-events"
HARNESS_DIR = REQUIRED_DIR / "skill-harness"
MARKER_FILE = REQUIRED_DIR / "skill-harness-required"
RECENT_SECONDS = 72 * 60 * 60

MUTATING_BASH_PATTERNS = re.compile(
    r"(apply_patch|cat\s*>|tee\s+|>>|>|python\s+-c|python3\s+-c|node\s+-e|npm\s+(run\s+)?(test|build)|pytest|dotnet\s+(test|build)|go\s+test|git\s+(commit|merge|rebase|push|checkout\s+-b))",
    re.IGNORECASE,
)


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def block_pre(reason: str) -> int:
    emit(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }
    )
    return 0


def block_stop(reason: str) -> int:
    emit({"decision": "block", "reason": reason})
    return 0


def ok_context(message: str | None = None, event_name: str | None = None) -> int:
    if message and event_name in {"PreToolUse", "UserPromptSubmit"}:
        emit({"hookSpecificOutput": {"hookEventName": event_name, "additionalContext": message}})
    else:
        # Stop hooks expect JSON on success.
        emit({"continue": True, "suppressOutput": True})
    return 0


def find_root(cwd: Path) -> Path:
    # Prefer the nearest active implementation root. Test worktrees or nested
    # sandboxes can live inside a larger Git checkout, and the guard should bind
    # to the project that owns the explicit harness marker.
    for candidate in [cwd, *cwd.parents]:
        if (candidate / MARKER_FILE).exists():
            return candidate

    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=str(cwd),
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=3,
        ).strip()
        if out:
            return Path(out)
    except Exception:
        pass
    return cwd


def active(root: Path) -> bool:
    return (root / MARKER_FILE).exists()


def tool_command(event: dict[str, Any]) -> str:
    tool_input = event.get("tool_input")
    if isinstance(tool_input, dict):
        value = tool_input.get("command") or tool_input.get("cmd") or ""
        if isinstance(value, str):
            return value
        return json.dumps(value, ensure_ascii=False)
    if isinstance(tool_input, str):
        return tool_input
    return ""


def creating_harness(event: dict[str, Any]) -> bool:
    blob = tool_command(event)
    if not blob:
        try:
            blob = json.dumps(event.get("tool_input"), ensure_ascii=False)
        except Exception:
            blob = ""
    normalized = blob.replace("\\", "/").lower()
    return (
        ".codex/agent-events/skill-harness" in normalized
        or ".codex/agent-events/skill-harness-required" in normalized
        or "skill-harness" in normalized
    )


def evidence_files(root: Path) -> list[Path]:
    directory = root / HARNESS_DIR
    if not directory.exists():
        return []
    return sorted(directory.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)


def evidence_ok(root: Path) -> tuple[bool, str]:
    files = evidence_files(root)
    if not files:
        return False, f"missing {HARNESS_DIR}/*.md evidence"

    now = None
    try:
        import time

        now = time.time()
    except Exception:
        pass

    for path in files:
        try:
            stat = path.stat()
            text = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        if now is not None and now - stat.st_mtime > RECENT_SECONDS:
            continue
        lowered = text.lower()
        required_fields = ["task:", "agent:", "loaded:", "rules:", "constraints:"]
        has_required_fields = all(field in lowered for field in required_fields)
        has_skill_path = any(token in lowered for token in ["skill.md", "/skills/", "\\skills\\", "mandatory", "instruction"])
        has_loaded_item = bool(re.search(r"(?im)^\s*-\s+(path|skill|name|file)\s*:", text))
        has_rule_item = bool(re.search(r"(?im)^\s*-\s+.+", text)) and "rules:" in lowered
        if has_required_fields and has_skill_path and has_loaded_item and has_rule_item:
            return True, str(path.relative_to(root))

    return False, f"no recent {HARNESS_DIR}/*.md contains structured task/agent/loaded/rules/constraints evidence"


def pre_tool(event: dict[str, Any], root: Path) -> int:
    tool = str(event.get("tool_name") or "")
    command = tool_command(event)

    # Always allow creation/update of the harness itself.
    if creating_harness(event):
        return ok_context("Skill-harness evidence update allowed by guard.", "PreToolUse")

    must_check = tool in {"apply_patch", "Edit", "Write"}
    if tool == "Bash" and MUTATING_BASH_PATTERNS.search(command or ""):
        must_check = True

    if not must_check:
        return ok_context(None, "PreToolUse")

    ok, detail = evidence_ok(root)
    if ok:
        return ok_context(f"Skill-harness guard found evidence: {detail}", "PreToolUse")

    return block_pre(
        "Specialist skill-harness evidence is required before edits/tests/mutating commands. "
        f"Create {HARNESS_DIR}/<task-id>-<agent-name>.md with task:, agent:, loaded:, rules:, and constraints: "
        f"fields before continuing. Detail: {detail}"
    )


def stop(event: dict[str, Any], root: Path) -> int:
    ok, detail = evidence_ok(root)
    if ok:
        return ok_context(None, "Stop")
    return block_stop(
        "Cannot finish an $implement-tdd specialist task without mechanical skill-harness evidence. "
        f"Write {HARNESS_DIR}/<task-id>-<agent-name>.md with task:, agent:, loaded:, rules:, and constraints: "
        f"fields before finishing. Detail: {detail}"
    )


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception as exc:
        # Fail open outside parseable hook payloads to avoid breaking unrelated Codex starts.
        return ok_context(f"skill-harness-guard: invalid payload: {exc}", "PreToolUse")

    cwd = Path(str(event.get("cwd") or os.getcwd()))
    root = find_root(cwd)
    event_name = str(event.get("hook_event_name") or event.get("hook") or "")

    if not active(root):
        return ok_context(None, event_name)

    if event_name == "PreToolUse":
        return pre_tool(event, root)
    if event_name == "Stop":
        return stop(event, root)
    if event_name == "UserPromptSubmit":
        return ok_context(
            "Mechanical skill-harness guard is active because .codex/agent-events/skill-harness-required exists. Specialist tasks must create structured .codex/agent-events/skill-harness evidence before edits/tests and before Stop.",
            "UserPromptSubmit",
        )

    return ok_context(None, event_name)


if __name__ == "__main__":
    raise SystemExit(main())
