# Centralized CNPG (`cnpg-main`) Migration Plan (Multi-App)

Date: 2026-02-07

## Goal

Move application databases onto a single CloudNativePG cluster (`cnpg-main`) in namespace `apps`, with redundancy (1 replica: 2 instances total), while preserving data.

Target apps (in order of risk/importance):

1. Harbor (highest risk: registry metadata consistency)
2. Authentik
3. NetBox
4. Later: Semaphore, Gitea, HarborGuard

## Non-Goals

- Zero downtime for every app (some cutovers require brief write pause/restart).
- Imperative cluster mutation outside GitOps (all changes go through Git + ArgoCD).

## Constraints / Safety

- GitOps-only: all workload changes via Git -> ArgoCD -> cluster.
- No plaintext secrets in Git. Use existing SealedSecrets for DB creds.
- Avoid depending on Harbor registry for migration tooling images (Harbor may be part of the migration). Use `dhi.io/*` directly with `imagePullSecrets`.
- ResourceQuota headroom: migration and `init-roles` Jobs must not inherit large default `LimitRange` limits that can blow the `apps` quota.

## Preflight (Must Pass)

1. `cnpg-main` healthy and HA:
   - `instances: 2` (primary + 1 replica).
   - replication and failover conditions healthy.
2. Backups:
   - Scheduled backups for `cnpg-main` are succeeding.
   - Restore drill exists (documented procedure + last known good backup).
3. MinIO/S3:
   - Buckets exist and are reachable from `apps` namespace.
   - CA bundle / TLS trust is correct (avoid intermittent EOF-like failures).
4. Quotas:
   - `apps` namespace memory quota has headroom.
   - Any hook/migration job uses explicit low `resources` (requests/limits).

## Approach Summary

For each app DB:

1. Provision role + database on `cnpg-main` (via `init-roles` job driven by Helm values).
2. Snapshot / export from the source DB (per-app CNPG cluster or legacy DB) using a GitOps-managed one-off `Job`:
   - Use `pg_dump` (custom format) to S3 (preferred) or to a PVC.
3. Import into `cnpg-main` using a second GitOps-managed one-off `Job`:
   - Use `pg_restore` into the target database.
4. Cutover the application:
   - Update the app’s `values.yaml` to point at `cnpg-main-rw.apps.svc.cluster.local:5432` and the new secret.
   - Sync the app and validate.
5. Keep the old DB cluster for a defined safety window.
6. Decommission the old DB cluster (only after validation + safety window).

## Image Policy For Migration Jobs

Do not use `harbor.m0sh1.cc/...` as the image source for migration tooling.

Use:

- `dhi.io/postgres:18.1-debian13@sha256:086748e4e33806af10483b2dd4bc287d7102a8cc3d11d73f5cad9886c02f3b87`
- `imagePullSecrets: [{ name: kubernetes-dhi }]`

Rationale: Harbor may be disrupted during Harbor’s own DB cutover; migration jobs must still be able to pull images.

## Harbor-Specific Notes (Do Not Skip)

Harbor metadata is stored in Postgres; registry blobs are stored separately (PVC/S3). If the DB content is lost or inconsistent, Harbor can no longer associate blobs with repositories/tags (blobs may still exist, but “invisible” to Harbor).

To reduce risk:

- Prefer a short write freeze during the final export:
  - Put Harbor into maintenance/read-only mode if supported by the chart, or scale down write-heavy components briefly for a consistent dump.
- Validate after restore:
  - Core API health, UI login, project listing, repository listing.
  - `harbor-registry` still has access to the same storage backend (do not move registry storage as part of this DB migration).

## Phased Implementation (High Level)

### Phase 0: Prepare `cnpg-main` as Shared Service

1. Ensure `cnpg-main` `instances: 2`.
2. In `apps/cluster/cloudnative-pg/values.yaml`:
   - Enable roles for apps that will be migrated first (Harbor/Auth/NetBox).
   - Enable databases for those apps.
3. Ensure `init-roles` job has explicit low `resources` and uses DHI `psqlImage` + `imagePullSecrets`.

### Phase 1: Build Repeatable Dump/Restore Jobs (GitOps)

Implement a generic pattern per app (or parameterized template) that:

- Connects to the *source* DB (old cluster service + secret).
- Writes a dump to S3 (bucket path includes app name + timestamp).
- Connects to the *target* DB (`cnpg-main-rw`) and restores.

Notes:

- Store dumps in S3 to avoid large PVC management.
- Use `--no-owner`/`--no-privileges` for restore unless you explicitly want them.
- Make the restore idempotent by:
  - Restoring into an empty DB, or
  - Dropping/recreating schema (requires downtime / app stopped).

### Phase 2: Migrate Lower-Risk Apps First (Authentik, NetBox)

For each app:

1. Run dump Job (Git -> ArgoCD sync).
2. Run restore Job (Git -> ArgoCD sync).
3. Cutover app values to point at `cnpg-main`.
4. Validate (log in, run typical queries, check app-specific migrations/health checks).

### Phase 3: Migrate Harbor

1. Ensure Harbor has at least 2 running core pods before cutover (availability).
2. Freeze writes briefly for consistent dump (maintenance/read-only or scale-down write path).
3. Dump -> Restore -> Cutover.
4. Validate repositories/projects/tags, plus registry push/pull end-to-end.
5. Keep old harbor DB cluster intact for rollback window.

### Phase 4: Decommission Old Per-App DB Clusters (After Safety Window)

1. Mark old DB clusters `enabled: false` in their wrapper charts.
2. Ensure reclaim policies retain PVs until you explicitly clean up.
3. Document exact rollback steps and the date you consider the migration final.

## Rollback Strategy

Rollback is “switch app back to old DB endpoint” provided:

- Old DB cluster was not modified post-cutover, or
- You accept losing writes since cutover.

For Harbor, treat rollback as a high-risk operation: confirm write freeze, and document the exact service/secret to revert to.

## Open Questions (Need Answers Before Execution)

1. Source DB locations per app:
   - Which per-app CNPG clusters exist today for Harbor/Auth/NetBox (names + services)?
2. Desired downtime budget per app:
   - “Never down” generally still implies a minimal maintenance window for safe DB cutover. Confirm acceptable cutover window.
3. S3 bucket paths and retention policy for dumps:
   - Use a separate prefix from continuous WAL backups to avoid confusion.
