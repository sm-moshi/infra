# CNPG Centralized Migration (Canonical Runbook)

**Date:** 2026-02-11
**Status:** In progress (canonicalized from legacy CNPG migration docs)
**Scope:** Migrate application PostgreSQL workloads to shared `cnpg-main` via GitOps-only changes.

Supersedes:

- legacy CNPG centralized migration drafts (2026-02-06 and 2026-02-07), now archived

Related:

- `docs/diaries/cnpg-dhi-migration.md` (DHI boundaries and image policy context)
- `docs/diaries/harbor-implementation.md` (Harbor-specific implementation details)

## 1) Goal and Scope

- Use one shared CloudNativePG cluster: `cnpg-main` in namespace `apps`.
- Keep redundancy at `instances: 2` (primary + 1 replica).
- Migrate app databases without data loss and with explicit rollback.
- Keep all changes in Git and let ArgoCD reconcile to cluster state.

Target apps (risk-aware order):

1. Authentik
2. NetBox
3. Harbor (highest risk)
4. Later: Semaphore, Gitea, HarborGuard

## 2) Constraints and Safety

- GitOps-only: no imperative `kubectl apply/patch`, no direct Helm install/upgrade.
- No plaintext secrets in Git; continue SealedSecrets usage.
- Use service DNS for DB connectivity:
  - `cnpg-main-rw.apps.svc.cluster.local`
  - `cnpg-main-ro.apps.svc.cluster.local`
- Migration tooling must not depend on Harbor image pulls during Harbor cutover.
- Migration and role-init jobs must use explicit low resources to avoid namespace quota blowups.

## 3) Current Status Snapshot

Cluster snapshot baseline from 2026-02-07:

- `cnpg-main` exists and is running with 2 instances.
- `cnpg-main-init-roles` exists as an ArgoCD hook job with explicit resources.
- Role/database provisioning on `cnpg-main` is already staged for key apps.
- Authentik and NetBox are already configured against `cnpg-main`.
- Harbor is not yet cut over (still on per-app DB endpoint).
- Per-app migration jobs are present for some apps, disabled by default.

Known blockers/risks:

- Backup reliability must be stable before high-risk Harbor cutover.
- Confirm scheduled backup health and restore drill evidence before final migrations.

## 4) Preflight Checklist (Must Pass)

1. `cnpg-main` health:

- 2 instances healthy, replication stable, failover conditions normal.

2. Backup readiness:

- Scheduled backups succeeding.
- Restore drill documented and verified with a known-good recovery point.

3. S3/MinIO readiness:

- Bucket path exists and is reachable from `apps`.
- TLS trust / CA configuration validated.

4. Quota readiness:

- `apps` namespace has memory headroom.
- Migration/init jobs have explicit conservative requests/limits.

5. Secrets and identities:

- App DB credential secrets exist and map to the intended role/database.
- `kubernetes-dhi` pull secret available where migration jobs execute.

## 5) Standard Migration Workflow

For each app, follow this standard cutover path.

### 5.1 Prepare in Git

- Ensure `cnpg-main` has role + database enabled for the app.
- Ensure app chart supports switchable DB endpoint/secret.
- Keep migration jobs disabled by default.

### 5.2 Freeze writes (maintenance window)

- Pause writes or scale down write-heavy components for consistent dump.
- Confirm source DB is reachable from migration job namespace.

### 5.3 Run dump/restore jobs via GitOps

- Enable migration job in values.
- ArgoCD sync runs migration job as hook.
- Validate job completion and logs.
- Disable migration job again after completion.

Job design requirements:

- Use ArgoCD hook annotations (`Sync`) and hook delete policy.
- Avoid plain always-managed Job objects that recreate unexpectedly.
- Prefer S3 dump staging over large temporary PVCs.

### 5.4 Cut over app to `cnpg-main`

- Switch app DB host to `cnpg-main-rw.apps.svc.cluster.local`.
- Sync via ArgoCD.
- Validate login/API/background workers and data integrity.

### 5.5 Post-cutover validation

- Application functional checks pass.
- DB migration/state checks pass.
- `cnpg-main` backups continue to succeed after new workload load.

### 5.6 Rollback

- Keep old per-app DB resources during safety window.
- Rollback by restoring previous app DB endpoint/secret in Git and syncing.
- Do not decommission old DB/PVs until stability + backup cycle is confirmed.

### Migration tooling image policy

- Do not use Harbor-hosted tooling images for Harbor migration.
- Preferred tooling image:
  - `dhi.io/postgres:18.1-debian13@sha256:086748e4e33806af10483b2dd4bc287d7102a8cc3d11d73f5cad9886c02f3b87`
- Include `imagePullSecrets: [{ name: kubernetes-dhi }]`.

## 6) App Order and Risk Levels

| App | Risk | Current State | Migration State |
|---|---|---|---|
| Authentik | Low/Medium | Already on `cnpg-main` | Validate and keep |
| NetBox | Low/Medium | Already on `cnpg-main` | Validate and keep |
| Harbor | High | Still on per-app DB | Planned cutover after backup confidence |
| Gitea | Medium | Staged | Migrate after Harbor strategy locks |
| HarborGuard | Medium | Staged | Migrate after Harbor baseline |
| Semaphore | Medium | Later | Planned |

## 7) Harbor-Specific Deltas

Harbor has higher blast radius because DB metadata controls project/repository visibility.

Harbor-specific guidance:

- use a dedicated maintenance window
- enforce write freeze during final dump
- validate projects/repos/tags plus push/pull end-to-end
- keep registry storage unchanged during DB cutover

See detailed Harbor implementation notes:

- `docs/diaries/harbor-implementation.md`

## 8) Open Questions and Decision Log

Open questions:

1. Confirm current source DB endpoints for all apps still pending cutover.
2. Confirm downtime budget per app for maintenance windows.
3. Confirm dump retention policy/prefix separate from WAL/base backup paths.
4. Confirm Harbor cutover go/no-go criteria tied to backup reliability SLO.

Decisions locked:

- Canonical runbook is this file.
- Legacy CNPG plan files are retired from active docs.
- GitOps-only reconciliation remains mandatory.

## 9) Tracking Checklist and Next Actions

Tracking checklist:

- [ ] Backup reliability validated with recent clean scheduled runs.
- [ ] Restore drill evidence attached/linked.
- [ ] Harbor migration job validated in non-prod-like dry run.
- [ ] Harbor maintenance window approved.
- [ ] Harbor cutover completed and validated.
- [ ] Old per-app DB resources decommissioned after safety window.

Next actions:

1. Treat this file as the only active CNPG centralized migration runbook.
2. Update Harbor plan references to point here for shared DB migration logic.
3. Keep app-specific details in app docs; keep shared procedure only here.
