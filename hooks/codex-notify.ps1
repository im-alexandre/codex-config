$ErrorActionPreference = "Stop"

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8NoBom
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

$logDir = Join-Path $env:USERPROFILE ".codex\logs"
$logPath = Join-Path $logDir "codex-notify.log"

function Write-NotifyLog {
  param(
    [string]$Message
  )

  try {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message" -Encoding utf8
  } catch {
    # O hook de notificação não deve bloquear o Codex por falha de log.
  }
}

function Write-HookJson {
  @{
    continue = $true
  } | ConvertTo-Json -Compress
}

$raw = [Console]::In.ReadToEnd()
$event = $null

try {
  if ($raw.Trim()) {
    $event = $raw | ConvertFrom-Json -ErrorAction Stop
  }
} catch {
  Write-NotifyLog "payload invalido: $($_.Exception.Message); raw=$raw"
}

try {
  $hook = [string]$event.hook_event_name
  if (-not $hook) {
    $hook = [string]$event.hook
  }

  $cwd = [string]$event.cwd
  $msg = [string]$event.last_assistant_message
  $sessionId = [string]$event.session_id

  if (-not $cwd) {
    $cwd = (Get-Location).Path
  }

  $project = Split-Path $cwd -Leaf
  if (-not $project) {
    $project = $cwd
  }

  switch ($hook) {
    "Stop" {
      $title = "Codex CLI terminou"
      $body = if ($msg) {
        "$project - $($msg.Substring(0, [Math]::Min(180, $msg.Length)))"
      } else {
        "$project - resposta pronta"
      }
    }

    "PermissionRequest" {
      $title = "Codex CLI precisa de aprovacao"
      $body = "$project - aguardando sua confirmacao"
    }

    default {
      $title = "Codex CLI"
      $body = "$project - evento: $hook"
    }
  }

  Write-NotifyLog "inicio hook=$hook session=$sessionId cwd=$cwd"

  Import-Module BurntToast -ErrorAction Stop

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
      Write-NotifyLog "sessao registrada session=$sessionId title=$tabTitle"
    } catch {
      Write-NotifyLog "falha ao registrar sessao session=${sessionId}: $($_.Exception.Message)"
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
    $button = New-BTButton -Content "Abrir sessao" -Arguments $actionPath -ActivationType Protocol

    New-BurntToastNotification -Text $title, $body -ActivatedAction $focusAction -Button $button -UniqueIdentifier $sessionId
    Write-NotifyLog "toast enviado com acao session=$sessionId action=$actionPath"
  } else {
    New-BurntToastNotification -Text $title, $body
    Write-NotifyLog "toast enviado sem acao session=$sessionId focusScript=$focusScript"
  }
} catch {
  Write-NotifyLog "falha no hook de notificacao: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
}

Write-HookJson
