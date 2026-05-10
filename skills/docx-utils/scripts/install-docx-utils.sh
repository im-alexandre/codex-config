#!/usr/bin/env bash
set -euo pipefail

skip_tests=0
skip_skill_validation=0
configuration="Debug"
no_package_mutation=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)
      skip_tests=1
      shift
      ;;
    --skip-skill-validation)
      skip_skill_validation=1
      shift
      ;;
    --configuration)
      configuration="$2"
      shift 2
      ;;
    --no-package-mutation)
      no_package_mutation=1
      shift
      ;;
    *)
      printf 'Argumento desconhecido: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ "$configuration" != "Debug" && "$configuration" != "Release" ]]; then
  printf 'Configuracao invalida: %s\n' "$configuration" >&2
  exit 2
fi

status() {
  printf '[docx-utils] %s\n' "$1"
}

if ! command -v dotnet >/dev/null 2>&1; then
  printf 'SDK do .NET nao encontrado no PATH.\n' >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
skill_root="$(realpath "${script_dir}/..")"
dotnet_path="$(command -v dotnet)"
status "dotnet encontrado em $dotnet_path"

mapfile -t project_files < <(find "$skill_root" -type f -name '*.csproj' | sort)
if [[ ${#project_files[@]} -eq 0 ]]; then
  printf 'Nenhum projeto .NET encontrado em: %s\n' "$skill_root" >&2
  exit 1
fi

ensure_package_reference() {
  local project="$1"
  local package_id="$2"
  local version="$3"

  if python3 - "$project" "$package_id" <<'PY'
import sys
import xml.etree.ElementTree as ET

project, package_id = sys.argv[1], sys.argv[2]
root = ET.parse(project).getroot()
for item in root.iter():
    if item.tag.rsplit("}", 1)[-1] == "PackageReference" and item.attrib.get("Include") == package_id:
        raise SystemExit(0)
raise SystemExit(1)
PY
  then
    return 1
  fi

  if [[ "$no_package_mutation" -eq 1 ]]; then
    printf "Pacote ausente em '%s': %s\n" "$project" "$package_id" >&2
    exit 1
  fi

  dotnet add "$project" package "$package_id" --version "$version"
  return 0
}

package_changes=0
for project in "${project_files[@]}"; do
  name="$(basename "$project")"
  required=()
  case "$name" in
    ArticleDocxBuilder.csproj)
      required=(DocumentFormat.OpenXml SixLabors.ImageSharp System.IO.Packaging)
      ;;
    DocxOpenXmlTools.csproj)
      required=(DocumentFormat.OpenXml SixLabors.ImageSharp)
      ;;
    StyleXmlExporter.csproj)
      required=(DocumentFormat.OpenXml)
      ;;
  esac

  for package_id in "${required[@]}"; do
    case "$package_id" in
      DocumentFormat.OpenXml) version="3.2.0" ;;
      SixLabors.ImageSharp) version="3.1.12" ;;
      System.IO.Packaging) version="8.0.1" ;;
      *) version="" ;;
    esac
    if ensure_package_reference "$project" "$package_id" "$version"; then
      package_changes=$((package_changes + 1))
      status "Pacote adicionado em ${name}: $package_id"
    fi
  done
done

for project in "${project_files[@]}"; do
  status "restore: $(basename "$project")"
  dotnet restore "$project"
done

for project in "${project_files[@]}"; do
  status "build: $(basename "$project") [$configuration]"
  dotnet build "$project" --configuration "$configuration" --no-restore
done

tools_project="${skill_root}/src/DocxOpenXmlTools/DocxOpenXmlTools.csproj"
package_dir="${skill_root}/bin/docx-utils"
status "publish: DocxOpenXmlTools [$configuration] -> $package_dir"
dotnet publish "$tools_project" --configuration "$configuration" --no-restore --output "$package_dir"

for stale_wrapper in docx-comments.mjs docx-comments.cmd; do
  stale_path="${package_dir}/${stale_wrapper}"
  if [[ -e "$stale_path" ]]; then
    rm -f "$stale_path"
    status "wrapper obsoleto removido: $stale_wrapper"
  fi
done

test_projects_run=0
test_status="executados"
if [[ "$skip_tests" -eq 0 ]]; then
  test_projects=()
  for project in "${project_files[@]}"; do
    base="$(basename "$project" .csproj)"
    if [[ "$base" =~ (^|\.)(Tests?|Spec)$ || "$base" =~ Tests?$ || "$base" =~ Spec$ ]]; then
      test_projects+=("$project")
    fi
  done
  if [[ ${#test_projects[@]} -gt 0 ]]; then
    for project in "${test_projects[@]}"; do
      status "test: $(basename "$project") [$configuration]"
      dotnet test "$project" --configuration "$configuration" --no-build --no-restore
      test_projects_run=$((test_projects_run + 1))
    done
  else
    status 'Nenhum projeto de teste encontrado; pulando dotnet test.'
    test_status="nenhum-projeto"
  fi
else
  status 'Testes automaticos ignorados por parametro.'
  test_status="ignorado"
fi

skill_validation_status="executada"
if [[ "$skip_skill_validation" -eq 0 ]]; then
  skill_creator="${HOME}/.codex/skills/.system/skill-creator/scripts/quick_validate.py"
  if [[ -f "$skill_creator" ]]; then
    status 'Executando quick_validate.py da skill skill-creator.'
    python_bin="$(command -v python3 || command -v python || true)"
    if [[ -z "$python_bin" ]]; then
      printf 'Python nao encontrado para executar quick_validate.py.\n' >&2
      exit 1
    fi
    "$python_bin" "$skill_creator" "$skill_root"
  else
    status 'skill-creator nao encontrado; quick_validate.py ignorado.'
    skill_validation_status="skill-creator-ausente"
  fi
else
  status 'Validacao da skill ignorada por parametro.'
  skill_validation_status="ignorada"
fi

status "Resumo: projetos=${#project_files[@]}; alteracoes-de-pacote=${package_changes}; testes=${test_status}(${test_projects_run}); skill-validation=${skill_validation_status}; configuracao=${configuration}"
