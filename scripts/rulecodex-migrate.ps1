[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$RuleCodexRoot,
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }),
    [switch]$InstallGlobalInstructions
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $RuleCodexRoot 'RULECODEX_VERSION.json'
$installer = Join-Path $RuleCodexRoot 'scripts\install-codex-deploy-policy.ps1'
$syncPath = Join-Path $CodexHome 'bin\rulecodex-sync.ps1'
$logDir = Join-Path $CodexHome 'logs'
$logFile = Join-Path $logDir 'rulecodex-migration.log'
$migrationState = Join-Path $CodexHome 'rules\rulecodex-migration.json'

function Write-MigrationLog([string]$Message, [string]$Level = 'INFO') {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $line = "$(Get-Date -Format o) [$Level] $Message"
    Add-Content -LiteralPath $logFile -Value $line
    Write-Output $line
}

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Missing manifest: $manifestPath" }
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw "Missing installer: $installer" }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schema_version -ne 1 -or [string]$manifest.source_ref -ne 'main') { throw 'Migration source must be a schema-1 manifest from main.' }
foreach ($relative in $manifest.managed_files) {
    if ($relative -match '(^|[\\/])\.\.|^/') { throw "Invalid managed path: $relative" }
    $source = Join-Path $RuleCodexRoot $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing managed file: $relative" }
    $text = Get-Content -Raw -LiteralPath $source
    $bytes = [Text.Encoding]::UTF8.GetBytes(($text -replace "`r`n", "`n"))
    $actual = ([BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes))).Replace('-', '')
    $expected = $manifest.managed_sha256.PSObject.Properties[$relative].Value
    if ($actual -ne $expected) { throw "Manifest checksum mismatch: $relative" }
}

$oldPinned = $false
if (Test-Path -LiteralPath $syncPath -PathType Leaf) {
    $oldPinned = (Get-Content -Raw -LiteralPath $syncPath) -match 'codex/don-dep-vps-phase1-external-artifacts'
}
Write-MigrationLog "Validated RuleCodex main manifest policy=$($manifest.policy_version); old_branch_pinned=$oldPinned"
if (-not $PSCmdlet.ShouldProcess($CodexHome, 'Replace branch-pinned RuleCodex managed scripts with main versions')) { exit 0 }

$installerArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer, '-RuleCodexRoot', $RuleCodexRoot, '-CodexHome', $CodexHome)
if ($InstallGlobalInstructions) { $installerArgs += '-InstallGlobalInstructions' }
& powershell @installerArgs
if ($LASTEXITCODE -ne 0) { throw 'RuleCodex installer failed; migration was not completed.' }

New-Item -ItemType Directory -Force -Path (Split-Path $migrationState) | Out-Null
[ordered]@{
    schema_version = 1
    migrated_utc = (Get-Date).ToUniversalTime().ToString('o')
    source_ref = 'main'
    policy_version = [string]$manifest.policy_version
    old_branch_pinned = $oldPinned
    status = 'success'
} | ConvertTo-Json | Set-Content -LiteralPath $migrationState -Encoding UTF8
Write-MigrationLog 'Migration completed; future managed sync defaults to main.'
