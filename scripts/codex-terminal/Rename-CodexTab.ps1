param(
    [Parameter(Mandatory = $true)]
    [string]$SessionId,
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [string]$StatePath = "$env:USERPROFILE\.codex-terminal\codex-session-state.json"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $StatePath)) {
    throw "Estado de sessões não encontrado: $StatePath"
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
if (-not $session) {
    throw "Sessão não encontrada: $SessionId"
}
$session.friendlyName = $Title
$session.tabTitle = $Title
if ($session.windowName -and $null -ne $session.tabIndex) {
    wt.exe -w $session.windowName focus-tab -t ([string]$session.tabIndex) rename-tab $Title | Out-Null
}
$state.sessions = $sessions
Save-State $state
[pscustomobject]@{ sessionId = $SessionId; action = "renamed"; title = $Title } | ConvertTo-Json -Compress
