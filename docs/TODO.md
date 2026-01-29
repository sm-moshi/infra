# Infrastructure TODO

**Last Updated:** 2026-01-29
**Status:** ArgoCD WebUI operational ✅ | MetalLB L2 working ✅ | Base cluster deployed ✅

This document tracks active and planned infrastructure tasks. Completed work is archived in [done.md](done.md).

**Current Focus:** Cloudflare Tunnel deployment → User app re-enablement → Proxmox CSI validation

## Phase Tracker (merged from checklist)

- Phase 0 — Repository Contract: ✅ complete (guardrails, layout, CI, storage audit, MinIO pool)
- Phase 1 — Infrastructure Deployment: 🔄 in progress (finish infra LXCs + bastion; AdGuard Home DNS; PBS/SMB Ansible rollout)
- Phase 2 — Storage Provisioning: ✅ complete (datasets + storage IDs + pvesm verification)
- Phase 3 — GitOps Bootstrap: ✅ complete (infra-root corrected, base apps deployed, sealed-secrets restored)
- Phase 4 — Validation & Operations: 🔄 ongoing (ArgoCD auto-sync fix, CSI PVC test, MinIO PVC, ingress validation, re-enable user apps)

---

## 🔥 P0 Critical Priority (Deployment Sequence)

### Task 21: Deploy Cloudflare Tunnel for External Access

**Status:** 🔄 Ready for Implementation - ArgoCD accessible, certificate warning present

**Objective:** Enable external HTTPS access to ArgoCD and other services with valid TLS certificates

**Estimated Time:** 30-45 minutes

**Benefits:**

- Fix certificate warning (`*.m0sh1.cc` covers only one level, not `*.lab.m0sh1.cc`)
- Enable secure external access without port forwarding
- Cloudflare terminates TLS with valid certificate
- Zero-trust architecture

**Tasks:**

- [ ] Create Cloudflare Zero Trust tunnel in dashboard
- [ ] Get tunnel token/credentials
- [ ] Create SealedSecret with tunnel token
- [ ] Create Helm wrapper chart in apps/cluster/cloudflared/
- [ ] Configure ingress routes (annotations or dashboard config)
- [ ] Create ArgoCD Application manifest
- [ ] Deploy and validate external access

**Architecture:**

```text
Internet → Cloudflare Edge (TLS) → Encrypted tunnel → cloudflared pod → ArgoCD service
```

**Priority:** 🔴 **HIGH** - Fixes certificate warning, enables external access

---

## 🔴 P1 Post-Deployment Tasks

### Phase 1 Remainders (Infrastructure Deployment)

**Status:** 🔄 Partially done

**Tasks:**

- [ ] Finish Terraform-driven infra LXCs (dns01, dns02, pbs, smb) and bastion VM
- [ ] Run Ansible for AdGuard Home DNS
- [ ] Complete Ansible rollout for PBS and SMB services

**Priority:** 🔴 **HIGH** - Blocks stable infra services

### Create Proxmox CSI Datasets

**Status:** Documented, execute after k3s bootstrap

**Tasks:**

- [ ] SSH to each Proxmox node (pve-01, pve-02, pve-03)
- [ ] Create nvme rpool datasets (pgdata 16K, pgwal 128K, registry 128K, caches 128K)
- [ ] Create sata-ssd MinIO datasets (sata-ssd/minio parent, sata-ssd/minio/data 1M recordsize)
- [ ] Configure Proxmox storage IDs (k8s-pgdata, k8s-pgwal, k8s-registry, k8s-caches, minio-data)
- [ ] Verify with `pvesm status | grep k8s`
- [ ] Enable Proxmox CSI ArgoCD Application
- [ ] Test PVC provisioning

**Reference:** [docs/diaries/proxmox-csi-setup.md](diaries/proxmox-csi-setup.md)

**Priority:** 🔴 **CRITICAL** - Must complete before app deployments

---

## 🔨 P2 Post-Bootstrap Tasks

### Task 12: Deploy NetBox IPAM/DCIM

**Status:** Planning Complete (Ready for Implementation)

**Plan:** [docs/diaries/netbox-deployment-plan.md](diaries/netbox-deployment-plan.md)

**Tasks:**

- [ ] Phase 1: Prerequisites & CNPG Config (DB, S3, Secrets)
- [ ] Phase 2: Create Wrapper Chart (apps/user/netbox)
- [ ] Phase 3: Create SealedSecrets
- [ ] Phase 4: ArgoCD Application & Deployment
- [ ] Phase 5: Verification (Login, Object Storage, HA)

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

### Task 18: Post-Deployment Health Monitoring

**Status:** ✅ Phase 4 Complete - ArgoCD WebUI Accessible | 🔄 Phase 5 - Re-enable User Apps

**Objective:** Ensure all applications reach Healthy/Synced status after GitOps bootstrap

**Completed Validation:**

