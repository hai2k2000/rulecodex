---
name: local-vps-deploy
description: Build, verify, and (only with explicit approval) activate releases from a local workspace to a configured VPS or other deployment target using checksums, provenance, health checks, rollback gates, and bounded retention.
---

# Local-to-target deployment

Use this skill for build, staging, verification, release, rollback, or deployment-preparation tasks. Read the repository's `AGENTS.md`, deployment documentation, and `GLOBAL_DEPLOY_POLICY.md` before acting. Project configuration is authoritative for commands, paths, services, platform, and budgets; never infer missing target details.

## Safety boundary

- Default mode is `BUILD` or `VERIFY`; do not activate production, restart services, run migrations, or perform cleanup APPLY without explicit owner approval naming the project, target, release, and operation.
- Never print or copy passwords, private keys, tokens, secret environment values, or database contents.
- Do not hardcode IP addresses, users, paths, credentials, or service names in this skill.
- Do not transfer a development worktree. Transfer only the configured immutable artifact and explicitly approved runtime/configuration references.
- If the target is not clearly identified as a VPS, detect the platform and use its documented transfer/activation mechanism instead of assuming SSH.

## Modes

`BUILD`: inspect project configuration, capture source commit and tree state, check disk budget, run the configured local build/tests, scan artifact contents for secrets, and emit a checksum/provenance manifest.

`VERIFY`: transfer or receive the artifact through the approved channel, verify target identity, disk/runtime prerequisites, checksum, provenance, release isolation, backup/rollback references, and health checks. Leave production unchanged.

`ACTIVATE`: require explicit owner approval, re-run preflight under the project's deployment lock, create/verify backup and rollback references, activate the exact release, run health checks, and record the result. Stop on any failed gate.

`ROLLBACK`: require approval unless the project has a documented automatic rollback rule. Select only a verified rollback target, activate it using the project procedure, run health checks, and preserve evidence.

## Workflow

1. Discover application type, build/runtime versions, target reference, staging/release roots, service, health check, migration gate, backup/rollback procedure, disk budget, and retention policy.
2. Resolve the source commit and repository state. A dirty or uncommitted source tree is a warning/blocker according to project policy and must be recorded in provenance.
3. Run local build and relevant tests in the configured compatible environment. Do not silently switch to GitHub Actions when local work fails; diagnose and report the failure.
4. Package a minimal artifact, exclude `.env*`, keys, credentials, development caches, and unrelated files, then generate SHA-256 checksums and provenance.
5. In `VERIFY`, send the artifact to staging or the configured target intake, validate checksum/provenance and target prerequisites, and report PASS/FAIL without activation.
6. In `ACTIVATE`, require the approval gate, revalidate the exact artifact and release id, perform the documented activation, and run bounded health checks.
7. Archive/sync the source and deployment evidence to GitHub when appropriate. Report push failures as `GITHUB_UNSYNCED`; do not treat them as a successful archive.
8. Report the release id, commit, artifact checksum, target, mode, checks, health, rollback readiness, retention result, and blockers without secrets.

## Supported application families

The workflow applies to Next.js, static websites, Node.js backends, Docker applications, and other stacks after compatibility checks. Select commands from project configuration; this skill supplies the safety gates, not universal build commands.

## New project requirement

When a project is initialized, create or update its `AGENTS.md`/deployment document with the required configuration from `GLOBAL_DEPLOY_POLICY.md` and link to the canonical policy. If the information is missing, stop at discovery and request project configuration rather than guessing.

## RuleCodex synchronization

The canonical policy repository is `hai2k2000/rulecodex`. Environment installers maintain a local policy cache, a SHA-256/provenance state file, and an append-only sync log. A managed Codex launcher may run `rulecodex-sync` before startup:

- `Check` verifies the remote ref and reports whether the installed commit is current.
- `Sync` updates only the allowlisted policy and skill files after validating the repository manifest and commit; it does not execute repository code.
- Offline mode keeps the last valid installation and reports that the remote version could not be verified.
- `rulecodex-status` reports the installed policy version/commit and flags baseline conflicts in the current project's `AGENTS.md`.

Project-specific rules remain in force. A conflict must be reported and resolved by project documentation/owner review; synchronization must not delete or rewrite unrelated project instructions.
