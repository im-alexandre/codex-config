#!/usr/bin/env bash
set -euo pipefail

source_skill_path="${HOME}/.codex/skills/docx-utils"
target_skill_path="${HOME}/.codex/skills/docx-utils"
skip_tests=0
skip_skill_validation=0
clean=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-skill-path)
      source_skill_path="$2"
      shift 2
      ;;
    --target-skill-path)
      target_skill_path="$2"
      shift 2
      ;;
    --skip-tests)
      skip_tests=1
      shift
      ;;
    --skip-skill-validation)
      skip_skill_validation=1
      shift
      ;;
    --clean)
      clean=1
      shift
      ;;
    *)
      printf 'Argumento desconhecido: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

status() {
  printf '[docx-utils-global] %s\n' "$1"
}

if [[ ! -d "$source_skill_path" ]]; then
  printf 'Skill de origem nao encontrada: %s\n' "$source_skill_path" >&2
  exit 1
fi

mkdir -p "$(dirname "$target_skill_path")"

if [[ "$clean" -eq 1 && -e "$target_skill_path" ]]; then
  rm -rf "$target_skill_path"
fi

if [[ -e "$target_skill_path" ]]; then
  if [[ "$(realpath "$source_skill_path")" != "$(realpath "$target_skill_path")" ]]; then
    cp -a "${source_skill_path}/." "$target_skill_path/"
  fi
else
  cp -a "$source_skill_path" "$target_skill_path"
fi

status "Skill copiada para $target_skill_path"

installer="${target_skill_path}/scripts/install-docx-utils.sh"
if [[ ! -x "$installer" ]]; then
  printf 'Instalador nao encontrado no destino: %s\n' "$installer" >&2
  exit 1
fi

args=()
[[ "$skip_tests" -eq 1 ]] && args+=(--skip-tests)
[[ "$skip_skill_validation" -eq 1 ]] && args+=(--skip-skill-validation)

"$installer" "${args[@]}"
status 'Instalacao global concluida com sucesso.'
