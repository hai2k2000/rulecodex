[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [string]$ProjectRoot = (Get-Location).Path
)
$statePath = Join-Path $CodexHome 'rules\rulecodex-state.json'
if (Test-Path -LiteralPath $statePath) {
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    $state | Select-Object machine, policy_version, source_ref, source_commit, policy_sha256, last_verified_utc, last_sync_status, last_error_utc | Format-List
} else { Write-Output 'RuleCodex state: NOT_INSTALLED' }
$agents = Join-Path $ProjectRoot 'AGENTS.md'
if (Test-Path -LiteralPath $agents) {
    $matches = Select-String -LiteralPath $agents -Pattern '(?i)(github actions.*(required|must)|must.*push.*before.*deploy|build.*on.*vps|build.*on.*production)' -AllMatches
    if ($matches) {
        Write-Output 'PROJECT POLICY CONFLICTS: REVIEW_REQUIRED'
        $matches | ForEach-Object { Write-Output ("{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()) }
    } else { Write-Output 'PROJECT POLICY CONFLICTS: none detected by baseline checks' }
} else { Write-Output 'PROJECT AGENTS.md: not found' }