- ✅ ArgoCD synced and self-managed via GitOps
- ✅ ArgoCD WebUI accessible from Mac at <https://argocd.lab.m0sh1.cc/> (HTTP 200)
- ✅ Dual-NIC deployment complete - all K8s nodes have VLAN 30 interfaces (10.0.30.50-54)
- ✅ Proxmox CSI plugin healthy (6 pods Running: controller + 5 node DaemonSets)
- ✅ StorageClasses created (6 total: local-path + 5 Proxmox CSI ZFS classes)
- ✅ MetalLB assigns 10.0.30.10 to Traefik (traefik-lan LoadBalancer) - WORKING after dual-NIC fix
- ✅ Traefik ingress accessible from Mac (curl returns HTTP 200)
- ✅ cert-manager Healthy - wildcard certificate issued (*.m0sh1.cc, m0sh1.cc)
- ✅ TLS secret created in traefik namespace (wildcard-m0sh1-cc)
- ✅ external-dns Healthy with fresh Cloudflare API token
- ✅ origin-ca-issuer Healthy with fresh Cloudflare API token
- ✅ sealed-secrets controller operational with restored keys
- ✅ DNS resolution working (internal k8s services + external domains)
- ✅ CoreDNS integrated with OPNsense Unbound (10.0.30.1)

**Known Issues:**

- ⚠️ Certificate warning - `*.m0sh1.cc` doesn't cover `*.lab.m0sh1.cc` (two-level subdomain)
  - **Fix:** Deploy Cloudflare Tunnel for external access with valid certificate
  - **Workaround:** Accept certificate warning in browser (internal-only access working)
- ⚠️ ArgoCD automated sync showing "Unknown" status for some apps
  - **Status:** Under investigation, manual sync works
  - **Impact:** Apps are Healthy, just sync mechanism needs troubleshooting

**Next Phase:**

- [ ] Troubleshoot ArgoCD automated sync (apps showing Unknown status)
- [ ] Deploy Cloudflare Tunnel (fix certificate warning + enable external access)
- [ ] Test Proxmox CSI provisioning with test PVC
- [ ] Re-enable user apps: CNPG → Valkey → Renovate → pgadmin4

**Priority:** 🟢 **MEDIUM** - Post-bootstrap validation complete, optimization phase

**Key Applications to Monitor:**

- ArgoCD (self-managed via GitOps)
- Proxmox CSI (StorageClass provisioning)
- MetalLB (LoadBalancer IP assignment)
- Traefik (Ingress controller)
- cert-manager (TLS certificate issuance)
- CloudNativePG (PostgreSQL clusters)
- Harbor (Container registry)
- Gitea (Git server with runner)
- MinIO (Object storage on sata-ssd)

**Tasks:**

- [ ] Monitor initial ArgoCD sync wave progression
- [ ] Verify StorageClasses created by Proxmox CSI
- [ ] Confirm MetalLB assigns 10.0.30.10 to Traefik
- [ ] Test ingress connectivity (*.lab.m0sh1.cc)
- [ ] Verify CNPG PostgreSQL clusters provision successfully
- [ ] Check MinIO buckets created (cnpg-backups, k8s-backups)
- [ ] Validate Harbor registry accessible
- [ ] Test Gitea runner functionality

**Priority:** 🔴 **HIGH** - Post-bootstrap validation

---

### Task 20: Fix Proxmox Cluster API Endpoint

**Status:** 🔴 CRITICAL - Blocks MinIO and all future PVC provisioning on sata-ssd pool

**Problem:** Proxmox CSI controller attempting to connect to 10.0.0.100:8006 (old cluster corosync VIP) which is unreachable from VLAN 20 (K8s nodes). CSI plugin config correctly specifies individual node IPs (10.0.10.11/12/13) but Proxmox cluster resources API requires cluster-level endpoint.

**Options:**

1. **Option A: Add DNS record** (Quick fix)
   - Create DNS A record: `pve-cluster.lab.m0sh1.cc` → 10.0.10.11 (or HAProxy VIP)
   - Update OPNsense firewall to allow VLAN 20 → VLAN 10 on port 8006
   - Verify CSI can reach Proxmox API from K8s nodes

2. **Option B: Reconfigure Proxmox corosync** (Proper fix)
   - Update corosync.conf ring addresses to use VLAN 10 (10.0.10.11/12/13)
   - Restart corosync service on all nodes
   - Update cluster resource manager configuration
   - **Risk:** Requires cluster restart, may cause brief downtime

3. **Option C: Use node-specific APIs only** (Workaround)
   - Modify CSI controller to bypass cluster API and use node APIs directly
   - **Issue:** May limit cross-node storage operations

**Recommendation:** Option A (DNS + firewall) for immediate unblock, plan Option B for next maintenance window

**Tasks:**

- [ ] Verify current Proxmox cluster corosync configuration (`pvecm status`)
- [ ] Check firewall rules: VLAN 20 → VLAN 10 port 8006
- [ ] Option A: Add DNS record and test CSI connectivity
- [ ] Test MinIO PVC provisioning after fix
- [ ] Monitor CSI controller logs for errors

**Priority:** 🔴 **CRITICAL** - Blocks storage layer

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

---

