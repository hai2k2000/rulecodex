[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$RuleCodexRoot,
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [switch]$InstallGlobalInstructions,
    [switch]$InstallPowerShellHook
)

$ErrorActionPreference = 'Stop'
$sourcePolicy = Join-Path $RuleCodexRoot 'GLOBAL_DEPLOY_POLICY.md'
$manifestPath = Join-Path $RuleCodexRoot 'RULECODEX_VERSION.json'
$sourceSkill = Join-Path $RuleCodexRoot 'skills\local-vps-deploy\SKILL.md'
$requiredScripts = @('rulecodex-sync.ps1', 'codex-managed.ps1', 'codex-managed.cmd', 'rulecodex-status.ps1', 'rulecodex-migrate.ps1')
$globalAgents = Join-Path $CodexHome 'AGENTS.md'
$targetPolicy = Join-Path $CodexHome 'rules\GLOBAL_DEPLOY_POLICY.md'
$targetSkill = Join-Path $CodexHome 'skills\local-vps-deploy\SKILL.md'
$targetBin = Join-Path $CodexHome 'bin'
$managedMarkerStart = '<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->'
$managedMarkerEnd = '<!-- END CODEX GLOBAL DEPLOY POLICY -->'

function Get-NormalizedSha256([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    $normalized = $text -replace "`r`n", "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized)))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Backup-IfChanged([string]$Source, [string]$Destination, [string]$BackupRoot) {
    if (-not (Test-Path -LiteralPath $Destination)) { return $false }
    if ((Get-NormalizedSha256 $Source) -eq (Get-NormalizedSha256 $Destination)) { return $false }
    $relative = if ($Destination.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) { $Destination.Substring($env:USERPROFILE.Length).TrimStart('\\') } else { Split-Path -Leaf $Destination }
    $backup = Join-Path $BackupRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
    Copy-Item -LiteralPath $Destination -Destination $backup -Force
    return $true
}

function Get-PolicyBlock {
@"
$managedMarkerStart

# GLOBAL DEPLOY POLICY

For build, packaging, staging, deploy, release, rollback, migration, service activation, or deployment cleanup:

1. Read the canonical `GLOBAL_DEPLOY_POLICY.md` from the configured RuleCodex checkout or local policy cache, then read the target repository's `AGENTS.md` and deployment documentation. Do not assume a shared HOME or CODEX_HOME.
2. Use `LOCAL DEVELOPMENT -> LOCAL BUILD -> SSH/RSYNC (or the documented target transfer) -> TARGET VERIFY -> PRODUCTION ACTIVATION -> GITHUB ARCHIVE`.
3. Prefer local build and direct artifact transfer. GitHub Actions is optional and is not a fallback that may be selected silently.
4. Identify the target platform before acting. Never expose credentials, private keys, tokens, secrets, or `.env` contents.
5. Default to build/verify only. Production activation, restart, migration, rollback, destructive retention, and cleanup APPLY require explicit owner approval for the exact project, target, release, and operation.
6. Require source commit/version, checksum, provenance, compatible runtime, disk budget, health check, backup/rollback target, and retention evidence. Missing or conflicting configuration is a blocker.
7. New projects must link to the canonical policy and declare application type, build command, target, staging/release roots, service, health check, migration/backup/rollback gates, disk budget, retention, and approver.
8. Report GitHub synchronization failures as unsynchronized; do not hide them.
9. Authenticated smoke is optional diagnostics only; missing cookies, bearer tokens, test accounts, waivers, or RBAC smoke evidence must never block build, verification, activation, or deployment. Preserve static/automated auth tests, migration safety, health, rollback, and disk guards.

Canonical repository: `hai2k2000/rulecodex`
Canonical policy: `GLOBAL_DEPLOY_POLICY.md`
Reusable skill: `skills/local-vps-deploy/SKILL.md`

$managedMarkerEnd
"@
}

if (-not (Test-Path -LiteralPath $sourcePolicy -PathType Leaf)) { throw "Missing canonical policy: $sourcePolicy" }
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Missing manifest: $manifestPath" }
if (-not (Test-Path -LiteralPath $sourceSkill -PathType Leaf)) { throw "Missing canonical skill: $sourceSkill" }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema_version -ne 1) { throw 'Unsupported RuleCodex manifest schema.' }
foreach ($relative in $manifest.managed_files) {
    if ($relative -match '(^|[\\/])\.\.|^/') { throw "Invalid managed path: $relative" }
    $source = Join-Path $RuleCodexRoot $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing managed file: $relative" }
    $expected = $manifest.managed_sha256.PSObject.Properties[$relative].Value
    if ((Get-NormalizedSha256 $source) -ne $expected) { throw "Manifest checksum mismatch: $relative" }
}
foreach ($scriptName in $requiredScripts) {
    if (-not (Test-Path -LiteralPath (Join-Path $RuleCodexRoot "scripts\$scriptName") -PathType Leaf)) { throw "Missing installer dependency: $scriptName" }
}

