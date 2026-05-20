#!/usr/bin/env python3
"""Inventory and copy global Codex skills/plugins into a project."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any


HOME = Path.home()
GLOBAL_SKILL_ROOTS = (
    ("codex", HOME / ".codex" / "skills"),
    ("agents", HOME / ".agents" / "skills"),
)
GLOBAL_CONFIG = HOME / ".codex" / "config.toml"


@dataclass(frozen=True)
class SkillRecord:
    name: str
    source: str
    path: Path
    description: str


@dataclass(frozen=True)
class PluginRecord:
    name: str
    marketplace: str
    path: Path | None
    enabled: bool
    category: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def frontmatter_value(text: str, key: str) -> str:
    if not text.startswith("---"):
        return ""
    lines = text.splitlines()
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith(f"{key}:"):
            value = line.split(":", 1)[1].strip()
            return value.strip('"').strip("'")
    return ""


def list_skills(include_system: bool = False) -> list[SkillRecord]:
    records: list[SkillRecord] = []
    for source, root in GLOBAL_SKILL_ROOTS:
        if not root.exists():
            continue
        for skill_dir in sorted(p for p in root.iterdir() if p.is_dir()):
            if skill_dir.name.startswith(".") and not include_system:
                continue
            skill_file = skill_dir / "SKILL.md"
            if not skill_file.is_file():
                continue
            text = read_text(skill_file)
            records.append(
                SkillRecord(
                    name=frontmatter_value(text, "name") or skill_dir.name,
                    source=source,
                    path=skill_dir,
                    description=frontmatter_value(text, "description"),
                )
            )
    return sorted(records, key=lambda item: (item.source, item.name))


def load_toml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    return tomllib.loads(path.read_text(encoding="utf-8"))


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def marketplace_roots(config: dict[str, Any]) -> dict[str, Path]:
    roots: dict[str, Path] = {}
    for name, data in config.get("marketplaces", {}).items():
        if data.get("source_type") != "local":
            continue
        source = data.get("source")
        if source:
            roots[name] = Path(str(source).replace("\\\\?\\", ""))
    local_home_marketplace = HOME / ".agents" / "plugins" / "marketplace.json"
    if local_home_marketplace.is_file():
        roots.setdefault("imale-local", HOME)
    return roots


def enabled_plugins(config: dict[str, Any]) -> set[str]:
    enabled: set[str] = set()
    for name, data in config.get("plugins", {}).items():
        if data.get("enabled") is True:
            enabled.add(name)
    return enabled


def list_plugins() -> list[PluginRecord]:
    config = load_toml(GLOBAL_CONFIG)
    enabled = enabled_plugins(config)
    records: list[PluginRecord] = []
    for marketplace, root in marketplace_roots(config).items():
        marketplace_file = root / ".agents" / "plugins" / "marketplace.json"
        data = load_json(marketplace_file)
        for entry in data.get("plugins", []):
            name = entry.get("name")
            if not name:
                continue
            source = entry.get("source", {})
            path: Path | None = None
            if source.get("source") == "local" and source.get("path"):
                path = (root / source["path"]).resolve()
            records.append(
                PluginRecord(
                    name=name,
                    marketplace=marketplace,
                    path=path if path and path.exists() else None,
                    enabled=f"{name}@{marketplace}" in enabled,
                    category=entry.get("category") or "Productivity",
                )
            )
    return sorted(records, key=lambda item: (item.marketplace, item.name))


def inventory(include_system: bool = False) -> dict[str, Any]:
    skills = list_skills(include_system=include_system)
    plugins = list_plugins()
    return {
        "instructions": "Delete everything you do not want and return this JSON to $project-setup.",
        "skills": [
            {
                "name": item.name,
                "source": item.source,
                "path": str(item.path),
                "description": item.description,
            }
            for item in skills
        ],
        "plugins": [
            {
                "name": item.name,
                "marketplace": item.marketplace,
                "enabled": item.enabled,
                "copyable": item.path is not None,
                "path": str(item.path) if item.path else "",
                "category": item.category,
            }
            for item in plugins
        ],
    }


def index_skills() -> dict[tuple[str, str], SkillRecord]:
    return {(item.source, item.name): item for item in list_skills(include_system=True)}


def index_plugins() -> dict[tuple[str, str], PluginRecord]:
    return {(item.marketplace, item.name): item for item in list_plugins()}


def copytree(src: Path, dst: Path) -> None:
    if not src.exists():
        raise FileNotFoundError(src)
    shutil.copytree(src, dst, dirs_exist_ok=True)


def ensure_marketplace(project_root: Path) -> Path:
    marketplace_path = project_root / ".agents" / "plugins" / "marketplace.json"
    marketplace_path.parent.mkdir(parents=True, exist_ok=True)
    if marketplace_path.exists():
        return marketplace_path
    data = {
        "name": f"{project_root.name or 'project'}-local",
        "interface": {"displayName": f"{project_root.name or 'Project'} Local"},
        "plugins": [],
    }
    marketplace_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return marketplace_path


def upsert_plugin_entry(marketplace_path: Path, name: str, category: str) -> None:
    data = load_json(marketplace_path)
    plugins = data.setdefault("plugins", [])
    entry = {
        "name": name,
        "source": {"source": "local", "path": f"./plugins/{name}"},
        "policy": {
            "installation": "INSTALLED_BY_DEFAULT",
            "authentication": "ON_INSTALL",
        },
        "category": category,
    }
    for idx, existing in enumerate(plugins):
        if existing.get("name") == name:
            plugins[idx] = entry
            break
    else:
        plugins.append(entry)
    marketplace_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def ps1_without_sh(root: Path) -> list[str]:
    missing: list[str] = []
    if not root.exists():
        return missing
    for script in sorted(root.rglob("*.ps1")):
        if "__pycache__" in script.parts:
            continue
        if not script.with_suffix(".sh").exists():
            missing.append(str(script.relative_to(root)))
    return missing


def install(selection_path: Path, project_root: Path) -> dict[str, Any]:
    selection = load_json(selection_path)
    skills_by_key = index_skills()
    plugins_by_key = index_plugins()
    installed_skills: list[str] = []
    installed_plugins: list[str] = []
    warnings: list[str] = []

    for item in selection.get("skills", []):
        source = item.get("source")
        name = item.get("name")
        record = skills_by_key.get((source, name))
        if not record:
            raise ValueError(f"Unknown skill selection: {source}/{name}")
        target = project_root / ".agents" / "skills" / name
        copytree(record.path, target)
        for missing in ps1_without_sh(target):
            warnings.append(f"skill {name}: {missing} has no matching .sh")
        installed_skills.append(str(target))

    marketplace_path: Path | None = None
    for item in selection.get("plugins", []):
        marketplace = item.get("marketplace")
        name = item.get("name")
        record = plugins_by_key.get((marketplace, name))
        if not record:
            raise ValueError(f"Unknown plugin selection: {marketplace}/{name}")
        if not record.path:
            raise ValueError(f"Plugin is not copyable from a local path: {marketplace}/{name}")
        target = project_root / "plugins" / name
        copytree(record.path, target)
        for missing in ps1_without_sh(target):
            warnings.append(f"plugin {name}: {missing} has no matching .sh")
        marketplace_path = ensure_marketplace(project_root)
        upsert_plugin_entry(marketplace_path, name, record.category)
        installed_plugins.append(str(target))

    return {
        "project_root": str(project_root),
        "installed_skills": installed_skills,
        "installed_plugins": installed_plugins,
        "marketplace": str(marketplace_path) if marketplace_path else "",
        "next_step": f"codex plugin marketplace add {project_root}" if installed_plugins else "",
        "warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Project-local Codex skill/plugin setup.")
    sub = parser.add_subparsers(dest="command", required=True)

    inv = sub.add_parser("inventory", help="List global skills and plugins as editable JSON.")
    inv.add_argument("--include-system", action="store_true")

    ins = sub.add_parser("install", help="Install selected resources into a project.")
    ins.add_argument("--selection", required=True, type=Path)
    ins.add_argument("--project-root", default=".", type=Path)

    args = parser.parse_args()

    if args.command == "inventory":
        print(json.dumps(inventory(include_system=args.include_system), indent=2, ensure_ascii=False))
        return 0

    if args.command == "install":
        result = install(args.selection.resolve(), args.project_root.resolve())
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