## 📝 Deployment Notes

**Network Architecture:**

- VLAN 10 (10.0.10.0/24): Infrastructure (Proxmox, DNS, PBS, SMB, Bastion)
- VLAN 20 (10.0.20.0/24): Kubernetes nodes (labctrl, horse01-04)
- VLAN 30 (10.0.30.0/24): Service VIPs (MetalLB pool 10.0.30.10-49)
- OPNsense (.1 on each VLAN): Inter-VLAN routing and firewall

**Storage Architecture:**

- **nvme rpool** (fast storage): 472Gi allocated
  - pgdata (16K): PostgreSQL data - 245Gi
  - pgwal (128K): PostgreSQL WAL - 30Gi
  - registry (128K): Container images, git repos - 170Gi
  - caches (128K): Ephemeral/retained caches - 27Gi
- **sata-ssd pool** (128GB SSD per node): 50Gi allocated (39% utilization)
  - minio-data (1M): Object storage, CNPG backups - 50Gi

**MinIO Configuration:**

- Deployment: Standalone mode on sata-ssd pool
- Size: 50Gi (conservative start, expandable to ~70Gi)
- Buckets: cnpg-backups (PostgreSQL PITR), k8s-backups (general)
- ZFS: 1M recordsize, zstd compression, atime=off, redundant_metadata=most
- Scheduling: Node-agnostic (sata-ssd available on all nodes)

**Security Posture:**

- All secrets managed via SealedSecrets (no plaintext in Git)
- Database credentials generated with `openssl rand -base64 32`
- TLS enforced for all database connections (sslmode=require)
- Harbor registry mirrors optional during bootstrap (k3s_enable_harbor_mirrors: false)
- Future: NetworkPolicy for workload isolation

---

## 🎯 Recent Progress

### 2026-01-29 Session (Dual-NIC Deployment & ArgoCD Access)

**Completed:**

- ✅ Deployed dual-NIC configuration to all 5 K8s nodes (VLAN 30 secondary interfaces)
  - labctrl: 10.0.30.50/24
  - horse01-04: 10.0.30.51-54/24
- ✅ Fixed MetalLB L2 ARP limitation (speakers can now reach VLAN 30)
- ✅ Traefik LoadBalancer assigned 10.0.30.10 successfully
- ✅ **ArgoCD WebUI accessible from Mac** at <https://argocd.lab.m0sh1.cc/>
- ✅ HTTP 200 response, login page functional
- ✅ All base cluster apps deployed and operational (16 applications)
- ✅ Ansible playbook created: k3s-secondary-nic.yaml
- ✅ Fixed interface naming issue (ens19 vs eth1 altname)
- ✅ Fixed hostname mapping (labctrl vs lab-ctrl)
- ✅ Committed and pushed to Git (commit 921d8ff7)
- ✅ Certificate warning expected (`*.m0sh1.cc` vs `*.lab.m0sh1.cc`)

**Network Architecture Validated:**

- VLAN 20: K8s primary interfaces (cluster communication)
- VLAN 30: K8s secondary interfaces (MetalLB L2Advertisement)
- MetalLB speakers: Detect ens19, ARP for 10.0.30.10
- Traefik: Reachable via LoadBalancer VIP from Mac

**Known Issues:**

- ⚠️ Certificate warning (will fix with Cloudflare Tunnel)
- ⚠️ ArgoCD automated sync showing "Unknown" status (investigating)
- ⚠️ MinIO Degraded (CSI provisioning blocked - see Task 20)

**Next Immediate Steps:**

1. Deploy Cloudflare Tunnel (fix certificate, enable external access)
2. Troubleshoot ArgoCD automated sync mechanism
3. Fix Proxmox cluster API endpoint (unblock MinIO)
4. Test Proxmox CSI provisioning with PVC
5. Re-enable user apps (CNPG, Valkey, Renovate, pgadmin4)

---

### 2026-01-28 Session (Pre-Bootstrap Preparation)

**Completed:**

- ✅ Configured MinIO storage on dedicated sata-ssd pool (50Gi)
- ✅ Created ZFS dataset configuration (1M recordsize, zstd compression, atime=off)
- ✅ Designed Proxmox CSI StorageClass: proxmox-csi-zfs-minio-retain
- ✅ Updated proxmox-csi wrapper chart (version 0.45.9)
- ✅ Comprehensive storage audit (23 apps validated, 472Gi nvme + 50Gi sata-ssd)
- ✅ Updated documentation (proxmox-csi-setup.md, architect.md, decisionLog.md, progress.md)
- ✅ Validated all apps using correct StorageClasses and sizes
- ✅ MinIO configuration: standalone mode, node-agnostic scheduling, CNPG/k8s backup buckets

**Storage Allocations Validated:**

- nvme rpool: pgdata 245Gi, pgwal 30Gi, registry 170Gi, caches 27Gi
- sata-ssd: minio-data 50Gi (39% pool utilization, room for growth)

---

**Last Updated:** 2026-01-29
**Next Review:** After Cloudflare Tunnel deployment
