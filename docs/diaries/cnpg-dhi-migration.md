# CNPG DHI Migration Plan

**Date:** 2026-02-05
**Status:** In progress (Phase 1 done; Phase 2 plugin done; operator pending)
**Scope:** Use DHI where it is safe/compatible (helper Jobs first), then migrate
CNPG operator + plugins to DHI. Do not break the running CNPG cluster.

## Goal

Increase supply-chain hardening by using Docker Hardened Images (DHI) where
possible, while keeping CNPG functional and GitOps-aligned.

This is a GitOps-only change: Git -> ArgoCD -> Cluster. No imperative Helm or
kubectl apply/upgrade steps.

## Current Reality (Live Cluster)

- CNPG Cluster: `cnpg-main` in namespace `apps`
- Current CNPG operand image: `ghcr.io/cloudnative-pg/postgresql:18.1-system-trixie`
- Cluster security context runs Postgres as UID/GID 26 (CNPG default)
- Backups: Barman Cloud plugin -> MinIO tenant over HTTPS

## Proposed Change

### Phase 1 (Safe): DHI for `psql` helper Jobs + explicit MinIO CA trust

CNPG clusters require the upstream CNPG Postgres images (`cloudnative-pg/postgresql:*`)
because they include CNPG manager bits. The plain DHI Postgres image is not a
drop-in replacement for `Cluster.spec.imageName`.

Instead, we:

- Keep `Cluster.spec.imageName` as the CNPG operand image.
- Add `cnpg.cluster.psqlImage` for GitOps helper Jobs that only need `psql`
  (e.g. `init-roles-job.yaml`, future app db-init hooks).

Use DHI and pin by digest. We intentionally pull directly from `dhi.io` here,
so migrations do not depend on Harbor being available to pull the image (Harbor
may itself depend on cnpg-main during DB consolidation/migrations).

  - `dhi.io/postgres:18.1-debian13@sha256:086748e4e33806af10483b2dd4bc287d7102a8cc3d11d73f5cad9886c02f3b87`

- Pin MinIO CA trust explicitly in the ObjectStore via:

  - `endpointCA.name=minio-ca`
  - `endpointCA.key=ca.crt`

### Phase 2: CNPG operator + plugin images to DHI (after verifying chart overrides)

Once we confirm the chart override keys line up with the DHI image tags, switch.

Implemented now:

- Barman Cloud plugin images -> DHI tags:
  - `harbor.m0sh1.cc/dhi/cloudnative-pg-plugin-barman-cloud:0.11.0-debian13@sha256:447dfcd58bda0e4034d8331d03da749665e48778e2ea347f6ffcda1a3c1dc12d`
  - `harbor.m0sh1.cc/dhi/cloudnative-pg-plugin-barman-cloud-sidecar:0.11.0-debian13@sha256:1a193acad4f966386b31c49493a8e95176b48752f0b1b770aa1b8a5cae9f6b90`

- Wrapper dependency bump to keep chart appVersion aligned with plugin images:
  - `plugin-barman-cloud` chart `0.5.0` (appVersion `v0.11.0`)

Pending (blocked on image availability):

- CNPG operator image: chart `cloudnative-pg` `0.27.0` targets CNPG `1.28.0`,
  but `harbor.m0sh1.cc/dhi/cloudnative-pg:1.28.0-*` is not available yet. We
  should not downgrade the operator to `1.27.x` just to use DHI unless we
  explicitly decide to accept that risk.

Do not change `postgresUID/postgresGID` (26) as part of this work.

## Implementation (Repo Diffs)

1. Update wrapper chart values:
   - `apps/cluster/cloudnative-pg/values.yaml`
     - Keep `cnpg.cluster.imageName` as the upstream CNPG operand image.
     - Add `cnpg.cluster.psqlImage` (DHI Postgres, digest-pinned).
     - Add `cnpg.cluster.backup.endpointCA` pointing at `minio-ca` (`ca.crt`).
     - Configure `plugin-barman-cloud` images to use the Harbor DHI proxy cache.

2. Bump wrapper chart version (behavior change):
   - `apps/cluster/cloudnative-pg/Chart.yaml`

3. Update diary to match cluster reality:
   - `docs/diaries/cnpg-implementation.md`
     - MinIO endpoint is HTTPS `:443`, not HTTP `:80`.
     - Call out `endpointCA` trust wiring.

## Rollout (GitOps Execution)

1. Merge to `main`.
2. ArgoCD auto-syncs `argocd/Application cloudnative-pg` (sync-wave 23).
3. CNPG reconciles the Cluster. With `instances: 2` (primary + standby), it
   should avoid a hard outage, but expect some failover/connection churn during
   rolling changes.

## Post-Sync Validation (Read-only)

- ArgoCD:
  - `Application cloudnative-pg` is `Synced` and `Healthy`
  - The Argo Sync hook `Job/cnpg-main-init-roles` uses `dhi.io/postgres@sha256:0867...`
    (note: hook jobs are deleted on success via `HookSucceeded`)
  - `Cluster/cnpg-main` still uses `ghcr.io/cloudnative-pg/postgresql:18.1-system-trixie`

- CNPG:
  - `Cluster cnpg-main` condition `Ready=True`
  - Pod `cnpg-main-1` is `Running` and uses the CNPG operand image

- Backups:
  - `ScheduledBackup cnpg-main-backup` continues to succeed
  - Barman plugin can reach MinIO over HTTPS with `endpointCA` configured

## Rollback Plan

If the init-roles Job fails (image pull, crashloop):

1. Revert the commit that changed `cnpg.cluster.psqlImage` (or remove it).
2. Let ArgoCD resync.
3. Confirm the init-roles Job uses the cluster image again and completes.

## Follow-ups

- Implement Phase 2 (operator + plugin images) once we verify override keys for
  `cloudnative-pg` and `plugin-barman-cloud` charts.
