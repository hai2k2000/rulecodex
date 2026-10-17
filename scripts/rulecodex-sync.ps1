[CmdletBinding()]
param(
    [ValidateSet('Check', 'Sync')]
    [string]$Mode = 'Check',
    [string]$RepositoryUrl = 'https://github.com/hai2k2000/rulecodex.git',
    [string]$Ref = 'main',
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
# Git writes progress to stderr; treat native stderr as captured diagnostics, not terminating PowerShell errors.
if ($null -ne (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)) {
    $PSNativeCommandUseErrorActionPreference = $false
}
$script:LogDir = Join-Path $CodexHome 'logs'
$script:LogFile = Join-Path $script:LogDir 'rulecodex-sync.log'
$script:StateFile = Join-Path $CodexHome 'rules\rulecodex-state.json'
$script:ManagedMarkerStart = '<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->'
$script:ManagedMarkerEnd = '<!-- END CODEX GLOBAL DEPLOY POLICY -->'

function Write-Event([string]$Message, [string]$Level = 'INFO') {
    New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null
    $line = "$(Get-Date -Format o) [$Level] $Message"
    Add-Content -LiteralPath $script:LogFile -Value $line
    Write-Output $line
}

function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-NormalizedSha256([string]$Path) {
    $text = Get-Content -Raw -LiteralPath $Path
    $normalized = $text -replace "`r`n", "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($normalized)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Save-State($State) {
    New-Item -ItemType Directory -Force -Path (Split-Path $script:StateFile) | Out-Null
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
}

function Backup-File([string]$Path, [string]$BackupRoot) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $relative = if ($Path.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) { $Path.Substring($env:USERPROFILE.Length).TrimStart('\\') } else { Split-Path -Leaf $Path }
    $destination = Join-Path $BackupRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
    Copy-Item -LiteralPath $Path -Destination $destination -Force
    return $destination
}

function Get-ManagedPolicyBlock([string]$PolicyPath) {
    $policy = Get-Content -Raw -LiteralPath $PolicyPath
    return @"
$script:ManagedMarkerStart

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

$script:ManagedMarkerEnd
"@
}

function Update-GlobalAgents([string]$PolicyPath, [string]$BackupRoot) {
    $agents = Join-Path $CodexHome 'AGENTS.md'
    if (-not (Test-Path -LiteralPath $agents)) {
        Write-Event "Global AGENTS.md does not exist; no file created automatically." 'WARN' | Out-Null
        return 'missing'
    }
    $override = Join-Path $CodexHome 'AGENTS.override.md'
    if (Test-Path -LiteralPath $override) {
        Write-Event "AGENTS.override.md exists and has higher precedence; it was not modified." 'WARN' | Out-Null
    }
    $content = Get-Content -Raw -LiteralPath $agents
    $block = Get-ManagedPolicyBlock $PolicyPath
    $pattern = '(?s)<!-- BEGIN CODEX GLOBAL DEPLOY POLICY -->.*?<!-- END CODEX GLOBAL DEPLOY POLICY -->'
    if ($content -match $pattern) { $next = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }) }
    else { $next = $content.TrimEnd() + "`r`n`r`n" + $block + "`r`n" }
    if ($next -ne $content) {
        Backup-File $agents $BackupRoot | Out-Null
        Set-Content -LiteralPath $agents -Value $next -Encoding UTF8
        Write-Event "Updated managed global deploy block in $agents" | Out-Null
        return 'updated'
    }
    return 'unchanged'
}

function Get-Manifest([string]$Root) {
    $manifest = Read-Json (Join-Path $Root 'RULECODEX_VERSION.json')
    if ($null -eq $manifest -or $manifest.schema_version -ne 1) { throw 'Missing or unsupported RULECODEX_VERSION.json' }
    foreach ($relative in $manifest.managed_files) {
        if ($relative -match '(^|[\\/])\.\.|^/') { throw "Invalid managed path: $relative" }
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relative) -PathType Leaf)) { throw "Missing managed file: $relative" }
        $expected = $manifest.managed_sha256.PSObject.Properties[$relative].Value
        $actual = Get-NormalizedSha256 (Join-Path $Root $relative)
        if (-not $expected -or $actual -ne $expected) { throw "Manifest checksum mismatch: $relative" }
    }
    return $manifest
}

