# Infrastructure Completed Tasks

**Last Updated:** 2026-01-19 06:00 UTC

This document tracks completed infrastructure work that has been verified and is operational.

---

## ✅ COMPLETED - P0 Critical Issues (2026-01-18)

### ✅ Issue 1: Missing Database Secrets & CNPG init-roles Job

**Resolution:** All PostgreSQL roles and databases already existed. Disabled init-roles Job to eliminate authentication blocker.

**Completed Actions:**

1. ✅ Created `gitea-db-secret` SealedSecret (apps/user/gitea/templates/)
2. ✅ Created `semaphore-postgres-auth` SealedSecret (apps/user/semaphore/templates/)
3. ✅ Verified existing PostgreSQL state:
   - Roles: harbor, harborguard, semaphore, gitea ✓
   - Databases: harbor, harborguard, semaphore, gitea ✓
4. ✅ Disabled all roles in CNPG values.yaml to prevent Job creation
5. ✅ Deleted stuck init-roles Job
6. ✅ CNPG cluster healthy: "Cluster in healthy state"

**Commits:** ded4976, 27225b7, c1c72dd, c3dcf5f

---

### ✅ Issue 2: HarborGuard PVC Resize Conflict

**Resolution:** Updated harborguard values.yaml persistence.size to 50Gi (matches provisioned capacity)

**Completed Actions:**

1. ✅ Fixed harborguard/values.yaml: persistence.size: 20Gi → 50Gi
2. ✅ Bumped harborguard Chart.yaml version to 0.2.0
3. ✅ Committed and pushed changes

**Commits:** ded4976

---

## ✅ COMPLETED - P1 High Priority (2026-01-18 → 2026-01-19)

### ✅ Task 2: Deploy MinIO Object Storage

**Resolution:** MinIO v5.4.0 deployed with timemachine HDD storage for S3-compatible object storage

**Completed Actions:**

1. ✅ Created proxmox-csi StorageClass for timemachine pool (ssd: false for HDD)
2. ✅ Created MinIO wrapper chart (apps/cluster/minio/)
   - Upstream chart v5.4.0 (app: RELEASE.2024-12-18T13-15-44Z)
   - Standalone mode, 100Gi initial allocation
   - Node affinity prefers pve-01 (timemachine pool location)
3. ✅ Created minio-root-credentials SealedSecret
4. ✅ Created ArgoCD Application (argocd/apps/cluster/minio.yaml)
5. ✅ Configured default buckets: cnpg-backups, k8s-backups
6. ✅ Tuned probes for HDD latency (120s initial, 30s period)

**Commits:** 6f28330

**Completed:** Created IAM user `cnpg-backup` and attached bucket policy

---

### ✅ Task 4: Configure CNPG Point-in-Time Recovery

**Resolution:** CNPG configured with MinIO S3 backend for automated PITR backups

**Initial Configuration (2026-01-18):**

1. ✅ Created cnpg-backup-credentials SealedSecret (apps namespace)
2. ✅ Updated cloudnative-pg cluster template with barmanObjectStore support
3. ✅ Configured backup settings:
   - Endpoint: <http://minio.minio.svc:9000>
   - Destination: s3://cnpg-backups/
   - Retention: 30 days
   - WAL compression: gzip
4. ✅ Created ScheduledBackup resource (daily at 2 AM, sync wave 15)
5. ✅ Bumped chart version: 0.2.22 → 0.2.23

**Commits:** 0350154

**Critical Fixes (2026-01-19):**

1. ✅ Fixed WAL archiving credentials:
   - Issue: SealedSecret sealed with incorrect cluster cert, controller couldn't decrypt
   - Resolution: Fetched correct sealed-secrets cert, re-sealed cnpg-backup-credentials
   - Result: Secret successfully unsealed, MinIO credentials now valid
2. ✅ Fixed init-roles Job template logic:
   - Issue: Job created even when all roles had `enabled: false`
   - Resolution: Added filtering to only create Job when enabled roles exist
   - Result: No more unnecessary Job creation
3. ✅ Fixed Cluster managed.roles validation:
   - Issue: Template rendered `roles: null` causing validation error
   - Resolution: Filter enabled roles before rendering managed block
   - Result: Cluster spec valid, no null arrays
4. ✅ Fixed ArgoCD CRD sync errors:
   - Issue: poolers.postgresql.cnpg.io annotations too long (>262KB)
   - Resolution: Removed kubectl.kubernetes.io/last-applied-configuration from all CNPG CRDs
   - Result: ServerSideApply working, application synced

**Final Status (2026-01-19):**

- Continuous archiving: ✅ Working ("ContinuousArchivingSuccess")
- ArgoCD sync: ✅ Synced on revision 7542f8c
- Health: ✅ Healthy
- Chart version: 0.2.24

**Commits:** 699c5f1, df4eee1, 7542f8c

**Outcome:** ✅ CNPG PITR backups fully operational with WAL archiving confirmed working
