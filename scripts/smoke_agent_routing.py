#!/usr/bin/env python3
"""Smoke-check specialist agent routing rules for a synthetic DRF + React plan."""

from __future__ import annotations

import os
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FIXTURE = ROOT / "scripts" / "fixtures" / "agent-routing"
SANDBOX = Path(os.environ.get("CODEX_CONFIG_ROUTING_SMOKE_DIR", DEFAULT_FIXTURE))

EXPECTED = {
    "Django/DRF backend": {
        "agent": "backend-django-drf-tdd",
        "skills": ["django-tdd", "drf", "senior-django-developer"],
        "forbidden": ["worker", "default", "frontend-react-vite-tdd"],
    },
    "React/Vite frontend": {
        "agent": "frontend-react-vite-tdd",
        "skills": ["react-vite", "frontend-testing", "testing-library"],
        "forbidden": ["worker", "default", "backend-django-drf-tdd"],
    },
}


def load_agent(name: str) -> str:
    path = ROOT / "agents" / f"{name}.toml"
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    return data["developer_instructions"]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def parse_tasks() -> dict[str, str]:
    text = (SANDBOX / "tasks.md").read_text(encoding="utf-8")
    sections: dict[str, str] = {}
    for block in re.split(r"(?=^## )", text, flags=re.M):
        m = re.search(r"^Stack:\s*(.+)$", block, flags=re.M)
        if m:
            sections[m.group(1).strip()] = block
    return sections


def main() -> int:
    tasks = parse_tasks()
    require(set(EXPECTED).issubset(tasks), f"missing expected task stacks: {set(EXPECTED) - set(tasks)}")

    implement_tdd = (ROOT / "skills" / "implement-tdd" / "SKILL.md").read_text(encoding="utf-8")
    prompt_contracts = (ROOT / "skills" / "implement-tdd" / "references" / "prompt-contracts.md").read_text(encoding="utf-8")
    agents_readme = (ROOT / "agents" / "README.md").read_text(encoding="utf-8")
    spec_flow = (ROOT / "skills" / "spec-flow" / "SKILL.md").read_text(encoding="utf-8")
    shared_config = (ROOT / "config.shared.toml").read_text(encoding="utf-8")
    guard_hook = (ROOT / "hooks" / "skill-harness-guard.py").read_text(encoding="utf-8")

    require("Do not route code changes through a generic fallback agent" in implement_tdd, "implement-tdd lacks generic fallback prohibition")
    require("mandatory skill/load checklist" in implement_tdd, "implement-tdd lacks mandatory skill/load checklist requirement")
    require("| Task | Stack | Agent | Mandatory skills loaded |" in prompt_contracts, "prompt contracts lack expanded stack/skills matrix")
    require("Specialist agents are not reusable generalists" in agents_readme, "agents README lacks hard specialist routing rule")
    require("stacks detected" in spec_flow, "spec-flow handoff lacks detected stack metadata")
    require("specialist expected by stack" in spec_flow, "spec-flow handoff lacks expected specialist metadata")
    require("manual end-to-end" in implement_tdd, "implement-tdd lacks manual E2E requirement")
    require("every user-facing flow" in implement_tdd, "implement-tdd lacks full user-flow manual E2E coverage")
    require("manual e2e required" in spec_flow, "spec-flow handoff lacks manual E2E metadata")
    require("minimum validation by stack" in spec_flow, "spec-flow handoff lacks stack validation checklist")
    require("skill harness required" in spec_flow, "spec-flow handoff lacks harness activation metadata")
    require("manual end-to-end validation" in prompt_contracts, "prompt contracts lack manual E2E reviewer check")
    require("skill-harness evidence" in implement_tdd, "implement-tdd lacks skill harness evidence requirement")
    require("not a memory summary" in prompt_contracts, "prompt contract allows summarized skill usage")
    require("reload the mandatory skill files" in prompt_contracts, "prompt contract lacks reload-after-compaction rule")
    require("skill-harness-required" in implement_tdd, "implement-tdd does not document explicit harness marker")
    require("skill-harness-required" in guard_hook, "guard hook does not require explicit activation marker")
    require("skill-harness-guard.py" in shared_config, "config.shared.toml does not install mechanical skill-harness hook")
    require("[[hooks.PreToolUse]]" in shared_config and "[[hooks.Stop]]" in shared_config, "mechanical guard must run before tools and at stop")
    require("permissionDecision\": \"deny" in guard_hook, "guard hook cannot mechanically deny tool use")
    require("Cannot finish an $implement-tdd specialist task" in guard_hook, "guard hook cannot mechanically block Stop")
    for field in ["task:", "agent:", "loaded:", "rules:", "constraints:"]:
        require(field in implement_tdd, f"implement-tdd lacks structured harness field {field}")
        require(field in prompt_contracts, f"prompt contracts lack structured harness field {field}")

    for stack, expected in EXPECTED.items():
        block = tasks[stack]
        require(f"Expected agent: {expected['agent']}" in block, f"{stack} task does not name expected specialist")
        agent_instructions = load_agent(expected["agent"])
        require("Scope and skill gate" in agent_instructions, f"{expected['agent']} lacks scope/skill gate")
        require("Skill harness evidence" in agent_instructions, f"{expected['agent']} lacks skill harness evidence gate")
        require("Do not replace them with a memory summary" in agent_instructions, f"{expected['agent']} allows summarized skill usage")
        require("report `blocked`" in agent_instructions, f"{expected['agent']} does not require blocked on mismatch")
        for skill in expected["skills"]:
            require(skill in agent_instructions, f"{expected['agent']} lacks mandatory skill {skill}")
        for forbidden in expected["forbidden"]:
            require(forbidden not in block, f"{stack} task unexpectedly routes to {forbidden}")

    worker = load_agent("worker")
    default = load_agent("default")
    require("Do not accept coding work when a stack-specific agent exists" in worker, "worker does not refuse specialist coding work")
    require("Do not accept software implementation work when a stack-specific agent exists" in default, "default does not refuse specialist coding work")

    print("PASS: synthetic Django/DRF + React/Vite plan routes to specialist agents with mandatory skill harness evidence and manual E2E closure rule")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
