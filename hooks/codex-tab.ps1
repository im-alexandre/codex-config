$ErrorActionPreference = "Stop"

$raw = [Console]::In.ReadToEnd()

try {
  $event = $raw | ConvertFrom-Json
} catch {
  $event = $null
}

function Write-HookJson {
  param(
    [bool]$Continue,
    [string]$Message = ""
  )

  $payload = @{
    continue = $Continue
  }

  if ($Message) {
    $payload.systemMessage = $Message
    if (-not $Continue) {
      $payload.stopReason = $Message
    }
  }

  $payload | ConvertTo-Json -Compress
}

if (-not $event) {
  Write-HookJson -Continue $true -Message "codex-tab: payload do hook invalido; mantendo a sessao atual."
  exit 0
}

$sessionId = [string]$event.session_id
$cwd = [string]$event.cwd

if (-not $cwd) {
  $cwd = (Get-Location).Path
}

if (-not $sessionId) {
  Write-HookJson -Continue $true -Message "codex-tab: session_id ausente; mantendo a sessao atual."
  exit 0
}

try {
  $scriptRoot = Join-Path $env:USERPROFILE ".codex\scripts\codex-terminal"
  . (Join-Path $scriptRoot "CodexTerminal.Common.ps1")

  $projectInfo = Get-CodexProjectInfo -Path $cwd
  $windowName = if ($env:CODEX_TERMINAL_WINDOW_NAME) { $env:CODEX_TERMINAL_WINDOW_NAME } else { "codex" }
  $tabTitle = if ($env:CODEX_TERMINAL_TAB_TITLE) { $env:CODEX_TERMINAL_TAB_TITLE } else { $projectInfo.ProjectName }
  $launcherSessionId = $env:CODEX_TERMINAL_LAUNCH_ID
  $tabIndex = $null

  if ($env:CODEX_TERMINAL_TAB_INDEX -match '^\d+$') {
    $tabIndex = [int]$env:CODEX_TERMINAL_TAB_INDEX
  }

  Register-CodexTerminalSession -SessionId $sessionId -ProjectInfo $projectInfo -WindowName $windowName -TabTitle $tabTitle -TabIndex $tabIndex -LauncherSessionId $launcherSessionId | Out-Null
} catch {
  Write-HookJson -Continue $true -Message "codex-tab: falha ao registrar sessao; mantendo a sessao atual."
  exit 0
}

Write-HookJson -Continue $true
