[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CodexArgs
)
$sync = Join-Path $PSScriptRoot 'rulecodex-sync.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $sync -Mode Sync
if ($LASTEXITCODE -ne 0) { Write-Warning 'RuleCodex sync failed; continuing with the last installed policy only.' }
$command = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $command) { throw 'Codex executable was not found in PATH. Use the installed Codex command or pass its path explicitly.' }
& $command.Source @CodexArgs
exit $LASTEXITCODE
