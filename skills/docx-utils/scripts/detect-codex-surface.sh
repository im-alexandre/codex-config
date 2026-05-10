#!/usr/bin/env bash
set -euo pipefail

json=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      json=1
      shift
      ;;
    *)
      printf 'Argumento desconhecido: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ "${CODEX_MANAGED_BY_NPM:-}" == "1" ]]; then
  surface="cli"
  reason="codex-npm"
else
  surface="app"
  reason="fallback"
fi

if [[ "$json" -eq 1 ]]; then
  printf '{"surface":"%s","reason":"%s"}\n' "$surface" "$reason"
else
  printf '%s\n' "$surface"
fi
