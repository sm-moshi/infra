# Infrastructure TODO

**Last Updated:** 2026-01-19 01:15 UTC
**Status:** P2 In Progress 🔄 | Completed tasks moved to [done.md](done.md)

This document tracks active and planned infrastructure tasks. Completed work is archived in [done.md](done.md).

---

## 🔄 P2 High Priority Tasks (Current Focus)

### Task 1: Sync Out-of-Sync ArgoCD Applications

**Status:** Namespace cleanup complete, MinIO StorageClass fixed, waiting for ArgoCD auto-sync

**Current State:**

- cloudnative-pg: ✅ Synced / Healthy (revision 7542f8c)
- namespaces: ✅ Synced / Healthy (namespace cleanup resolved)
- harbor: OutOfSync / Healthy (orphaned resources from deleted namespaces)
- minio: OutOfSync / Healthy (fixed StorageClass drift in commit 28d4e67)

**Completed:**

- ✅ Deleted kubescape namespace (removed stale kubescape CRDs)
- ✅ Deleted observability namespace (patched Alloy finalizers)
- ✅ Fixed MinIO PVC StorageClass immutability (reverted to proxmox-csi-zfs-minio-retain)

**Remaining Tasks:**

- [ ] Wait for ArgoCD to auto-sync harbor and minio (orphaned resource warnings should clear)
- [ ] Verify all applications reach Synced/Healthy

**Priority:** 🟡 **HIGH** - Issues identified and fixed, waiting for ArgoCD reconciliation

---

### ✅ Task 2: Enable Gitea Deployment (COMPLETE)

**Status:** ✅ Gitea deployed, running, and healthy with clean reinstall

**Completed Actions:**

- ✅ Rotated all 5 SealedSecrets (admin, db, secrets, redis, runner)
- ✅ Wiped PVC and recreated fresh persistent storage (10Gi)
- ✅ Dropped and recreated gitea PostgreSQL database
- ✅ Fixed CNPG init-roles Job to sync role passwords on secret rotation
- ✅ Worked around ArgoCD CRD annotation size limit (kubectl server-side apply)
- ✅ Enabled gitea-runner with DinD sidecar (2/2 Running)
- ✅ Connected to external Valkey for session/cache/queue
- ✅ Configured Harbor registry integration for runner
- ✅ Gitea pod Running 1/1, health check passing
- ✅ Runner registered successfully with labels: [alpine, self-hosted]

**Current State:**

- Gitea: <https://git.m0sh1.cc> (web UI access pending verification)
- Pod: gitea-7dbd8767b8-d47vs (Running 1/1)
- Runner: gitea-gitea-runner-5946779cb9-kt8s9 (Running 2/2)
- Database: Fresh gitea database in cnpg-main cluster
- Cache: Connected to valkey.apps.svc:6379
- ArgoCD: Synced (Degraded status due to 126 orphaned resources warning - cosmetic)

**Remaining:** Test web UI access and admin login

**Priority:** ✅ **COMPLETE** - Gitea operational with CI/CD capability

---

### ✅ Task 3: Clean Up Terminating Namespaces (COMPLETE)

**Status:** ✅ Both namespaces successfully deleted

**Completed Actions:**

- ✅ Deleted kubescape namespace
  - Removed stale API discovery (spdx.softwarecomposition.kubescape.io/v1beta1)
  - Deleted remaining kubescape CRDs (operatorcommands, rules, runtimerulealertbindings, servicesscanresults)
- ✅ Deleted observability namespace
  - Patched finalizers on 2 Alloy resources (alloy-alloy-logs, alloy-alloy-singleton)
  - Patched finalizer on alloy-alloy-operator deployment
  - Used finalize API to force completion

**Result:** Both namespaces successfully removed, resolved orphaned resources in ArgoCD applications

---

### Task 4: Verify CNPG Scheduled Backups

**Status:** ✅ WAL archiving confirmed working, scheduled backups configured

**Tasks:**

- [ ] Verify ScheduledBackup resource exists: `kubectl get scheduledbackup -n apps`
- [ ] Check for completed backups: `kubectl get backups -n apps`
- [ ] Wait for first scheduled backup (daily 2 AM UTC)
- [ ] Verify backup appears in MinIO s3://cnpg-backups/

**Priority:** 🟢 **MEDIUM** - Monitoring task, continuous archiving already working

---

### Task 5: Deploy harbor-build-user SealedSecret

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

**Priority:** 🟢 **MEDIUM** - Enables Harbor integration for K3s nodes

---

### Task 6: HarborGuard Evaluation (Deferred)

**Status:** ⏸️ Disabled due to stability issues

**Decision:** HarborGuard removed from active deployment - too buggy and unreliable

**Completed:**

- ✅ Moved `argocd/apps/user/harborguard.yaml` → `argocd/disabled/user/harborguard.yaml`
- ✅ ArgoCD will prune HarborGuard resources automatically

**Rationale:**

- HarborGuard experiencing persistent bugs affecting functionality
- Harbor's built-in Trivy scanner provides baseline security scanning
- Can revisit HarborGuard when stability improves or consider alternatives

**Alternatives:**

- Harbor built-in Trivy integration (already active)
- Trivy Operator for in-cluster runtime scanning (Task 7)
- Manual scanning workflows via CI/CD

**Priority:** ⏸️ **DEFERRED** - Wrapper chart preserved in apps/user/harborguard/ for future evaluation

---

## 🔨 P3 Medium Priority Tasks (This Month)

### Task 7: Deploy Semaphore

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

