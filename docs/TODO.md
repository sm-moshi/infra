# Infrastructure TODO (Revised)

**Generated:** 2026-01-18
**Updated:** 2026-01-18 22:30 UTC
**Status:** [MEMORY BANK: ACTIVE] - P0 Complete ✅ | P1 In Progress 🔄

This document consolidates actual infrastructure state against planning documents, with **CRITICAL ISSUES** identified and prioritized.

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

## ✅ COMPLETED - P1 High Priority (2026-01-18)

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

**Completed Actions:**

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

**Next:** Verify first backup succeeds and confirm WAL archiving

---

## 🔄 P1 High Priority Tasks (In Progress)

### Task 1: Enable Gitea Deployment

**Status:** Gitea disabled in `argocd/disabled/user/gitea.yaml`, database secret now exists

**Prerequisites:** ✅ gitea-db-secret created, ✅ gitea role/database exist in PostgreSQL

**Tasks:**

- [ ] Move `argocd/disabled/user/gitea.yaml` → `argocd/apps/user/gitea.yaml`
- [ ] Verify ArgoCD detects and syncs Application
- [ ] Check Gitea pod starts successfully: `kubectl get pods -n apps -l app.kubernetes.io/name=gitea`
- [ ] Test Gitea web UI access (<https://gitea.m0sh1.cc>)
- [ ] Configure Gitea runner integration (if needed)

**Priority:** 🟡 **HIGH**

---

### Task 2: Verify CNPG PITR Backups

**Status:** MinIO and CNPG PITR configured; confirm backups are running

**Tasks:**

- [ ] Verify scheduled backup runs: `kubectl get backups -n apps`
- [ ] Confirm WAL archiving: `kubectl logs -n apps cnpg-main-1 -c postgres | rg "archived"`

**Priority:** 🟡 **HIGH**

---

### Task 3: Deploy harbor-build-user SealedSecret

**Objective:** Enable K3s nodes to pull/push images to Harbor registry

**Location:** apps namespace

**Tasks:**

- [ ] Generate Harbor robot account credentials
- [ ] Create SealedSecret `harbor-build-user` (apps namespace)
- [ ] Update Ansible K3s roles to use secret:
  - `ansible/roles/k3s_control_plane/templates/registries.yaml.j2`
  - `ansible/roles/k3s_worker/templates/registries.yaml.j2`
- [ ] Re-run Ansible playbooks to apply K3s registry config
- [ ] Test image pull from Harbor: `kubectl run test --image=harbor.m0sh1.cc/library/nginx:latest`

**Priority:** 🟡 **HIGH**

---

## 🔨 P2 Medium Priority Tasks (This Month)

### Task 5: Deploy Semaphore

**Status:** Wrapper chart exists, database secret created, no ArgoCD Application

**Prerequisites:** ✅ semaphore-postgres-auth created, ✅ semaphore role/database exist

**Tasks:**

- [ ] Review Semaphore values.yaml (TLS, auth, RBAC)
- [ ] Create ArgoCD Application: `argocd/apps/user/semaphore.yaml`
- [ ] Deploy and verify pods start
- [ ] Test Semaphore web UI access
- [ ] Configure project/playbook integration

**Priority:** 🟢 **MEDIUM**

---

### Task 6: Deploy Kubescape Operator

**Status:** Wrapper chart exists in apps/cluster/kubescape-operator/, not deployed

**Tasks:**

- [ ] Review Kubescape values.yaml (scan schedules, compliance frameworks)
- [ ] Create ArgoCD Application: `argocd/apps/cluster/kubescape-operator.yaml`
- [ ] Deploy and verify scan pods
- [ ] Integrate with monitoring (if observability restored)

**Priority:** 🟢 **MEDIUM**

---

### Task 7: Evaluate Trivy Operator Deployment

**Status:** Trivy Operator exists but disabled (apps/cluster/trivy-operator/)

**Update:** Trivy Operator pinned to aquasec/trivy v0.68.2

**Decision Required:** Overlap with HarborGuard?

- HarborGuard: Registry image scanning (pre-deployment)
- Trivy Operator: In-cluster workload scanning (runtime)

**Tasks:**

- [ ] Assess value of dual scanning (registry + cluster)
- [ ] Review resource overhead (Trivy scans ALL pods)
- [ ] Decide: Enable or archive?
- [ ] If enabling: Create ArgoCD Application
- [ ] If archiving: Move to archive/trivy-operator/

**Priority:** 🟢 **MEDIUM**

---

### Task 8: Implement ArgoCD Project Boundaries

**Objective:** Isolate cluster apps from user apps via ArgoCD Projects

**Tasks:**

- [ ] Create ArgoCD Projects:
  - `cluster-project` (apps/cluster/*, namespaces: kube-system, argocd, traefik, sealed-secrets, etc.)
  - `user-project` (apps/user/*, namespace: apps only)
- [ ] Update Application manifests to reference projects
- [ ] Test: Ensure user apps cannot deploy to cluster namespaces
- [ ] Document project strategy in docs/

**Priority:** 🟢 **MEDIUM**

---

### Task 9: NetworkPolicy Baseline

**Objective:** Zero-trust networking between workloads

**Tasks:**

- [ ] Create default-deny NetworkPolicy for apps namespace
- [ ] Create allow-ingress-from-traefik policy
- [ ] Create allow-egress-to-cnpg policy
- [ ] Create allow-dns policy (coredns access)
- [ ] Test connectivity: `kubectl exec` tests between pods
- [ ] Document policy patterns in docs/

**Priority:** 🟢 **MEDIUM**

---

## 🧹 P3 Low Priority Tasks (Future)

### Task 10: Delete Obsolete Observability Apps

**Status:** Observability stack was supposed to be deleted

**Charts to Remove:**

- kube-prometheus-stack (apps/cluster/)
- prometheus-crds (apps/cluster/)
- netdata (apps/cluster/)
- argus (apps/user/)

**Tasks:**

- [ ] Backup Grafana dashboards (if any custom dashboards exist)
- [ ] Delete ArgoCD Applications (if they exist)
- [ ] Delete wrapper chart directories
- [ ] Clean up CRDs:
  - `kubectl delete crd prometheuses.monitoring.coreos.com`
  - `kubectl delete crd servicemonitors.monitoring.coreos.com`
  - (etc., all Prometheus Operator CRDs)
- [ ] Verify namespace cleanup
- [ ] Archive charts to archive/observability/ if needed for reference

**Priority:** 🔵 **LOW**

---

### Task 11: Traefik Security Headers

**Objective:** Add security headers via Traefik middleware

**Tasks:**

- [ ] Create Traefik Middleware for security headers:
  - X-Content-Type-Options: nosniff
  - X-Frame-Options: DENY
  - X-XSS-Protection: 1; mode=block
  - Strict-Transport-Security: max-age=31536000
- [ ] Apply to all IngressRoutes via Traefik annotations
- [ ] Test with <https://securityheaders.com>

**Priority:** 🔵 **LOW**

---

### Task 12: Expand Terraform to Additional Nodes

**Current Scope:** Only `terraform/envs/lab/` active

**Future Expansion:**

- [ ] Add pve-02 VM/LXC management
- [ ] Add pve-01 VM/LXC management (if needed)
- [ ] Consider separate Terraform workspaces per node
- [ ] Document Terraform usage in docs/

**Priority:** 🔵 **LOW**

---

## 📊 Priority Summary

### Immediate (This Week - P1)

1. ✅ Fix database secrets (COMPLETE)
2. ✅ Fix HarborGuard PVC (COMPLETE)
3. ✅ Deploy MinIO object storage (COMPLETE)
4. ✅ Configure CNPG PITR backups (COMPLETE - verify backups)
5. 🔄 Verify CNPG PITR backups
6. 🔄 Enable Gitea deployment
7. 🔄 Deploy harbor-build-user SealedSecret

### This Month (P2)

1. Deploy Semaphore
2. Deploy Kubescape Operator
3. Evaluate Trivy Operator
4. ArgoCD Project boundaries
5. NetworkPolicy baseline

### Future (P3)

1. Delete observability apps
2. Traefik security headers
3. Terraform expansion

---

## 📝 Notes

**CNPG Role Management:**

- All PostgreSQL roles/databases already exist (harbor, harborguard, semaphore, gitea)
- init-roles Job disabled (all roles set enabled: false in values.yaml)
- Jobs are unnecessary - roles were created by previous process
- If password rotation needed in future, re-enable specific role and update secret first

**Object Storage Strategy:**

- MinIO recommended over Rook-Ceph for homelab scale
- Single-node deployment on pve-01 timemachine pool (500GB HDD)
- No built-in replication - rely on ZFS underlying storage
- Suitable for CNPG backups, Loki logs, future object storage needs

**Security Posture:**

- All secrets managed via SealedSecrets (no plaintext in Git)
- Database credentials generated with `openssl rand -base64 32`
- TLS enforced for all database connections (sslmode=require)
- Future: NetworkPolicy for workload isolation

---

---

## 🎯 Recent Progress (2026-01-18 Session)

**Completed:**

- ✅ All P0 critical blockers resolved (database secrets, PVC resize, init-roles Job)
- ✅ MinIO object storage deployed on timemachine HDD pool
- ✅ CNPG PITR backups configured with 30-day retention
- ✅ Scheduled daily backups at 2 AM
- ✅ Fixed helm_scaffold.py ArgoCD path bug
- ✅ Fixed proxmox-csi StorageClass for HDD storage (ssd: false)

**Commits:** ded4976, 27225b7, c1c72dd, c3dcf5f, 6f28330, 0350154

**Next Immediate Steps:**

1. Verify CNPG PITR backups
2. Enable Gitea deployment
3. Deploy harbor-build-user for K3s registry auth

---

**Last Updated:** 2026-01-18 22:30 UTC
**Next Review:** After MinIO deployment completes
