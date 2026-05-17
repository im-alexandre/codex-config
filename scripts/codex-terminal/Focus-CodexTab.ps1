param(
  [string]$SessionId,
  [string]$ProjectName,
  [string]$WindowName = "codex",
  [switch]$OpenNewTabIfStale
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "CodexTerminal.Common.ps1")

function Invoke-CodexTerminalForeground {
  $source = @(
    "using System;",
    "using System.Runtime.InteropServices;",
    "public static class CodexTerminalWin32 {",
    "  [DllImport(""user32.dll"")]",
    "  public static extern bool SetForegroundWindow(IntPtr hWnd);",
    "  [DllImport(""user32.dll"")]",
    "  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);",
    "}"
  ) -join [Environment]::NewLine

  if (-not ([System.Management.Automation.PSTypeName]"CodexTerminalWin32").Type) {
    Add-Type -TypeDefinition $source
  }

  $processes = Get-Process -Name WindowsTerminal -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 }
  foreach ($process in $processes) {
    [CodexTerminalWin32]::ShowWindowAsync($process.MainWindowHandle, 9) | Out-Null
    [CodexTerminalWin32]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
  }
}

if (-not $SessionId -and -not $ProjectName) {
  throw "Informe -SessionId ou -ProjectName."
}

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue
if (-not $wt) {
  throw "wt.exe nao encontrado no PATH."
}

$session = Find-CodexTerminalSession -SessionId $SessionId -ProjectName $ProjectName -WindowName $WindowName
if (-not $session) {
  Start-Process -FilePath $wt.Source -ArgumentList @("-w", $WindowName, "focus-tab", "-t", "0") -WindowStyle Hidden -Wait | Out-Null
  Invoke-CodexTerminalForeground
  [pscustomobject]@{
    focused = $false
    fallback = "window"
    reason = "Sessao nao encontrada no estado local."
  } | ConvertTo-Json -Compress
  exit 0
}

$tabIndex = [int]$session.tabIndex
$focusProcess = Start-Process -FilePath $wt.Source -ArgumentList @("-w", $session.windowName, "focus-tab", "-t", ([string]$tabIndex)) -WindowStyle Hidden -Wait -PassThru
Invoke-CodexTerminalForeground

if ($focusProcess.ExitCode -eq 0) {
  Touch-CodexTerminalSession -SessionId $session.sessionId -WindowName $session.windowName
  [pscustomobject]@{
    focused = $true
    sessionId = $session.sessionId
    projectName = $session.projectName
    windowName = $session.windowName
    tabIndex = $tabIndex
  } | ConvertTo-Json -Compress
  exit 0
}

Start-Process -FilePath $wt.Source -ArgumentList @("-w", $session.windowName, "focus-tab", "-t", "0") -WindowStyle Hidden -Wait | Out-Null
Invoke-CodexTerminalForeground

if ($OpenNewTabIfStale -and $session.cwd -and (Test-Path -LiteralPath $session.cwd)) {
  & (Join-Path $PSScriptRoot "Start-CodexTab.ps1") -Path $session.cwd -WindowName $session.windowName | Out-Null
  [pscustomobject]@{
    focused = $false
    fallback = "new-tab"
    reason = "Indice da aba falhou; nova aba aberta para o projeto."
  } | ConvertTo-Json -Compress
  exit 0
}

[pscustomobject]@{
  focused = $false
  fallback = "window"
  reason = "Indice da aba pode estar stale; janela codex foi focada."
  sessionId = $session.sessionId
  projectName = $session.projectName
  tabIndex = $tabIndex
} | ConvertTo-Json -Compress
