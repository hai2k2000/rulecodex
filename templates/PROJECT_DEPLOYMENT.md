# Project Deployment Configuration

This project inherits [`GLOBAL_DEPLOY_POLICY.md`](https://github.com/hai2k2000/rulecodex/blob/main/GLOBAL_DEPLOY_POLICY.md). Keep this file next to the project's `AGENTS.md` or link it from there.

Fill every field before a build/deploy task. Write `N/A` with a reason when a field does not apply.

- Application/runtime: `TODO`
- Local build command and compatible runtime/toolchain: `TODO`
- Test/static-check commands: `TODO`
- Target platform and non-secret connection reference: `TODO`
- Staging/intake root: `TODO`
- Immutable release root and active-release pointer: `TODO`
- Service/process/container to verify or activate: `TODO`
- Health check and acceptance criteria: `TODO`
- Backup procedure and protected data: `TODO`
- Rollback target/procedure: `TODO`
- Migration gate and owner approval: `TODO`
- Disk budget and peak build requirement: `TODO`
- Artifact/release/log retention: `TODO`
- Production approver: `TODO`

Until all `TODO` values are resolved, the deployment skill may perform discovery only and must not activate production.