### Task 8: Deploy Kubescape Operator

**Status:** Wrapper chart exists in apps/cluster/kubescape-operator/, not deployed

**Tasks:**

- [ ] Review Kubescape values.yaml (scan schedules, compliance frameworks)
- [ ] Create ArgoCD Application: `argocd/apps/cluster/kubescape-operator.yaml`
- [ ] Deploy and verify scan pods
- [ ] Integrate with monitoring (if observability restored)

**Priority:** 🟢 **MEDIUM**

---

### Task 9: Evaluate Trivy Operator Deployment

**Status:** Trivy Operator exists but disabled (apps/cluster/trivy-operator/)

**Update:** Trivy Operator pinned to aquasec/trivy v0.68.2

**Context:** HarborGuard disabled due to bugs - Trivy Operator may be more suitable for runtime scanning

**Scanning Strategy:**

- Harbor built-in Trivy: Registry image scanning (pre-deployment) ✅ Active
- Trivy Operator: In-cluster workload scanning (runtime) 🔄 Under evaluation

**Tasks:**

- [ ] Assess value of in-cluster runtime scanning
- [ ] Review resource overhead (Trivy scans ALL pods)
- [ ] Decide: Enable or archive?
- [ ] If enabling: Create ArgoCD Application
- [ ] If archiving: Move to archive/trivy-operator/

**Priority:** 🟢 **MEDIUM** - Higher priority now that HarborGuard is disabled

---

### Task 10: Implement ArgoCD Project Boundaries

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

### Task 11: NetworkPolicy Baseline

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

### Task 12: Delete Obsolete Observability Apps

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

### Task 13: Traefik Security Headers

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

### Task 14: Expand Terraform to Additional Nodes

**Current Scope:** Only `terraform/envs/lab/` active

**Future Expansion:**

- [ ] Add pve-02 VM/LXC management
- [ ] Add pve-01 VM/LXC management (if needed)
- [ ] Consider separate Terraform workspaces per node
- [ ] Document Terraform usage in docs/

**Priority:** 🔵 **LOW**

---

### Task 15: Deploy Kiwix Server (Offline Wikipedia)

**Status:** Not started - requires Docker OCI to Helm conversion

**Objective:** Deploy Kiwix Server for offline access to Wikipedia and other content

**Resources:**

- Docker image: ghcr.io/kiwix/kiwix-tools or ghcr.io/kiwix/kiwix-serve
- Docs: <https://github.com/kiwix/kiwix-tools/blob/main/docker/README.md>
- Guide: <https://thehomelab.wiki/books/docker/page/setup-and-install-kiwix-serve-on-debian-systems>

**Tasks:**

- [ ] Create Helm wrapper chart from Docker OCI image
- [ ] Configure PVC for ZIM file storage
- [ ] Create IngressRoute for external access
- [ ] Download ZIM files (Wikipedia, Stack Overflow, etc.)
- [ ] Test web interface

**Priority:** 🔵 **LOW** - Nice-to-have for offline knowledge base

---

### Task 16: Evaluate Logging Stack (Optional)

**Status:** Not started - marked as "if needed" in Phase 4

**Objective:** Decide if logging stack (Loki/Promtail/Grafana) should be reintroduced

**Decision Criteria:**

- Do we need centralized log aggregation?
- Is `kubectl logs` sufficient for current scale?
- Resource overhead vs. benefit

**Tasks (if proceeding):**

- [ ] Design lightweight logging architecture
- [ ] Create Loki wrapper chart
- [ ] Create Promtail wrapper chart
- [ ] Configure log retention and storage
- [ ] Create Grafana dashboards for log exploration
- [ ] Document logging strategy in docs/

**Priority:** 🔵 **LOW** - Optional enhancement, `kubectl logs` currently sufficient

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

## 🎯 Recent Progress

### 2026-01-19 Session

**Completed:**

- ✅ Gitea clean reinstall with rotated secrets (admin, db, secrets, redis, runner)
- ✅ Wiped Gitea PVC and database for fresh start
- ✅ Fixed CNPG password synchronization (init-roles Job now updates passwords)
- ✅ Worked around ArgoCD CRD annotation limit (kubectl server-side apply)
- ✅ Enabled gitea-runner with DinD sidecar (Harbor registry integration)
- ✅ Connected Gitea to external Valkey (cluster-wide, not bundled)
- ✅ Verified all components healthy (Gitea 1/1, Runner 2/2, Valkey connected)
- ✅ Disabled HarborGuard due to stability issues (moved to argocd/disabled/)

**Commits:** 690cd3d, b404985, [current session]

### 2026-01-18 Session

**Completed:**

- ✅ All P0 critical blockers resolved (database secrets, PVC resize, init-roles Job)
- ✅ MinIO object storage deployed on timemachine HDD pool
- ✅ CNPG PITR backups configured with 30-day retention
- ✅ Scheduled daily backups at 2 AM
- ✅ Fixed helm_scaffold.py ArgoCD path bug
- ✅ Fixed proxmox-csi StorageClass for HDD storage (ssd: false)

**Commits:** ded4976, 27225b7, c1c72dd, c3dcf5f, 6f28330, 0350154

**Next Immediate Steps:**

1. Test Gitea web UI access (<https://git.m0sh1.cc>)
2. Verify CNPG PITR backups
3. Deploy harbor-build-user for K3s registry auth
4. Wait for ArgoCD auto-sync (harbor/minio orphaned resources)

---

**Last Updated:** 2026-01-19 01:15 UTC
**Next Review:** After Gitea web UI testing
