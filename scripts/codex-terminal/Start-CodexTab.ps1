param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$CodexArgs,
  [string]$Path = (Get-Location).Path,
  [string]$WindowName = "codex",
  [string]$SessionId,
  [switch]$Resume
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "CodexTerminal.Common.ps1")

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue
if (-not $wt) {
  throw "wt.exe nao encontrado no PATH."
}

$projectInfo = Get-CodexProjectInfo -Path $Path
$state = Read-CodexTerminalState -WindowName $WindowName
$state = Remove-CodexTerminalStaleSessions -State $state

$knownWindowSessions = @($state.sessions | Where-Object { $_.windowName -eq $WindowName })
if ($knownWindowSessions.Count -gt 0 -and -not (Test-CodexTerminalWindowOpen -WindowName $WindowName)) {
  $state = Reset-CodexTerminalWindowState -State $state -WindowName $WindowName
}

$tabIndex = Get-CodexTerminalNextTabIndex -State $state -WindowName $WindowName
$launcherSessionId = New-CodexTerminalSessionId
$effectiveSessionId = if ($SessionId) { $SessionId } else { $launcherSessionId }
$tabTitle = "codex:${WindowName}:$($projectInfo.ProjectName)"

Register-CodexTerminalSession -SessionId $effectiveSessionId -ProjectInfo $projectInfo -WindowName $WindowName -TabTitle $tabTitle -TabIndex $tabIndex -LauncherSessionId $launcherSessionId | Out-Null

$titleLiteral = ConvertTo-PowerShellSingleQuotedLiteral -Value $tabTitle
$windowLiteral = ConvertTo-PowerShellSingleQuotedLiteral -Value $WindowName
$sessionLiteral = ConvertTo-PowerShellSingleQuotedLiteral -Value $effectiveSessionId
$launcherLiteral = ConvertTo-PowerShellSingleQuotedLiteral -Value $launcherSessionId
$tabIndexLiteral = ConvertTo-PowerShellSingleQuotedLiteral -Value ([string]$tabIndex)
$profileHelpersDir = Join-Path (Split-Path -Parent $PROFILE) "helpers"
$documentsDir = Split-Path -Parent (Split-Path -Parent $PROFILE)
$closeTabCandidates = @(
  (Join-Path $profileHelpersDir "codex-close-tab.ps1"),
  (Join-Path $documentsDir "PowerShell\helpers\codex-close-tab.ps1"),
  (Join-Path $documentsDir "WindowsPowerShell\helpers\codex-close-tab.ps1")
)
$closeTabScript = $closeTabCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $closeTabScript) {
  throw "Script de encerramento da aba nao encontrado. Candidatos: $($closeTabCandidates -join '; ')"
}

$closeTabScriptLiteral = ConvertTo-PowerShellSingleQuotedLiteral -Value $closeTabScript

$commandParts = @(
  "`$env:CODEX_TAB_MANAGED = '1'",
  "`$env:CODEX_TERMINAL_WINDOW_NAME = $windowLiteral",
  "`$env:CODEX_TERMINAL_TAB_TITLE = $titleLiteral",
  "`$env:CODEX_TERMINAL_SESSION_ID = $sessionLiteral",
  "`$env:CODEX_TERMINAL_LAUNCH_ID = $launcherLiteral",
  "`$env:CODEX_TERMINAL_TAB_INDEX = $tabIndexLiteral",
  "[Console]::Title = $titleLiteral"
)

if ($Resume -and $SessionId) {
  $resumeLiteral = ConvertTo-PowerShellSingleQuotedLiteral -Value $SessionId
  $commandParts += "& $closeTabScriptLiteral -Resume -SessionId $resumeLiteral"
} else {
  $codexCommand = "& $closeTabScriptLiteral"
  foreach ($arg in @($CodexArgs)) {
    $codexCommand += " " + (ConvertTo-PowerShellSingleQuotedLiteral -Value $arg)
  }

  $commandParts += $codexCommand
}

$launchCommand = $commandParts -join "; "
$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launchCommand))

$wtArgs = @(
  "-w", $WindowName,
  "new-tab",
  "--title", $tabTitle,
  "-d", $projectInfo.Cwd,
  "pwsh",
  "-NoLogo",
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-EncodedCommand", $encodedCommand
)

Start-Process -FilePath $wt.Source -ArgumentList $wtArgs | Out-Null

[pscustomobject]@{
  sessionId = $effectiveSessionId
  launcherSessionId = $launcherSessionId
  projectName = $projectInfo.ProjectName
  cwd = $projectInfo.Cwd
  gitRoot = $projectInfo.GitRoot
  windowName = $WindowName
  tabTitle = $tabTitle
  tabIndex = $tabIndex
  statePath = $script:CodexTerminalStatePath
} | ConvertTo-Json -Depth 4
