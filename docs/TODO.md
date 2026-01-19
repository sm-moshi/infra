# Infrastructure TODO

**Last Updated:** 2026-01-19 08:05 UTC
**Status:** P2 In Progress 🔄 | Completed tasks moved to [done.md](done.md)

This document tracks active and planned infrastructure tasks. Completed work is archived in [done.md](done.md).

---

## 🔄 P2 High Priority Tasks (Current Focus)

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

## 🔨 P3 Medium Priority Tasks (This Month)

### Task 7: Deploy Semaphore

**Status:** ArgoCD Application enabled; pending first sync

**Prerequisites:** ✅ semaphore-postgres-auth created, ✅ semaphore role/database exist

**Tasks:**

- [ ] Review Semaphore values.yaml (TLS, auth, RBAC)
- [ ] Monitor first ArgoCD sync and verify pods start
- [ ] Test Semaphore web UI access
- [ ] Configure project/playbook integration

**Priority:** 🟢 **MEDIUM**

---

### Task 8: Deploy Kubescape Operator

**Status:** ArgoCD Application enabled; pending first sync

**Tasks:**

- [ ] Review Kubescape values.yaml (capabilities, runtime path)
- [ ] Monitor first ArgoCD sync and verify scan pods
- [ ] Integrate with monitoring (if observability restored)

**Priority:** 🟢 **MEDIUM**

---

### Task 9: Evaluate Trivy Operator Deployment

**Status:** ArgoCD Application enabled; pending first sync

**Update:** Trivy Operator pinned to aquasec/trivy v0.68.2

**Context:** HarborGuard disabled due to bugs - Trivy Operator may be more suitable for runtime scanning

**Scanning Strategy:**

- Harbor built-in Trivy: Registry image scanning (pre-deployment) ✅ Active
- Trivy Operator: In-cluster workload scanning (runtime) 🔄 Under evaluation

**Tasks:**

- [ ] Confirm namespace and operator pods healthy
- [ ] Assess resource overhead (scan jobs + node collectors)
- [ ] Decide: Keep enabled or archive?

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

### Task 13: Traefik Security Headers

**Objective:** Add security headers via Traefik middleware

**Tasks:**

- [ ] Create Traefik Middleware for security headers:
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options: DENY
- [ ] X-XSS-Protection: 1; mode=block
- [ ] Strict-Transport-Security: max-age=31536000
- [ ] Apply to all IngressRoutes via Traefik annotations
- [ ] Test with <https://securityheaders.com>

**Priority:** 🔵 **LOW**

---

### Task 14: Expand Terraform to Additional Nodes

**Current Scope:** Only `terraform/envs/lab/` active

**Tasks:**

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
- ✅ Removed obsolete observability charts (kube-prometheus-stack, prometheus-crds, netdata, argus)
- ✅ Enabled ArgoCD Applications for Semaphore, Kubescape Operator, and Trivy Operator (pending sync)

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
2. Deploy harbor-build-user for K3s registry auth
3. Confirm Semaphore/Kubescape/Trivy Operator sync healthy in ArgoCD
4. Evaluate Trivy Operator (runtime scanning)

---

**Last Updated:** 2026-01-19 08:05 UTC
**Next Review:** After ArgoCD sync checks
