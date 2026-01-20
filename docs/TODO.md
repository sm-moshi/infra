# Infrastructure TODO

**Last Updated:** 2026-01-20 05:40 UTC
**Status:** P2 In Progress 🔄 | Completed tasks moved to [done.md](done.md)

This document tracks active and planned infrastructure tasks. Completed work is archived in [done.md](done.md).

---

## 🔨 P3 Medium Priority Tasks (This Month)

### Task 12: Deploy NetBox IPAM/DCIM

**Status:** Planning Complete (Ready for Implementation)

**Plan:** [docs/netbox-deployment-plan.md](netbox-deployment-plan.md)

**Tasks:**

- [ ] Phase 1: Prerequisites & CNPG Config (DB, S3, Secrets)
- [ ] Phase 2: Create Wrapper Chart (apps/user/netbox)
- [ ] Phase 3: Create SealedSecrets
- [ ] Phase 4: ArgoCD Application & Deployment
- [ ] Phase 5: Verification (Login, Object Storage, HA)

**Priority:** 🟢 **MEDIUM**

---

### Task 8: Deploy Kubescape Operator

**Status:** Completed ✅

**Tasks:**

- [x] Review Kubescape values.yaml (capabilities, runtime path)
- [x] Monitor first ArgoCD sync and verify scan pods
- [x] Integrate with monitoring (Deferred until observability stack restored)

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

### Task 18: Resolve ArgoCD Degraded Apps

**Status:** In Progress 🔄

**Objective:** Restore healthy/synced status for core apps flagged Degraded/OutOfSync.

**Apps:**

- Gitea (Degraded)
- CloudNative-PG (Degraded/OutOfSync)
- Harbor (Degraded/OutOfSync)

**Tasks:**

- [ ] Identify root cause for Gitea Degraded status (orphaned resources/health checks)
- [ ] Resolve CNPG webhook TLS error (webhook CA vs serving cert mismatch)
- [ ] Verify cnpg-webhook-cert fingerprint matches webhook caBundle
- [ ] Re-sync CNPG and confirm cnpg-main is Synced
- [ ] Re-sync Harbor and confirm harbor-postgres is Synced
- [ ] Confirm all three apps return to Healthy/Synced

**Priority:** 🔴 **HIGH**

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

### Task 17: Workload Security Hardening

**Status:** In Progress 🔄

**Objective:** Remediate high-severity findings from Kubescape/Trivy (Security Contexts)

**Tasks:**

- [ ] Gitea: Enforce `readOnlyRootFilesystem`, `runAsNonRoot`, drop capabilities (ArgoCD Degraded)
- [ ] Harbor: Investigate and apply `securityContext` hardening (Bitnami or official)
- [ ] Traefik: Evaluate hardened images (`rapidfort/traefik` vs official) - *Blocked by Docker Auth*
- [ ] NetworkPolicy: Implement default-deny for `apps` namespace (See Task 11)

---

### Task 19: Clean up Crashloops and Test Pods

**Status:** Pending

**Objective:** Reduce noise from non-production pods and abandoned runners.

**Tasks:**

- [ ] Disable or scale down semaphore runners (CrashLoopBackOff)
- [ ] Remove or fix `dhi-test` ImagePullBackOff in `default`

**Priority:** 🟢 **MEDIUM**

**Priority:** 🟢 **MEDIUM**

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
- ✅ Ansible hardening pass: swapfile idempotency, k3s taints/labels, zfs_arc runtime update, tailscale router templating

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
2. Confirm Semaphore/Kubescape/Trivy Operator sync healthy in ArgoCD
3. Evaluate Trivy Operator (runtime scanning)

---

**Last Updated:** 2026-01-19 09:00 UTC
**Next Review:** After ArgoCD sync checks
