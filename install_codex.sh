#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(realpath "$script_dir")"
codex_home="$(realpath "${HOME}/.codex")"

if [[ "${repo_root}" != "${codex_home}" ]]; then
  printf 'Este repositorio deve ser usado diretamente como CODEX_HOME: %s\n' "$codex_home" >&2
  exit 1
fi

config_path="${repo_root}/config.toml"
if [[ ! -f "$config_path" ]]; then
  printf 'config.toml nao encontrado: %s\n' "$config_path" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  python3 - "$config_path" <<'PY'
import pathlib
import sys
import tomllib

tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
print("config.toml ok")
PY
fi

printf 'CODEX_HOME versionado pronto: %s\n' "$repo_root"
