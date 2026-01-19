# Infrastructure TODO

**Last Updated:** 2026-01-19 06:00 UTC
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

### Task 2: Enable Gitea Deployment

**Status:** Gitea disabled in `argocd/disabled/user/gitea.yaml`, database secret now exists

**Prerequisites:** ✅ gitea-db-secret created, ✅ gitea role/database exist in PostgreSQL

**Tasks:**

- [ ] Move `argocd/disabled/user/gitea.yaml` → `argocd/apps/user/gitea.yaml`
- [ ] Verify ArgoCD detects and syncs Application
- [ ] Check Gitea pod starts successfully: `kubectl get pods -n apps -l app.kubernetes.io/name=gitea`
- [ ] Test Gitea web UI access (<https://gitea.m0sh1.cc>)
- [ ] Configure Gitea runner integration (if needed)

**Priority:** 🟡 **HIGH** - Database ready, secret exists, safe to enable

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

**Priority:** � **MEDIUM** - Enables Harbor integration for K3s nodes

---

## 🔨 P3 Medium Priority Tasks (This Month)

### Task 6: Deploy Semaphore

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

### Task 13: Deploy Kiwix Server (Offline Wikipedia)

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

### Task 14: Evaluate Logging Stack (Optional)

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
