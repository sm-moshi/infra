# CNPG Centralized App DB Migration

**Date:** 2026-02-06
**Status:** In progress (Phase 1 done; Phase 2 mostly done; Phase 3 partially done; Phase 4 partially done)
**Scope:** Migrate application PostgreSQL databases to the shared CNPG cluster
`cnpg-main` (2 instances = 1 replica) without data loss, using GitOps-only
changes (Git -> ArgoCD -> Cluster).

Related:

- `docs/diaries/cnpg-implementation.md` (current CNPG + backups state)
- `docs/diaries/cnpg-dhi-migration.md` (DHI usage boundaries for CNPG)

## Goal

- One shared CloudNativePG cluster `cnpg-main` in namespace `apps`, configured
  with **2 instances** (primary + 1 replica) for redundancy.
- All application databases use `cnpg-main`:
  - Harbor
  - Authentik
  - NetBox
  - Gitea
  - HarborGuard
  - Later: Semaphore (+ anything else currently using per-app Postgres)
- Backups (WAL + base backups) keep working to MinIO (CNPG native `barmanObjectStore` to MinIO S3).
- Role/database provisioning is centralized and GitOps-managed.

## Current Implementation Status (As Of 2026-02-07)

- CNPG:
  - `Cluster/apps/cnpg-main`: **2 instances**, healthy.
  - Per-app Postgres clusters still exist where not cut over yet:
    - `Cluster/apps/harbor-postgres` still present and healthy.
- Provisioning:
  - Roles + databases exist on `cnpg-main` for:
    - `authentik`, `netbox`, `gitea`, `harbor`, `harborguard` (created centrally even if the app is not deployed yet).
- App cutovers:
  - Authentik: configured to use `cnpg-main` (`AUTHENTIK_POSTGRESQL__HOST=cnpg-main-rw.apps.svc.cluster.local`).
  - NetBox: configured to use `cnpg-main` (`externalDatabase.host=cnpg-main-rw.apps.svc.cluster.local`).
  - Harbor: **not cut over** yet (still points to `harbor-postgres-rw.apps.svc.cluster.local`).
  - Gitea + HarborGuard: not deployed in-cluster yet, but values are staged for `cnpg-main`.
- Migration jobs:
  - Harbor: `dbMigration` (disabled by default) exists and targets `harbor-postgres` -> `cnpg-main`.
  - Gitea: `migration` (disabled by default) exists and targets `gitea-postgresql` -> `cnpg-main`.
- Backups:
  - `ScheduledBackup/apps/cnpg-main-backup` exists and is configured with `method: barmanObjectStore`.
  - A one-off `barmanObjectStore` base backup was verified successful on 2026-02-07 (GitOps-triggered manual Backup CR; pruned afterwards).

## Non-Goals

- Zero-downtime migrations. These steps assume a maintenance window per app.
- Changing CNPG operand images to DHI. CNPG `Cluster.spec.imageName` must remain
  a CNPG operand image (see `docs/diaries/cnpg-dhi-migration.md`).

## Hard Constraints (Repo Rules)

- GitOps only: no imperative `helm install/upgrade` or `kubectl apply/patch`.
- No secrets in Git. Use SealedSecrets and existing secret reflection patterns.
- Do not introduce new top-level directories or restructure chart layout.

## Desired End State (High-Level)

1. `apps/cluster/cloudnative-pg`:
   - `cnpg-main` configured with `instances: 2`
   - init-roles Job provisions all required app roles + databases idempotently
2. Each app wrapper chart:
   - DB connection points to `cnpg-main` (via DNS)
   - Optional migration Job exists but is disabled by default

## DNS / Connection Convention

Assuming apps live in their own namespaces and CNPG cluster is in `apps`:

- Read/write service: `cnpg-main-rw.apps.svc.cluster.local`
- Read-only service: `cnpg-main-ro.apps.svc.cluster.local`

Keep this consistent across apps to reduce drift.

## Prerequisites (Before Any Cutover)

1. `cnpg-main` backups verified (manual `barmanObjectStore` backup completed on 2026-02-07; still recommended to observe at least one scheduled run).
2. MinIO CA trust is wired (`endpointCA`) and the cluster can reach MinIO over HTTPS.
3. The DHI pull secret (`kubernetes-dhi`) is present and reflected to relevant
   namespaces (for migration Jobs and DHI-based helpers).
4. For each app:
   - Password Secret exists (SealedSecret-managed) and matches the role name.
   - Target role and database are enabled in CNPG values (or staged but ready).

Note on `cnpg-main-superuser`:

- This secret is intentionally **not** stored as a SealedSecret in Git.
- CNPG generates it **in-cluster** when `enableSuperuserAccess: true`.
- Retrieve (do not paste into chat; treat as sensitive):
  - username: `kubectl -n apps get secret cnpg-main-superuser -o jsonpath='{.data.username}' | base64 -d`
  - password: `kubectl -n apps get secret cnpg-main-superuser -o jsonpath='{.data.password}' | base64 -d`

## Phase 0: Align CNPG Provisioning Model

The repo currently uses an init-roles Job because CNPG managed roles did not
reconcile reliably in the past.

