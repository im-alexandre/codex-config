$ErrorActionPreference = "SilentlyContinue"

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$raw = [Console]::In.ReadToEnd()

try {
  $event = $raw | ConvertFrom-Json
} catch {
  $event = $null
}

$hook = $event.hook_event_name
$model = $event.model
$cwd = $event.cwd
$msg = $event.last_assistant_message
$sessionId = [string]$event.session_id

if (-not $cwd) {
  $cwd = (Get-Location).Path
}

$project = Split-Path $cwd -Leaf

switch ($hook) {
  "Stop" {
    $title = "Codex CLI terminou"
    $body = if ($msg) {
      "$project — $($msg.Substring(0, [Math]::Min(180, $msg.Length)))"
    } else {
      "$project — resposta pronta"
    }
  }

  "PermissionRequest" {
    $title = "Codex CLI precisa de aprovação"
    $body = "$project — aguardando sua confirmação"
  }

  default {
    $title = "Codex CLI"
    $body = "$project — evento: $hook"
  }
}

Import-Module BurntToast

$focusScript = Join-Path $env:USERPROFILE ".codex\scripts\codex-terminal\Focus-CodexTab.ps1"
$commonScript = Join-Path $env:USERPROFILE ".codex\scripts\codex-terminal\CodexTerminal.Common.ps1"

if ($sessionId -and (Test-Path -LiteralPath $commonScript)) {
  try {
    . $commonScript
    $projectInfo = Get-CodexProjectInfo -Path $cwd
    $windowName = if ($env:CODEX_TERMINAL_WINDOW_NAME) { $env:CODEX_TERMINAL_WINDOW_NAME } else { "codex" }
    $tabTitle = if ($env:CODEX_TERMINAL_TAB_TITLE) { $env:CODEX_TERMINAL_TAB_TITLE } else { "codex:${windowName}:$($projectInfo.ProjectName)" }
    $launcherSessionId = $env:CODEX_TERMINAL_LAUNCH_ID
    $tabIndex = $null

    if ($env:CODEX_TERMINAL_TAB_INDEX -match '^\d+$') {
      $tabIndex = [int]$env:CODEX_TERMINAL_TAB_INDEX
    }

    Register-CodexTerminalSession -SessionId $sessionId -ProjectInfo $projectInfo -WindowName $windowName -TabTitle $tabTitle -TabIndex $tabIndex -LauncherSessionId $launcherSessionId | Out-Null
  } catch {
  }
}

if ($sessionId -and (Test-Path -LiteralPath $focusScript)) {
  $actionDir = Join-Path $env:USERPROFILE ".codex-terminal\notification-actions"
  New-Item -ItemType Directory -Force -Path $actionDir | Out-Null
  $safeFileName = ($sessionId -replace '[^\w.-]', '_')
  $actionPath = Join-Path $actionDir "focus-$safeFileName.vbs"
  $focusScriptForVbs = $focusScript.Replace('"', '""')
  $sessionIdForVbs = $sessionId.Replace('"', '""')
  $vbsCommandLine = 'cmd = "pwsh -NoProfile -ExecutionPolicy Bypass -File " & q & "' + $focusScriptForVbs + '" & q & " -SessionId " & q & "' + $sessionIdForVbs + '" & q'
  $actionLines = @(
    'Set shell = CreateObject("WScript.Shell")',
    'q = Chr(34)',
    $vbsCommandLine,
    'shell.Run cmd, 0, False'
  )
  Set-Content -LiteralPath $actionPath -Value $actionLines -Encoding ascii

  $safeFocusScript = "'" + ($focusScript -replace "'", "''") + "'"
  $safeSessionId = "'" + ($sessionId -replace "'", "''") + "'"
  $focusCommand = "Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$safeFocusScript,'-SessionId',$safeSessionId) -WindowStyle Hidden | Out-Null"
  $focusAction = [scriptblock]::Create($focusCommand)
  $button = New-BTButton -Content "Abrir sessao" -Arguments $actionPath

  New-BurntToastNotification -Text $title, $body -ActivatedAction $focusAction -Button $button
} else {
  New-BurntToastNotification -Text $title, $body
}

@{
  continue = $true
} | ConvertTo-Json -Compress
