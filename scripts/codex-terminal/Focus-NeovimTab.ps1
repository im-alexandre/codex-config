param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$StatePath = "$env:USERPROFILE\.codex-terminal\neovim-session-state.json"
)

$ErrorActionPreference = "Stop"

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return $null
    }
    $raw = [System.IO.File]::ReadAllText($StatePath)
    $raw = $raw.TrimStart([char]0xFEFF)
    $mojibakeBom = ([string][char]0x00EF) + ([string][char]0x00BB) + ([string][char]0x00BF)
    if ($raw.StartsWith($mojibakeBom)) {
        $raw = $raw.Substring(3)
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    return $raw | ConvertFrom-Json
}

function Save-State($state) {
    $dir = Split-Path -Parent $StatePath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = $state | ConvertTo-Json -Depth 8
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($StatePath, $json, $encoding)
}

function Same-Path($left, $right) {
    return [string]::Equals([string]$left, [string]$right, [System.StringComparison]::OrdinalIgnoreCase)
}

$cwd = (Resolve-Path -LiteralPath $Path).Path
$state = Read-State
if (-not $state) {
    [pscustomobject]@{ focused = $false; staleRemoved = $false; cwd = $cwd; statePath = $StatePath } | ConvertTo-Json
    exit 0
}
$sessions = @($state.sessions)
$existing = $sessions | Where-Object { Same-Path $_.cwd $cwd } | Select-Object -First 1
if (-not $existing) {
    [pscustomobject]@{ focused = $false; staleRemoved = $false; cwd = $cwd; statePath = $StatePath } | ConvertTo-Json
    exit 0
}
try {
    wt.exe -w $existing.windowName focus-tab -t ([string]$existing.tabIndex) | Out-Null
    $existing.lastUsedAt = (Get-Date).ToUniversalTime().ToString("o")
    Save-State $state
    $resultPid = 0
    if ($null -ne $existing.pid) {
        $resultPid = [int]$existing.pid
    }
    [pscustomobject]@{ focused = $true; staleRemoved = $false; cwd = $cwd; pid = $resultPid; statePath = $StatePath } | ConvertTo-Json
} catch {
    $state.sessions = $sessions | Where-Object { -not (Same-Path $_.cwd $cwd) }
    Save-State $state
    [pscustomobject]@{ focused = $false; staleRemoved = $true; cwd = $cwd; statePath = $StatePath } | ConvertTo-Json
}
