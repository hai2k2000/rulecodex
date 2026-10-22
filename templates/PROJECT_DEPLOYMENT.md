# Project Deployment Configuration

This project inherits [`GLOBAL_DEPLOY_POLICY.md`](https://github.com/hai2k2000/rulecodex/blob/main/GLOBAL_DEPLOY_POLICY.md). Keep this file next to the project's `AGENTS.md` or link it from there.

Fill every field before a build/deploy task. Write `N/A` with a reason when a field does not apply.

- Deployment profile (`default-local-to-target` or Thoi Dai Work-only `thoidai-work-vps-first`): `TODO`
- Application/runtime: `TODO`
- Build host (local machine or authorized VPS), command and compatible runtime/toolchain: `TODO`
- Test/static-check commands: `TODO`
- Target platform and non-secret connection reference: `TODO`
- Isolated development workspace and staging/intake root: `TODO`
- Immutable release root and active-release pointer: `TODO`
- Service/process/container to verify or activate: `TODO`
- Health check and acceptance criteria: `TODO`
- Backup procedure and protected data: `TODO`
- Rollback target/procedure: `TODO`
- Migration gate and owner approval: `TODO`
- Disk budget and peak build requirement: `TODO`
- VPS-local checksum/provenance manifest and source/dirty-tree evidence (if applicable): `TODO`
- Artifact/release/log retention: `TODO`
- Production approver: `TODO`

Until all `TODO` values are resolved, the deployment skill may perform discovery only and must not activate production.

Thoi Dai Work VPS-FIRST is available only when explicitly opted in via the project's `AGENTS.md` and permitted by the canonical global policy. It eliminates mandatory off-VPS artifact transfer and WSL/CI gate, but not final release-specific approval, immutable release verification, disk guard (at least 10 GiB free after headroom), health check, migration/data safety, deploy lock or rollback. Adopting this template does not deactivate legacy project deploy scripts.
