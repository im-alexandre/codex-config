param(
    [Parameter(Mandatory = $true)]
    [string]$SessionId,
    [string]$StatePath = "$env:USERPROFILE\.codex-terminal\codex-session-state.json"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $StatePath)) {
    [pscustomobject]@{ sessionId = $SessionId; action = "missing-state" } | ConvertTo-Json -Compress
    exit 0
}
function Read-State {
    $raw = [System.IO.File]::ReadAllText($StatePath)
    $raw = $raw.TrimStart([char]0xFEFF)
    $mojibakeBom = ([string][char]0x00EF) + ([string][char]0x00BB) + ([string][char]0x00BF)
    if ($raw.StartsWith($mojibakeBom)) {
        $raw = $raw.Substring(3)
    }
    return $raw | ConvertFrom-Json
}

function Save-State($state) {
    $json = $state | ConvertTo-Json -Depth 8
    $encoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($StatePath, $json, $encoding)
}

$state = Read-State
$sessions = @($state.sessions)
$session = $sessions | Where-Object { $_.sessionId -eq $SessionId } | Select-Object -First 1
if ($session -and $session.windowName -and $null -ne $session.tabIndex) {
    wt.exe -w $session.windowName focus-tab -t ([string]$session.tabIndex) close-tab | Out-Null
}
$state.sessions = $sessions | Where-Object { $_.sessionId -ne $SessionId }
Save-State $state
[pscustomobject]@{ sessionId = $SessionId; action = "closed" } | ConvertTo-Json -Compress
