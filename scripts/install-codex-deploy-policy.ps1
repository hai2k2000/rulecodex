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
$sourceSkill = Join-Path $RuleCodexRoot 'skills\local-vps-deploy'
$targetSkill = Join-Path $CodexHome 'skills\local-vps-deploy'
$targetPolicy = Join-Path $CodexHome 'rules\GLOBAL_DEPLOY_POLICY.md'
$policy = Join-Path $RuleCodexRoot 'GLOBAL_DEPLOY_POLICY.md'
$globalAgents = Join-Path $CodexHome 'AGENTS.md'
$targetBin = Join-Path $CodexHome 'bin'
$manifestPath = Join-Path $RuleCodexRoot 'RULECODEX_VERSION.json'

if (-not (Test-Path -LiteralPath (Join-Path $sourceSkill 'SKILL.md'))) {
    throw "Missing canonical skill: $sourceSkill\SKILL.md"
}
if (-not (Test-Path -LiteralPath $policy)) {
    throw "Missing canonical policy: $policy"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
foreach ($relative in $manifest.managed_files) {
    $source = Join-Path $RuleCodexRoot $relative
    $expected = $manifest.managed_sha256.PSObject.Properties[$relative].Value
    $text = Get-Content -Raw -LiteralPath $source
    $normalized = $text -replace "`r`n", "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actual = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized)))).Replace('-', '') }
    finally { $sha.Dispose() }
    if (-not $expected -or $actual -ne $expected) { throw "Manifest checksum mismatch: $relative" }
}

New-Item -ItemType Directory -Force -Path (Split-Path $targetSkill) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $targetPolicy) | Out-Null
New-Item -ItemType Directory -Force -Path $targetBin | Out-Null
if ($PSCmdlet.ShouldProcess($targetSkill, 'Install local-vps-deploy skill')) {
    if (Test-Path -LiteralPath $targetSkill) {
        $backup = "$targetSkill.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item -LiteralPath $targetSkill -Destination $backup
    }
    Copy-Item -LiteralPath $sourceSkill -Destination $targetSkill -Recurse
    Copy-Item -LiteralPath $policy -Destination $targetPolicy -Force
    Copy-Item -LiteralPath (Join-Path $RuleCodexRoot 'scripts\rulecodex-sync.ps1') -Destination (Join-Path $targetBin 'rulecodex-sync.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RuleCodexRoot 'scripts\codex-managed.ps1') -Destination (Join-Path $targetBin 'codex-managed.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RuleCodexRoot 'scripts\rulecodex-status.ps1') -Destination (Join-Path $targetBin 'rulecodex-status.ps1') -Force
}

if ($InstallGlobalInstructions) {
    if (-not (Test-Path -LiteralPath $globalAgents)) {
        throw "Global AGENTS.md does not exist; refusing to create/replace it automatically."
    }
    $content = Get-Content -Raw -LiteralPath $globalAgents
    $block = @'
<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->

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

Canonical repository: `hai2k2000/rulecodex`
Canonical policy: `GLOBAL_DEPLOY_POLICY.md`
Reusable skill: `skills/local-vps-deploy/SKILL.md`

<!-- END CODEX GLOBAL DEPLOY POLICY -->
'@
    $pattern = '(?s)<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->.*?<!-- END CODEX GLOBAL DEPLOY POLICY -->'
    if ($content -match $pattern) { $next = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }) }
    else { $next = $content.TrimEnd() + "`r`n`r`n" + $block + "`r`n" }
    if ($next -ne $content) {
        $backup = "$globalAgents.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $globalAgents -Destination $backup -Force
        Set-Content -LiteralPath $globalAgents -Value $next -Encoding UTF8
        Write-Output "BACKUP: $backup"
    }
}

if ($InstallPowerShellHook) {
    $profilePath = $PROFILE.CurrentUserAllHosts
    $hookMarker = '# BEGIN RULECODEX MANAGED STARTUP HOOK'
    $hook = @"
$hookMarker
function codex {
    & '$targetBin\codex-managed.ps1' @args
}
# END RULECODEX MANAGED STARTUP HOOK
"@
    $profileContent = if (Test-Path -LiteralPath $profilePath) { Get-Content -Raw -LiteralPath $profilePath } else { '' }
    if ($profileContent -notmatch [regex]::Escape($hookMarker)) {
        if ($profileContent -match '(?m)^\s*function\s+codex\b') {
            throw "PowerShell profile already defines a codex function; refusing to replace it. Install the managed launcher manually after review: $targetBin\codex-managed.ps1"
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $profilePath) | Out-Null
        if (Test-Path -LiteralPath $profilePath) {
            Copy-Item -LiteralPath $profilePath -Destination "$profilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
        }
        Add-Content -LiteralPath $profilePath -Value ("`r`n" + $hook)
        Write-Output "HOOK: $profilePath"
    }
}

Write-Output "PASS: installed $targetSkill"
Write-Output "POLICY: $targetPolicy"
