param(
  [string]$Path = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "CodexTerminal.Common.ps1")

$info = Get-CodexProjectInfo -Path $Path
[pscustomobject]@{
  projectName = $info.ProjectName
  projectKey = $info.ProjectKey
  cwd = $info.Cwd
  gitRoot = $info.GitRoot
} | ConvertTo-Json -Depth 3
