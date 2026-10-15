# Global Deploy Policy

Version: 1.0  
Scope: all Codex-managed projects that deploy to a VPS or another explicitly identified target.

## Purpose

Provide one safe default for building, transferring, verifying, activating, archiving, and rolling back releases. Project-specific `AGENTS.md` and deployment documents may add stricter controls, but must not silently weaken this policy.

## Default release path

```text
LOCAL DEVELOPMENT -> LOCAL BUILD -> SSH/RSYNC -> TARGET VERIFY -> PRODUCTION ACTIVATION -> GITHUB ARCHIVE
```

GitHub is the source archive, collaboration, and version-control system. GitHub Actions is optional; it is not a required step in the normal deployment path.

## Mandatory rules

1. Develop and build on the local machine, or in another explicitly approved compatible build environment.
2. Do not require a GitHub push before local build or artifact transfer.
3. Record the source commit/version before packaging. A dirty tree requires explicit acknowledgement and provenance evidence.
4. Build against a runtime/toolchain compatible with the target. Record the runtime, package-lock state, build command, and artifact identity.
5. Transfer only the required artifact/configuration through an approved channel such as SSH/rsync. Never transfer a development worktree or secrets.
6. The target verifies the artifact, checksum, provenance, disk budget, release layout, and service prerequisites. Do not rebuild on the target unless the project policy explicitly requires it.
7. Every release must have checksum/provenance evidence, an independent release identifier, a health check, and a documented rollback target before activation.
8. Production activation, restart, migration, destructive retention, and cleanup APPLY require explicit owner approval for the named project and release.
9. Keep runtime secrets and environment files on the target or approved secret store; they must not enter artifacts, Git, logs, or reports.
10. Sync to GitHub after a successful local/build/deploy checkpoint or at another appropriate point. If push fails, report the repository as unsynchronized; never hide the failure.
11. A target is not assumed to be a VPS. Identify the deployment platform first and adapt transfer/activation/verification to that platform.

## Required project configuration

Before build or deploy, read the project `AGENTS.md` and deployment docs. The project must identify, or explicitly mark as not applicable:

- application/runtime type (Next.js, static site, Node.js backend, Docker, or other);
- build command and compatible toolchain;
- target/platform and non-secret connection reference;
- staging and immutable release roots;
- service/process/container to verify and activate;
- backup, rollback, and migration gates;
- health checks and acceptance criteria;
- disk budget, artifact/release/log retention, and protected paths;
- owner/approver for production activation.

Missing or conflicting values are a preflight blocker, not a reason to guess.

## Gates

### Build gate

- working tree and source commit captured;
- dependencies/build completed locally;
- tests and relevant static checks pass;
- artifact excludes secrets and development-only files;
- checksum and provenance manifest generated;
- peak disk requirement is within the configured budget.

### Target verification gate

- connection and target identity verified without exposing credentials;
- target has sufficient disk and a compatible runtime;
- artifact checksum matches the local manifest;
- staging/release is isolated from the active release;
- backup/rollback target and service health checks are known;
- no activation, restart, migration, or cleanup APPLY occurs in verify-only mode.

### Activation gate

Activation is blocked until the owner approves the exact project, release identifier, target, and requested operations. The activation record must include pre/post health, migration result if applicable, active-release pointer, and rollback decision.

## Data growth and retention

- Do not keep unnecessary build caches, worktrees, or development directories on a target.
- Apply bounded retention to artifacts, releases, and logs using project-specific values.
- Protect the active release, previous/rollback targets, backups, runtime data, secrets, and unknown/unclassified objects.
- Check disk before build/transfer/activation. Stop when the budget cannot be proven safe.
- Never run cleanup APPLY, bulk prune, or destructive retention without exact owner approval.

## New project bootstrap

At project creation, add a project-specific `AGENTS.md` (or deployment document) that links to this policy and fills in the required configuration above. The project inherits this policy by default through the global Codex instructions. A project may narrow the allowed operations or add gates; it must document any intentional platform-specific deviation.

## Standard reporting

Every build/deploy task reports: project, source commit, artifact/release id, target, mode (`build`, `verify`, or `activate`), checksums/provenance, health result, GitHub sync status, blockers, and rollback readiness. Never include passwords, private keys, tokens, or secret values.

## Reference

Canonical repository: `hai2k2000/rulecodex`  
Canonical file: `GLOBAL_DEPLOY_POLICY.md`  
Reusable skill: `skills/local-vps-deploy/SKILL.md`  
Install each environment independently; do not assume Windows, WSL2, VPS, office machines, or future Codex installations share a filesystem.
