param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$WindowName = "codex",
    [string]$StatePath = "$env:USERPROFILE\.codex-terminal\neovim-session-state.json"
)

$ErrorActionPreference = "Stop"

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return [pscustomobject]@{ windowName = $WindowName; sessions = @() }
    }
    $raw = [System.IO.File]::ReadAllText($StatePath)
    $raw = $raw.TrimStart([char]0xFEFF)
    $mojibakeBom = ([string][char]0x00EF) + ([string][char]0x00BB) + ([string][char]0x00BF)
    if ($raw.StartsWith($mojibakeBom)) {
        $raw = $raw.Substring(3)
    }
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{ windowName = $WindowName; sessions = @() }
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

function Next-TabIndex($items) {
    $next = 0
    foreach ($item in @($items)) {
        if ($null -ne $item.tabIndex -and [int]$item.tabIndex -ge $next) {
            $next = [int]$item.tabIndex + 1
        }
    }
    return $next
}

$cwd = (Resolve-Path -LiteralPath $Path).Path
$state = Read-State
$sessions = @($state.sessions)
$existing = $sessions | Where-Object { Same-Path $_.cwd $cwd } | Select-Object -First 1
if ($existing) {
    try {
        if ($existing.windowName -and $null -ne $existing.tabIndex) {
            wt.exe -w $existing.windowName focus-tab -t ([string]$existing.tabIndex) | Out-Null
            $existing.lastUsedAt = (Get-Date).ToUniversalTime().ToString("o")
            Save-State $state
            $resultPid = 0
            if ($null -ne $existing.pid) {
                $resultPid = [int]$existing.pid
            }
            [pscustomobject]@{
                cwd = $cwd; pid = $resultPid; windowName = $existing.windowName
                tabTitle = $existing.tabTitle; tabIndex = [int]$existing.tabIndex
                action = "focused"; statePath = $StatePath
            } | ConvertTo-Json -Depth 4
            exit 0
        }
    } catch {
        $sessions = $sessions | Where-Object { -not (Same-Path $_.cwd $cwd) }
        $state.sessions = @($sessions)
        Save-State $state
    }
}

$tabTitle = "nvim:" + (Split-Path -Leaf $cwd)
$tabIndex = Next-TabIndex $sessions
wt.exe -w $WindowName new-tab --title $tabTitle -d $cwd powershell -NoExit -Command "nvim ." | Out-Null
Start-Sleep -Milliseconds 700
$nvimProcess = Get-Process | Where-Object { $_.ProcessName -like "*nvim*" } | Sort-Object StartTime -Descending | Select-Object -First 1
if (-not $nvimProcess) {
    throw "Nao foi possivel localizar processo nvim apos abrir a aba."
}
$nvimPid = [int]$nvimProcess.Id
$record = [pscustomobject]@{
    cwd = $cwd; pid = $nvimPid; windowName = $WindowName; tabTitle = $tabTitle; tabIndex = $tabIndex
    createdAt = (Get-Date).ToUniversalTime().ToString("o")
    lastUsedAt = (Get-Date).ToUniversalTime().ToString("o")
}
$state.windowName = $WindowName
$state.sessions = @($sessions) + $record
Save-State $state
$record | Add-Member -NotePropertyName action -NotePropertyValue "opened"
$record | Add-Member -NotePropertyName statePath -NotePropertyValue $StatePath
$record | ConvertTo-Json -Depth 4
