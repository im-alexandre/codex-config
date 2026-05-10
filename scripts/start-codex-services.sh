#!/usr/bin/env bash
set -euo pipefail

services=()
profiles=()
compose_file="${HOME}/.codex/docker-compose.yml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service|--services|-s)
      shift
      while [[ $# -gt 0 && "$1" != --* && "$1" != -* ]]; do
        services+=("$1")
        shift
      done
      ;;
    --profile|--profiles|-p)
      shift
      while [[ $# -gt 0 && "$1" != --* && "$1" != -* ]]; do
        profiles+=("$1")
        shift
      done
      ;;
    --compose-file|-f)
      compose_file="$2"
      shift 2
      ;;
    *)
      printf 'Argumento desconhecido: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker nao encontrado no PATH.\n' >&2
  exit 1
fi

if [[ ! -f "$compose_file" ]]; then
  printf 'docker-compose.yml nao encontrado: %s\n' "$compose_file" >&2
  exit 1
fi

mapfile -t unique_services < <(printf '%s\n' "${services[@]}" | awk 'NF' | sort -u)
mapfile -t unique_profiles < <(printf '%s\n' "${profiles[@]}" | awk 'NF' | sort -u)

if [[ ${#unique_services[@]} -eq 0 ]]; then
  printf 'Nenhum servico necessario.\n'
  exit 0
fi

args=(compose -f "$compose_file")
for profile in "${unique_profiles[@]}"; do
  args+=(--profile "$profile")
done
args+=(up -d)
args+=("${unique_services[@]}")

printf '\nIniciando servicos Codex:\n'
printf -- '- %s\n' "${unique_services[@]}"

if [[ ${#unique_profiles[@]} -gt 0 ]]; then
  printf '\nProfiles:\n'
  printf -- '- %s\n' "${unique_profiles[@]}"
fi

printf '\n'
docker "${args[@]}"
