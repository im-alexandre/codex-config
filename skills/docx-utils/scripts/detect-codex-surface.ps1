[CmdletBinding()]
param(
  [switch]$Json
)

$override = $env:DOCX_UTILS_SURFACE
if (-not $override) {
  $override = $env:CODEX_SURFACE
}

$surface = $null
$reason = $null

if ($override -match '^(cli|app)$') {
  $surface = $override.ToLowerInvariant()
  $reason = "override"
} elseif ($env:CODEX_MANAGED_BY_NPM -eq '1') {
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