function Get-RemoteCheckout {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ("rulecodex-sync-" + [guid]::NewGuid().ToString('N'))
    $gitOut = "$temp.clone.stdout.log"
    $gitErr = "$temp.clone.stderr.log"
    $cloneArgs = @('clone', '--depth', '1', '--branch', $Ref, '--filter=blob:none', '--no-checkout', $RepositoryUrl, $temp)
    $cloneProcess = Start-Process -FilePath 'git' -ArgumentList $cloneArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $gitOut -RedirectStandardError $gitErr
    $cloneExit = $cloneProcess.ExitCode
    Write-Event "git clone exit=$cloneExit path=$temp" | Out-Null
    if (Test-Path -LiteralPath $gitOut) { Get-Content -LiteralPath $gitOut | ForEach-Object { Write-Event ([string]$_) | Out-Null } }
    if (Test-Path -LiteralPath $gitErr) { Get-Content -LiteralPath $gitErr | ForEach-Object { Write-Event ([string]$_) | Out-Null } }
    if ($cloneExit -ne 0) { throw "Unable to retrieve RuleCodex from $RepositoryUrl ref $Ref" }
    $checkoutOut = "$temp.checkout.stdout.log"
    $checkoutErr = "$temp.checkout.stderr.log"
    $checkoutArgs = @('-C', $temp, 'checkout', '--quiet', $Ref)
    $checkoutProcess = Start-Process -FilePath 'git' -ArgumentList $checkoutArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $checkoutOut -RedirectStandardError $checkoutErr
    $checkoutExit = $checkoutProcess.ExitCode
    Write-Event "git checkout exit=$checkoutExit path=$temp" | Out-Null
    if (Test-Path -LiteralPath $checkoutOut) { Get-Content -LiteralPath $checkoutOut | ForEach-Object { Write-Event ([string]$_) | Out-Null } }
    if (Test-Path -LiteralPath $checkoutErr) { Get-Content -LiteralPath $checkoutErr | ForEach-Object { Write-Event ([string]$_) | Out-Null } }
    if ($checkoutExit -ne 0) { throw 'Unable to materialize the requested RuleCodex ref' }
    return [string]$temp
}

function Copy-ManagedFiles([string]$Root, $Manifest, [string]$BackupRoot) {
    $destinationMap = @{
        'GLOBAL_DEPLOY_POLICY.md' = Join-Path $CodexHome 'rules\GLOBAL_DEPLOY_POLICY.md'
        'skills/local-vps-deploy/SKILL.md' = Join-Path $CodexHome 'skills\local-vps-deploy\SKILL.md'
    }
    foreach ($relative in $Manifest.managed_files) {
        if (-not $destinationMap.ContainsKey($relative)) { continue }
        $source = Join-Path $Root $relative
        $destination = $destinationMap[$relative]
        $hash = Get-NormalizedSha256 $source
        if ($hash -notmatch '^[0-9A-F]{64}$') { throw "Invalid checksum for $relative" }
        if (Test-Path -LiteralPath $destination) { Backup-File $destination $BackupRoot | Out-Null }
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
        Write-Event "Installed verified managed file $relative"
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path $script:StateFile) | Out-Null
$started = Get-Date
$state = Read-Json $script:StateFile
if ($Offline) {
    Write-Event 'OFFLINE: using the last installed RuleCodex policy; remote version was not verified.' 'WARN'
    if ($Mode -eq 'Sync') { $Mode = 'Check' }
}
$backupRoot = Join-Path $CodexHome ("backups\rulecodex\" + $started.ToString('yyyyMMdd-HHmmss'))
$remoteRoot = $null
try {
    if ($Mode -eq 'Check' -and $Offline) { exit 0 }
    $remoteRoot = Get-RemoteCheckout
    $manifest = Get-Manifest $remoteRoot
    $commit = (& git -C $remoteRoot rev-parse HEAD).Trim()
    $policyHash = Get-NormalizedSha256 (Join-Path $remoteRoot 'GLOBAL_DEPLOY_POLICY.md')
    if ($commit -notmatch '^[0-9a-f]{40}$' -or $policyHash -notmatch '^[0-9A-F]{64}$') { throw 'Remote provenance/checksum validation failed' }
    $installedVersion = if ($state) { $state.policy_version } else { $null }
    $status = if ($state -and $state.source_commit -eq $commit) { 'current' } else { 'update-available' }
    Write-Event "Verified RuleCodex ref=$Ref commit=$commit policy=$($manifest.policy_version) status=$status"
    if ($Mode -eq 'Sync' -and $status -ne 'current') {
        $globalStatus = Update-GlobalAgents (Join-Path $remoteRoot 'GLOBAL_DEPLOY_POLICY.md') $backupRoot
        Copy-ManagedFiles $remoteRoot $manifest $backupRoot
        Save-State ([ordered]@{ schema_version = 1; machine = [Environment]::MachineName; policy_version = [string]$manifest.policy_version; source_repository = $RepositoryUrl; source_ref = $Ref; source_commit = $commit; policy_sha256 = $policyHash; last_verified_utc = (Get-Date).ToUniversalTime().ToString('o'); last_sync_status = 'success'; global_agents = $globalStatus })
        Write-Event "RuleCodex sync completed successfully at policy $($manifest.policy_version)"
    }
    elseif (-not $state) {
        Save-State ([ordered]@{ schema_version = 1; machine = [Environment]::MachineName; policy_version = [string]$manifest.policy_version; source_repository = $RepositoryUrl; source_ref = $Ref; source_commit = $commit; policy_sha256 = $policyHash; last_verified_utc = (Get-Date).ToUniversalTime().ToString('o'); last_sync_status = 'verified-only' })
    }
    exit 0
}
catch {
    Write-Event $_.Exception.Message 'ERROR'
    if ($state) {
        $state.last_sync_status = 'offline-or-verification-failed'
        $state.last_error_utc = (Get-Date).ToUniversalTime().ToString('o')
        Save-State $state
    }
    exit 1
}
finally {
    if ($remoteRoot -and (Test-Path -LiteralPath $remoteRoot)) { Remove-Item -LiteralPath $remoteRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
