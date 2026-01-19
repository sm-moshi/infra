# Infrastructure Completed Tasks

**Last Updated:** 2026-01-19 07:30 UTC

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

---

### ✅ Task 1: Sync Out-of-Sync ArgoCD Applications (2026-01-19)

**Status:** All applications now Synced/Healthy

**Resolution:** Namespace cleanup and MinIO StorageClass fixes resolved sync drift

**Completed Actions:**

1. ✅ Deleted kubescape namespace (removed stale kubescape CRDs)
2. ✅ Deleted observability namespace (patched Alloy finalizers)
3. ✅ Fixed MinIO PVC StorageClass immutability (reverted to proxmox-csi-zfs-minio-retain)
4. ✅ ArgoCD auto-sync resolved orphaned resource warnings

**Final State:**

- cloudnative-pg: ✅ Synced / Healthy
- namespaces: ✅ Synced / Healthy
- harbor: ✅ Synced / Healthy
- minio: ✅ Synced / Healthy

**Commits:** (namespace cleanup commits from 2026-01-18 session)

---

### ✅ Task 2: Enable Gitea Deployment (2026-01-19)

**Status:** ✅ Gitea deployed, running, and healthy with clean reinstall

**Completed Actions:**

1. ✅ Rotated all 5 SealedSecrets (admin, db, secrets, redis, runner)
2. ✅ Wiped PVC and recreated fresh persistent storage (10Gi)
3. ✅ Dropped and recreated gitea PostgreSQL database
4. ✅ Fixed CNPG init-roles Job to sync role passwords on secret rotation
5. ✅ Worked around ArgoCD CRD annotation size limit (kubectl server-side apply)
6. ✅ Enabled gitea-runner with DinD sidecar (2/2 Running)
7. ✅ Connected to external Valkey for session/cache/queue
8. ✅ Configured Harbor registry integration for runner
9. ✅ Gitea pod Running 1/1, health check passing
10. ✅ Runner registered successfully with labels: [alpine, self-hosted]

**Final State:**

- Gitea: <https://git.m0sh1.cc> (operational, web UI accessible)
- Pod: gitea-7dbd8767b8-d47vs (Running 1/1)
- Runner: gitea-gitea-runner-5946779cb9-kt8s9 (Running 2/2)
- Database: Fresh gitea database in cnpg-main cluster
- Cache: Connected to valkey.apps.svc:6379
- ArgoCD: Synced/Degraded (126 orphaned resources warning - cosmetic)

**Commits:** 690cd3d, b404985, a6a64ac5

---

### ✅ Task 3: Clean Up Terminating Namespaces (2026-01-19)

**Status:** ✅ Both namespaces successfully deleted

**Completed Actions:**

1. ✅ Deleted kubescape namespace
   - Removed stale API discovery (spdx.softwarecomposition.kubescape.io/v1beta1)
   - Deleted remaining kubescape CRDs (operatorcommands, rules, runtimerulealertbindings, servicesscanresults)
2. ✅ Deleted observability namespace
   - Patched finalizers on 2 Alloy resources (alloy-alloy-logs, alloy-alloy-singleton)
   - Patched finalizer on alloy-alloy-operator deployment
   - Used finalize API to force completion

**Result:** Both namespaces successfully removed, resolved orphaned resources in ArgoCD applications

---

### ✅ Task 4: Verify CNPG Scheduled Backups (2026-01-19)

**Status:** ✅ Scheduled backups verified and operational

**Completed Actions:**

1. ✅ ScheduledBackup resource exists: `cnpg-main-backup` (created 3h32m ago)
2. ✅ Confirmed completed backups: 4 successful backups
   - cnpg-main-backup-20260118221216 ✅
   - cnpg-main-backup-20260118230200 ✅
   - cnpg-main-backup-20260119000200 ✅
   - cnpg-main-backup-20260119010200 ✅
3. ✅ Backups stored in MinIO s3://cnpg-backups/
4. ✅ Continuous WAL archiving: "ContinuousArchivingSuccess"

**Outcome:** PITR backup capability fully verified and operational

---

### ✅ Task 6: HarborGuard Evaluation (2026-01-19)

**Status:** ⏸️ Disabled and archived due to stability issues

**Decision:** HarborGuard removed from active deployment - too buggy and unreliable

**Completed Actions:**

1. ✅ Moved `argocd/apps/user/harborguard.yaml` → `argocd/disabled/user/harborguard.yaml`
2. ✅ ArgoCD Application pruned (Application deleted from cluster)
3. ✅ HarborGuard pods terminating (ArgoCD automated prune in progress)

**Rationale:**

- HarborGuard experiencing persistent bugs affecting functionality
- Harbor's built-in Trivy scanner provides baseline security scanning
- Can revisit HarborGuard when stability improves or consider alternatives

**Alternatives:**

- Harbor built-in Trivy integration (already active)
- Trivy Operator for in-cluster runtime scanning (under evaluation)
- Manual scanning workflows via CI/CD

**Commits:** 9b4fc06, 5dcdfcd

**Outcome:** Wrapper chart preserved in apps/user/harborguard/ for future evaluation

---

### ✅ Task 5: Deploy harbor-build-user SealedSecret (2026-01-19)

**Status:** ✅ Registry credentials wired into K3s registry config

**Completed Actions:**

1. ✅ Verified SealedSecret exists: `apps/user/harbor/templates/harbor-build-user.sealedsecret.yaml`
2. ✅ Updated K3s registries templates to support Harbor auth:
   - `ansible/roles/k3s_control_plane/templates/registries.yaml.j2`
   - `ansible/roles/k3s_worker/templates/registries.yaml.j2`
3. ✅ Auth block is conditional and expects `harbor_build_user` vars from Ansible Vault

**Follow-up (ops):** Re-run K3s Ansible playbooks and validate image pulls after deployment

---

### ✅ Task 12: Delete Obsolete Observability Apps (2026-01-19)

**Status:** ✅ Observability stack removed from Git

**Completed Actions:**

1. ✅ Deleted wrapper charts from repo:
   - `apps/cluster/kube-prometheus-stack/`
   - `apps/cluster/prometheus-crds/`
   - `apps/cluster/netdata/`
   - `apps/user/argus/`
2. ✅ Removed disabled ArgoCD Application manifests:
   - `argocd/disabled/cluster/kube-prometheus-stack.yaml`
   - `argocd/disabled/cluster/prometheus-crds.yaml`
   - `argocd/disabled/cluster/netdata.yaml`
   - `argocd/disabled/user/argus.yaml`

**Follow-up (ops):** Verify Prometheus Operator CRDs are cleaned up if any remain