$profilePath = $PROFILE.CurrentUserAllHosts
$hookMarker = '# BEGIN RULECODEX MANAGED STARTUP HOOK'
$hook = @"
$hookMarker
function codex {
    & '$targetBin\codex-managed.ps1' @args
}
# END RULECODEX MANAGED STARTUP HOOK
"@
if ($InstallPowerShellHook -and [string]::IsNullOrWhiteSpace($profilePath)) { throw 'PowerShell profile path is unavailable; install policy without the startup hook or configure a profile explicitly.' }
$profileContent = if (-not [string]::IsNullOrWhiteSpace($profilePath) -and (Test-Path -LiteralPath $profilePath)) { Get-Content -Raw -LiteralPath $profilePath } else { '' }
if ($InstallPowerShellHook -and $profileContent -notmatch [regex]::Escape($hookMarker) -and $profileContent -match '(?m)^\s*function\s+codex\b') {
    throw "PowerShell profile already defines a codex function; refusing to replace it. Review $profilePath manually."
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $CodexHome "backups\rulecodex\$stamp"
$stagingRoot = Join-Path ([IO.Path]::GetTempPath()) ("rulecodex-install-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path "$stagingRoot\skills\local-vps-deploy", "$stagingRoot\rules", "$stagingRoot\bin" | Out-Null
    Copy-Item -LiteralPath $sourceSkill -Destination "$stagingRoot\skills\local-vps-deploy\SKILL.md"
    Copy-Item -LiteralPath $sourcePolicy -Destination "$stagingRoot\rules\GLOBAL_DEPLOY_POLICY.md"
    foreach ($scriptName in $requiredScripts) { Copy-Item -LiteralPath (Join-Path $RuleCodexRoot "scripts\$scriptName") -Destination "$stagingRoot\bin\$scriptName" }

    if ($PSCmdlet.ShouldProcess($CodexHome, 'Install verified RuleCodex policy and skill')) {
        New-Item -ItemType Directory -Force -Path (Split-Path $targetSkill), (Split-Path $targetPolicy), $targetBin | Out-Null
        $changed = $false
        if (Backup-IfChanged "$stagingRoot\skills\local-vps-deploy\SKILL.md" $targetSkill $backupRoot) { $changed = $true }
        if (Backup-IfChanged "$stagingRoot\rules\GLOBAL_DEPLOY_POLICY.md" $targetPolicy $backupRoot) { $changed = $true }
        foreach ($scriptName in $requiredScripts) { if (Backup-IfChanged "$stagingRoot\bin\$scriptName" (Join-Path $targetBin $scriptName) $backupRoot) { $changed = $true } }
        Copy-Item -LiteralPath "$stagingRoot\skills\local-vps-deploy\SKILL.md" -Destination $targetSkill -Force
        Copy-Item -LiteralPath "$stagingRoot\rules\GLOBAL_DEPLOY_POLICY.md" -Destination $targetPolicy -Force
        foreach ($scriptName in $requiredScripts) { Copy-Item -LiteralPath "$stagingRoot\bin\$scriptName" -Destination (Join-Path $targetBin $scriptName) -Force }

        if ($InstallGlobalInstructions) {
            $block = Get-PolicyBlock
            $content = if (Test-Path -LiteralPath $globalAgents) { Get-Content -Raw -LiteralPath $globalAgents } else { '' }
            $pattern = '(?s)<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->.*?<!-- END CODEX GLOBAL DEPLOY POLICY -->'
            $next = if ($content -match $pattern) { [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }) } else { $content.TrimEnd() + "`r`n`r`n" + $block + "`r`n" }
            if ($next -ne $content) {
                if (Test-Path -LiteralPath $globalAgents) { New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null; Copy-Item -LiteralPath $globalAgents -Destination (Join-Path $backupRoot 'AGENTS.md') -Force }
                New-Item -ItemType Directory -Force -Path (Split-Path $globalAgents) | Out-Null
                Set-Content -LiteralPath $globalAgents -Value $next -Encoding UTF8
                Write-Output "AGENTS: updated $globalAgents"
            }
        }
        if ($InstallPowerShellHook -and $profileContent -notmatch [regex]::Escape($hookMarker)) {
            if (Test-Path -LiteralPath $profilePath) { Copy-Item -LiteralPath $profilePath -Destination "$profilePath.backup-$stamp" -Force } else { New-Item -ItemType Directory -Force -Path (Split-Path $profilePath) | Out-Null }
            Add-Content -LiteralPath $profilePath -Value ("`r`n" + $hook)
            Write-Output "HOOK: installed $profilePath"
        }
        Write-Output "PASS: installed RuleCodex policy $($manifest.policy_version) (changed=$changed)"
    }
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