Action items:

- Treat `apps/cluster/cloudnative-pg/values.yaml` as the source of truth for:
  - roles
  - databases
- Avoid mismatches like "role enabled but database disabled" unless intentionally
  staging a migration.

## Phase 1: Make `cnpg-main` HA (2 Instances)

Update CNPG cluster to run `instances: 2` (primary + 1 replica).

This is foundational. Do this before migrating any write-heavy apps.

Post-sync validation (read-only):

- `Cluster/cnpg-main` reports `Ready=True`
- two Pods exist for `cnpg-main` (one primary, one replica)
- scheduled backups still succeed

## Phase 2: Centralize Role + Database Provisioning

For each target app:

1. Enable the role entry under `roles` with `login: true` when the app needs to
   authenticate directly.
2. Enable the database entry under `databases` with the correct `owner`.
3. Ensure the password Secret name matches the existing secrets tree.

Recommendation:

- Stage Harbor last because it can be a dependency (registry/proxy cache) for
  other workloads.

## Phase 3: Add Per-App Migration Jobs (GitOps-Gated)

Each app that currently has a per-app Postgres (or any non-`cnpg-main` source)
should gain an optional migration Job template in its wrapper chart.

### Job behavior

- Disabled by default: `migration.enabled: false`
- When enabled, it:
  - `pg_dump` from the source DB
  - `pg_restore` into the target DB on `cnpg-main`
- Runs with explicit resource limits and a defined service account.

### Avoid re-creation loops (important)

A plain `Job` as a managed resource can be problematic (immutability; TTL +
ArgoCD re-creation). Prefer ArgoCD hook annotations so it runs once per sync:

- `argocd.argoproj.io/hook: Sync`
- `argocd.argoproj.io/hook-delete-policy: HookSucceeded,HookFailed`

The wrapper chart should only render this resource when `migration.enabled=true`.

### Migration tooling image policy (Harbor-sensitive)

For migration Jobs, **do not** default to pulling tooling images from Harbor.

Rationale:

- Harbor may be down/degraded during its own cutover.
- Using Harbor as the image source creates a circular dependency.

Default migration tooling image:

- `dhi.io/postgres:<ver>-debian13@sha256:<digest>`
- plus `imagePullSecrets: [kubernetes-dhi]`

## Phase 4: Per-App Cutover Procedure (Template)

Use this as the standard, repeatable runbook for each app.

### 1) Preparation (Git state)

- Ensure CNPG has role + database enabled for the app.
- Ensure app values support switching DB host/user/dbname/secret reference to
  `cnpg-main`.
- Ensure migration Job is present but still disabled.

### 2) Maintenance window (runtime)

Goal: prevent writes during `pg_dump` so the snapshot is consistent.

- Scale app down / disable ingress / put into maintenance mode (app-specific).
- Confirm source DB is reachable from the migration Job namespace.

### 3) Run migration Job (GitOps)

- Flip `migration.enabled: true` for the app wrapper chart values.
- Sync the app via ArgoCD (no `--prune` / no `--force`).
- Watch Job logs and ensure it completes successfully.
- Flip `migration.enabled: false` again after completion.

### 4) Switch the app to cnpg-main (GitOps)

- Update the app DB connection values to point at `cnpg-main-rw.apps.svc`.
- Sync the app via ArgoCD.

### 5) Post-cutover validation

- Application health checks pass (UI + API).
- DB connectivity works (login, migrations, background workers).
- Confirm the app sees its expected data.
- Confirm `cnpg-main` backups still succeed after the new DB load.

### 6) Rollback plan (per app)

Keep the old DB resources (PVCs) with `retain` policies until validated.

Rollback is:

- switch the app DB connection back to the old DB host
- resync

Do not delete the old DB cluster/storage until the app has been stable and
backups have been observed succeeding for at least one backup cycle.

## Harbor-Specific Notes (High Risk)

Harbor is sensitive to DB correctness because metadata drives UI visibility of
artifacts. The registry blobs may still exist, but the UI can appear empty if
metadata or related services are inconsistent.

Recommendations:

- Schedule Harbor migration as a dedicated maintenance window.
- Ensure no pushes/pulls are occurring during the snapshot.
- Do not pull migration tooling images from Harbor.
- Post-cutover verify:
  - projects, repositories, and tags appear
  - basic push/pull works
  - scan adapters still function (if enabled)

## Tracking (What We Expect to Change in Git)

At minimum:

- `apps/cluster/cloudnative-pg/values.yaml`
  - `cnpg.cluster.instances: 2`
  - enable roles + databases for target apps (staged rollout)
- `apps/user/<app>/values.yaml`
  - update DB connection to `cnpg-main`
  - add `migration.*` section
- `apps/user/<app>/templates/db-migration-job.yaml`
  - add gated migration Job (as hook)
- bump wrapper chart versions for any behavior changes

## Next Steps

1. Update `cnpg-main` to `instances: 2`.
2. Normalize role+database enablement for Authentik and NetBox first (low blast radius).
3. Implement Harbor migration Job + cutover switches (then migrate Harbor last).
