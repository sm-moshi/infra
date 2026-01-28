# Infrastructure TODO

**Last Updated:** 2026-01-28
**Status:** Fresh cluster deployment imminent 🚀 | Proxmox CSI configured | Ready for bootstrap

This document tracks active and planned infrastructure tasks. Completed work is archived in [done.md](done.md).

**Current Focus:** 4-VLAN network deployment → k3s bootstrap → Proxmox CSI enablement → GitOps sync

---

## 🔥 P0 Critical Priority (Deployment Sequence)

### Task 19: Deploy 4-VLAN Network Infrastructure

**Status:** ✅ Configuration complete | 🔄 Ready for Terraform apply

**Pre-Deployment Checklist:**

- [x] Terraform configuration validated (terraform-validate passing)
- [x] Network architecture documented (network-vlan-architecture.md)
- [x] Proxmox CSI storage requirements documented (proxmox-csi-setup.md)
- [x] ZFS dataset creation commands prepared (5 datasets)
- [x] Ansible inventory updated for VLAN IPs
- [x] Harbor registry mirrors made optional (k3s_enable_harbor_mirrors toggle)
- [x] Edge service IPs updated to VLAN 10
- [x] Edge ingress hostnames updated to lab.m0sh1.cc
- [x] Node configurations updated (control plane taint, storage labels, zone labels)
- [x] Application scheduling configured (8 apps with HA topology spread)
- [x] Node role label application script created (tools/scripts/apply-node-role-labels.fish)
- [x] Bootstrap documentation updated with node label step

**Documentation:**

- Architecture: [network-vlan-architecture.md](network-vlan-architecture.md)
- Implementation: [terraform-vlan-rebuild.md](terraform-vlan-rebuild.md)

**Network Design:**

- VLAN 10 (10.0.10.0/24): Infrastructure (Proxmox, DNS, PBS, SMB, Bastion)
- VLAN 20 (10.0.20.0/24): Kubernetes nodes
- VLAN 30 (10.0.30.0/24): Service VIPs (MetalLB LoadBalancers)
- OPNsense: Inter-VLAN routing

**Deployment Phases:**

- [ ] Phase 1: Terraform infrastructure deployment
  - [ ] Apply Terraform: `cd terraform/envs/lab && terraform apply`
  - [ ] Verify LXCs/VMs created (dns01, dns02, pbs, smb, bastion, K8s nodes)
  - [ ] Verify OPNsense VM created (VMID 300)
- [ ] Phase 2: OPNsense configuration
  - [ ] Boot from ISO, install OPNsense
  - [ ] Add WAN interface manually (net0)
  - [ ] Configure VLAN interfaces (10, 20, 30)
  - [ ] Set up firewall rules (inter-VLAN routing)
- [ ] Phase 3: Infrastructure services
  - [ ] Deploy AdGuard Home DNS (ansible-playbook playbooks/adguard.yaml)
  - [ ] Update Ansible inventory for VLAN IPs
  - [ ] Deploy PBS, SMB, Bastion
- [ ] Phase 4: Kubernetes cluster
  - [ ] Deploy K3s control plane
  - [ ] Deploy K3s workers
  - [ ] Verify cluster: kubectl get nodes
- [ ] Phase 5: GitOps bootstrap
  - [ ] Bootstrap ArgoCD
  - [ ] Deploy root application
  - [ ] Verify MetalLB assigns 10.0.30.10 to Traefik
  - [ ] Test application access

**Key Changes:**

- dns02: 10.0.10.14 (was 10.0.10.11, conflict resolved)
- smb: 10.0.10.23 (was 10.0.10.110)
- MetalLB: Single VLAN 30 pool (simplified from 3-pool design)
- Traefik: 10.0.30.10 LoadBalancerIP

**Priority:** 🔴 **CRITICAL** - Infrastructure rebuild required

---

## � P1 Post-Deployment Tasks

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

**Reference:** [docs/proxmox-csi-setup.md](proxmox-csi-setup.md)

**Priority:** 🔴 **CRITICAL** - Must complete before app deployments

---

## 🔨 P2 Post-Bootstrap Tasks

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

### Task 18: Post-Deployment Health Monitoring

**Status:** Pending fresh cluster deployment

**Objective:** Ensure all applications reach Healthy/Synced status after GitOps bootstrap

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

### 2026-01-28 Session (Pre-Bootstrap Preparation)

**Completed:**

- ✅ Configured MinIO storage on dedicated sata-ssd pool (50Gi)
- ✅ Created ZFS dataset configuration (1M recordsize, zstd compression, atime=off)
- ✅ Designed Proxmox CSI StorageClass: proxmox-csi-zfs-minio-retain
- ✅ Updated proxmox-csi wrapper chart (version 0.45.9)
- ✅ Comprehensive storage audit (23 apps validated, 472Gi nvme + 50Gi sata-ssd)
- ✅ Updated documentation:
  - proxmox-csi-setup.md (MinIO dataset instructions)
  - architect.md (Proxmox CSI component architecture)
  - decisionLog.md (MinIO storage decision 2026-01-28)
  - progress.md (pre-bootstrap state)
- ✅ Validated all apps using correct StorageClasses and sizes
- ✅ MinIO configuration: standalone mode, node-agnostic scheduling, CNPG/k8s backup buckets

**Storage Allocations Validated:**

- nvme rpool: pgdata 245Gi, pgwal 30Gi, registry 170Gi, caches 27Gi
- sata-ssd: minio-data 50Gi (39% pool utilization, room for growth)

**Next Immediate Steps:**

1. Execute Terraform apply for 4-VLAN infrastructure
2. Boot and configure OPNsense (VLANs 10/20/30)
3. Deploy AdGuard Home DNS via Ansible
4. Bootstrap k3s control plane (labctrl)
5. Join k3s workers (horse01-04)
6. Create ZFS datasets on all Proxmox nodes
7. Configure Proxmox storage IDs
8. Bootstrap ArgoCD and deploy root application

---

**Last Updated:** 2026-01-28
**Next Review:** After k3s bootstrap
