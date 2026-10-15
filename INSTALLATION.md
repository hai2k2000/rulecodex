# Policy Installation and Synchronization

Install the policy and `local-vps-deploy` skill independently on every Codex environment. Do not assume that Windows, WSL2, a VPS, an office machine, or a future installation shares `HOME`, `CODEX_HOME`, or the same checkout.

## Windows Codex

Run PowerShell from a trusted RuleCodex checkout:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\install-codex-deploy-policy.ps1 -RuleCodexRoot $PWD -InstallGlobalInstructions -InstallPowerShellHook
```

This installs the skill under `$env:CODEX_HOME\skills` (or `$HOME\.codex\skills`) and caches the policy under `rules\GLOBAL_DEPLOY_POLICY.md`. Existing skill directories are renamed to a timestamped backup before replacement.

With `-InstallGlobalInstructions`, a missing global `AGENTS.md` is created safely. The installer validates all sources and checksums before making changes; a failed preflight does not leave a partial install.

The installer does not edit `config.toml`, model/provider settings, 9Router, CLIProxyAPI, npm `codex` launchers, or the Codex Desktop executable. It installs separate `codex-managed.ps1` and `codex-managed.cmd` launchers under `CODEX_HOME\bin`. The PowerShell startup hook is opt-in via `-InstallPowerShellHook`; CMD users can call `codex-managed.cmd` explicitly.

## WSL2 or Linux Codex

Run the POSIX installer from a Linux-visible RuleCodex checkout:

```bash
bash scripts/install-codex-deploy-policy.sh "$PWD"
```

The POSIX installer places `rulecodex-sync.sh`, `rulecodex-status.sh`, and `codex-managed.sh` in `$CODEX_HOME/bin`. Add that directory after the real Codex executable in the user's PATH or call the managed launcher by its full path.

Codex Desktop is not replaced or wrapped. It continues to read the installed global instructions and skills; automatic pre-start sync is available only through the managed CLI launchers because the Desktop app does not expose a supported shell startup hook.

Set `CODEX_HOME` explicitly when the environment does not use `$HOME/.codex`.

## VPS or office machine

Clone or sync only the RuleCodex policy repository through the approved organization channel, verify the repository/commit, then run the installer locally on that environment. Do not copy credentials or a development worktree merely to install the policy. VPS installation does not authorize deployment or cleanup.

## New/future environment checklist

1. Confirm the local `CODEX_HOME` and the RuleCodex checkout.
2. Install the policy and skill with the environment-appropriate script.
3. Verify the installed `GLOBAL_DEPLOY_POLICY.md` and `local-vps-deploy/SKILL.md` hashes against the checkout.
4. Start a fresh Codex task and confirm it reads the global instructions before any build/deploy task.
5. Record the environment, policy version/commit, install time, and PASS/FAIL result without secrets.

## Migrating an existing installation

Installations created from the experimental branch keep that branch in their installed sync script. They cannot discover the new default until their managed scripts are replaced. Run the following one-time command from an approved PowerShell session; it clones `main`, validates the manifest before installation, backs up changed files, replaces the managed sync/launcher files, and records the migration. It does not modify model/provider settings, 9Router, CLIProxyAPI, SSH configuration, or the Codex Desktop executable.

```powershell
$r=Join-Path $env:TEMP ('rulecodex-migrate-'+[guid]::NewGuid().ToString('N')); git clone --depth 1 --branch main https://github.com/hai2k2000/rulecodex.git $r; & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $r 'scripts\rulecodex-migrate.ps1') -RuleCodexRoot $r -InstallGlobalInstructions
```

The migration refuses to replace files when the `main` manifest or managed-file checksums fail. After it succeeds, inspect `rules\rulecodex-state.json` and run the managed launcher once; its sync log must show `ref=main`. Offline runs retain the last verified policy and emit a warning.

## Exact one-time Windows command

On the office computer, run exactly this one PowerShell command (it creates a unique temporary checkout, verifies the repository through Git, installs the policy, and enables the managed startup hook):

```powershell
$r=Join-Path $env:TEMP ('rulecodex-'+[guid]::NewGuid().ToString('N')); git clone --depth 1 --branch main https://github.com/hai2k2000/rulecodex.git $r; & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $r 'scripts\install-codex-deploy-policy.ps1') -RuleCodexRoot $r -InstallGlobalInstructions -InstallPowerShellHook
```

After this, start Codex through the `codex` function in a new PowerShell session. The managed launcher attempts a verified sync from `main` before each start and continues with the last valid local policy when the network is unavailable.

## Rollback

If a policy update on `main` fails validation or causes an instruction regression, do not activate production. Stop the managed launcher, identify the timestamped directory under `CODEX_HOME\backups\rulecodex\`, and restore the previous `AGENTS.md`, policy, skill, and managed scripts as a single backup set. Restore the prior `rules\rulecodex-state.json` if it was included in the backup, then run `rulecodex-status` and an offline managed-launcher check. Keep the failed sync log and record the commit/checksum as rollback evidence. A future sync remains blocked until an owner approves a corrected `main` commit.
