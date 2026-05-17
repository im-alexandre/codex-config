$ErrorActionPreference = "Stop"

$script:CodexTerminalStateDir = Join-Path $env:USERPROFILE ".codex-terminal"
$script:CodexTerminalStatePath = Join-Path $script:CodexTerminalStateDir "codex-session-state.json"

function ConvertTo-CodexSafeName {
  param(
    [string]$Name,
    [string]$Fallback = "codex"
  )

  $safe = ($Name -replace '[\p{C}\\/:*?"<>|]', "-").Trim()
  $safe = ($safe -replace '\s+', "-").Trim("-")
  if (-not $safe) {
    return $Fallback
  }

  return $safe
}

function ConvertTo-PowerShellSingleQuotedLiteral {
  param([string]$Value)

  return "'" + ($Value -replace "'", "''") + "'"
}

function Get-CodexProjectInfo {
  param([string]$Path = (Get-Location).Path)

  $cwd = $Path
  try {
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $cwd = $resolved.ProviderPath
  } catch {
    $cwd = [System.IO.Path]::GetFullPath($Path)
  }

  $gitRoot = $null
  if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitOutput = & git -C $cwd rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitOutput) {
      $gitRoot = [System.IO.Path]::GetFullPath(([string]$gitOutput).Trim())
    }
  }

  $projectSource = if ($gitRoot) { $gitRoot } else { $cwd }
  $projectName = Split-Path -Leaf $projectSource
  if (-not $projectName) {
    $projectName = "codex"
  }

  $safeProjectName = ConvertTo-CodexSafeName -Name $projectName
  [pscustomobject]@{
    Cwd = $cwd
    GitRoot = $gitRoot
    ProjectName = $safeProjectName
    ProjectKey = $safeProjectName.ToLowerInvariant()
  }
}

function New-CodexTerminalSessionId {
  return "local-" + ([guid]::NewGuid().ToString("N"))
}

function Read-CodexTerminalState {
  param([string]$WindowName = "codex")

  if (-not (Test-Path -LiteralPath $script:CodexTerminalStatePath)) {
    return [pscustomobject]@{
      windowName = $WindowName
      sessions = @()
    }
  }

  try {
    $state = Get-Content -LiteralPath $script:CodexTerminalStatePath -Raw | ConvertFrom-Json
  } catch {
    $state = [pscustomobject]@{
      windowName = $WindowName
      sessions = @()
    }
  }

  if (-not $state.PSObject.Properties["windowName"] -or -not $state.windowName) {
    $state | Add-Member -NotePropertyName windowName -NotePropertyValue $WindowName -Force
  }

  if (-not $state.PSObject.Properties["sessions"] -or -not $state.sessions) {
    $state | Add-Member -NotePropertyName sessions -NotePropertyValue @() -Force
  }

  $state.sessions = @($state.sessions)
  return $state
}

function Save-CodexTerminalState {
  param([Parameter(Mandatory)]$State)

  New-Item -ItemType Directory -Force -Path $script:CodexTerminalStateDir | Out-Null
  $tempPath = $script:CodexTerminalStatePath + ".tmp"
  $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tempPath -Encoding utf8
  Move-Item -LiteralPath $tempPath -Destination $script:CodexTerminalStatePath -Force
}

function Remove-CodexTerminalStaleSessions {
  param(
    [Parameter(Mandatory)]$State,
    [int]$MaxAgeDays = 14
  )

  $cutoff = (Get-Date).AddDays(-1 * $MaxAgeDays)
  $kept = @()
  foreach ($session in @($State.sessions)) {
    [datetime]$lastUsed = [datetime]::MinValue
    if ($session.lastUsedAt) {
      [datetime]::TryParse([string]$session.lastUsedAt, [ref]$lastUsed) | Out-Null
    }

    if ($lastUsed -eq [datetime]::MinValue -or $lastUsed -ge $cutoff) {
      $kept += $session
    }
  }

  $State.sessions = $kept
  return $State
}

function Get-CodexTerminalNextTabIndex {
  param(
    [Parameter(Mandatory)]$State,
    [string]$WindowName = "codex"
  )

  $indexes = @($State.sessions | Where-Object { $_.windowName -eq $WindowName -and $_.tabIndex -ne $null } | ForEach-Object { [int]$_.tabIndex })
  if (-not $indexes -or $indexes.Count -eq 0) {
    return 0
  }

  return (($indexes | Measure-Object -Maximum).Maximum + 1)
}

