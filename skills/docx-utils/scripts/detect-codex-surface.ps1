[CmdletBinding()]
param(
  [switch]$Json
)

$reason = $null

if ($env:CODEX_MANAGED_BY_NPM -eq '1') {
  $surface = 'cli'
  $reason = 'codex-npm'
} else {
  $surface = 'app'
  $reason = 'fallback'
}

if ($Json) {
  [pscustomobject]@{
    surface = $surface
    reason = $reason
  } | ConvertTo-Json -Compress
} else {
  $surface
}
