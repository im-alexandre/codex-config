#!/usr/bin/env bash
set -euo pipefail

mcps=()
skills=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mcp|--mcps|-m)
      shift
      while [[ $# -gt 0 && "$1" != --* && "$1" != -* ]]; do
        mcps+=("$1")
        shift
      done
      ;;
    --skill|--skills|-s)
      shift
      while [[ $# -gt 0 && "$1" != --* && "$1" != -* ]]; do
        skills+=("$1")
        shift
      done
      ;;
    *)
      printf 'Argumento desconhecido: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

python3 - "${HOME}/.codex" "${mcps[*]}" "${skills[*]}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
mcps = [x for x in sys.argv[2].split() if x]
skills = [x for x in sys.argv[3].split() if x]

services = set()
profiles = set()

def add_entry(entry):
    if not isinstance(entry, dict):
        return
    for service in entry.get("services") or []:
        if str(service).strip():
            services.add(str(service))
    for profile in entry.get("profiles") or []:
        if str(profile).strip():
            profiles.add(str(profile))

mcp_path = root / "presets" / "mcp-services.json"
if mcp_path.exists() and mcps:
    raw = mcp_path.read_text(encoding="utf-8").strip()
    data = json.loads(raw) if raw else {}
    for name in mcps:
        if name in data:
            add_entry(data[name])

skill_path = root / "presets" / "skills-services.json"
if skill_path.exists() and skills:
    raw = skill_path.read_text(encoding="utf-8").strip()
    data = json.loads(raw) if raw else {}
    for name in skills:
        if name in data:
            add_entry(data[name])

print(json.dumps({"services": sorted(services), "profiles": sorted(profiles)}, ensure_ascii=False))
PY