function Test-CodexTerminalWindowOpen {
  param(
    [string]$WindowName = "codex"
  )

  $prefix = "codex:${WindowName}:"
  $allWindows = @(Get-Process -Name WindowsTerminal -ErrorAction SilentlyContinue)
  if ($allWindows.Count -eq 0) {
    return $false
  }

  $processes = @($allWindows | Where-Object { $_.MainWindowTitle -like "$prefix*" })
  if ($processes.Count -gt 0) {
    return $true
  }

  return $true
}

function Reset-CodexTerminalWindowState {
  param(
    [Parameter(Mandatory)]$State,
    [string]$WindowName = "codex"
  )

  $State.sessions = @($State.sessions | Where-Object { $_.windowName -ne $WindowName })
  Save-CodexTerminalState -State $State
  return $State
}

function Register-CodexTerminalSession {
  param(
    [string]$SessionId,
    [Parameter(Mandatory)]$ProjectInfo,
    [string]$WindowName = "codex",
    [string]$TabTitle,
    [Nullable[int]]$TabIndex,
    [string]$LauncherSessionId
  )

  if (-not $SessionId) {
    $SessionId = New-CodexTerminalSessionId
  }

  if (-not $TabTitle) {
    $TabTitle = $ProjectInfo.ProjectName
  }

  $state = Read-CodexTerminalState -WindowName $WindowName
  $state = Remove-CodexTerminalStaleSessions -State $state
  $now = (Get-Date).ToString("o")
  $sessions = @($state.sessions)
  $existing = $sessions | Where-Object { $_.sessionId -eq $SessionId } | Select-Object -First 1
  if (-not $existing -and $LauncherSessionId) {
    $existing = $sessions | Where-Object { $_.launcherSessionId -eq $LauncherSessionId } | Select-Object -First 1
  }

  if (-not $TabIndex.HasValue) {
    $envIndex = $env:CODEX_TERMINAL_TAB_INDEX
    if ($envIndex -match '^\d+$') {
      $TabIndex = [int]$envIndex
    } else {
      $TabIndex = Get-CodexTerminalNextTabIndex -State $state -WindowName $WindowName
    }
  }

  if ($existing) {
    $existing.sessionId = $SessionId
    $existing.projectName = $ProjectInfo.ProjectName
    $existing.projectKey = $ProjectInfo.ProjectKey
    $existing.cwd = $ProjectInfo.Cwd
    $existing.gitRoot = $ProjectInfo.GitRoot
    $existing.windowName = $WindowName
    $existing.tabTitle = $TabTitle
    $existing.tabIndex = [int]$TabIndex
    $existing.lastUsedAt = $now
    if ($LauncherSessionId) {
      $existing.launcherSessionId = $LauncherSessionId
    }
  } else {
    $sessions += [pscustomobject]@{
      sessionId = $SessionId
      launcherSessionId = $LauncherSessionId
      projectName = $ProjectInfo.ProjectName
      projectKey = $ProjectInfo.ProjectKey
      cwd = $ProjectInfo.Cwd
      gitRoot = $ProjectInfo.GitRoot
      windowName = $WindowName
      tabTitle = $TabTitle
      tabIndex = [int]$TabIndex
      createdAt = $now
      lastUsedAt = $now
    }
  }

  $state.windowName = $WindowName
  $state.sessions = @($sessions)
  Save-CodexTerminalState -State $state
  return ($state.sessions | Where-Object { $_.sessionId -eq $SessionId } | Select-Object -First 1)
}

function Find-CodexTerminalSession {
  param(
    [string]$SessionId,
    [string]$ProjectName,
    [string]$WindowName = "codex"
  )

  $state = Read-CodexTerminalState -WindowName $WindowName
  $sessions = @($state.sessions | Where-Object { $_.windowName -eq $WindowName })

  if ($SessionId) {
    $match = $sessions | Where-Object { $_.sessionId -eq $SessionId -or $_.launcherSessionId -eq $SessionId } | Select-Object -First 1
    if ($match) {
      return $match
    }
  }

  if ($ProjectName) {
    $projectKey = (ConvertTo-CodexSafeName -Name $ProjectName).ToLowerInvariant()
    return $sessions | Where-Object { $_.projectKey -eq $projectKey -or $_.projectName -eq $ProjectName } | Sort-Object lastUsedAt -Descending | Select-Object -First 1
  }

  return $null
}

function Touch-CodexTerminalSession {
  param(
    [Parameter(Mandatory)][string]$SessionId,
    [string]$WindowName = "codex"
  )

  $state = Read-CodexTerminalState -WindowName $WindowName
  foreach ($session in @($state.sessions)) {
    if ($session.sessionId -eq $SessionId -or $session.launcherSessionId -eq $SessionId) {
      $session.lastUsedAt = (Get-Date).ToString("o")
    }
  }

  Save-CodexTerminalState -State $state
}
