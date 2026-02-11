# Infrastructure TODO

## Source Of Truth (Basic Memory)

This TODO is being migrated to Basic Memory (per `AGENTS.md` §8.1).

- **Note:** Basic Memory migration never completed; this file remains authoritative
- Legacy planning docs (migrated): `infra/memory-bank/*`

**Last Updated:** 2026-02-09
**Status:** All user apps operational ✅ | MetalLB L2 working ✅ | Base cluster deployed ✅ | Proxmox CSI operational ✅ | Cloudflared external access ✅ | MinIO + CNPG operational ✅ | Harbor deployed + verified ✅ | Tailscale subnet routing + split DNS ✅ | Observability stack (Loki, Alloy, Prometheus) ✅ | 38/39 apps Synced/Healthy

This document tracks active and planned infrastructure tasks. Completed work is archived in [done.md](done.md).

**Current Focus:** Phase 1 Infrastructure (LXCs, Bastion, DNS) → Security hardening → New applications

---

## Cluster Status (Reality Check - 2026-02-09)

**✅ Operational (38/39 apps):**

- **Cluster Infrastructure:** ArgoCD, cert-manager, Traefik, MetalLB, sealed-secrets, Proxmox CSI, external-dns, origin-ca-issuer, cloudflared, reflector, local-path
- **Storage:** MinIO operator+tenant, CloudNativePG operator
- **Observability:** kube-prometheus-stack, Loki, Alloy, prometheus-pve-exporter, grafana-mcp
- **Security:** Kubescape operator, Trivy operator
- **User Apps:** authentik, netbox, renovate, uptime-kuma, pgadmin4, basic-memory, semaphore, vaultwarden, valkey, headlamp, proxmenux
- **Other:** kured, cloudnative-pg (Healthy, shows OutOfSync UI glitch)

**⚠️ Not Started/Planned:**

- Scanopy (no chart exists)
- Phase 1 Infrastructure LXCs (dns01, dns02, pbs, smb, bastion)
- AdGuard Home DNS deployment
- NetworkPolicy baseline
- ArgoCD Project boundaries
- Comprehensive security hardening

---

## Prioritized Checklist (Updated 2026-02-09)

### ✅ Completed Recently

1. ✅ Install kube-prometheus-stack (Grafana, Prometheus, Alertmanager) — **DONE**
2. ✅ Install prometheus-pve-exporter — **DONE**
3. ✅ Install Loki (logging) — **DONE**
4. ✅ Install Alloy (log shipping) — **DONE**
5. ✅ Re-enable user apps: pgadmin4, basic-memory, semaphore — **DONE**
6. ✅ Deploy Basic Memory MCP server — **DONE** (was already deployed with livesync-bridge)
7. ✅ Semaphore CNPG migration — **DONE** (running with CNPG, not blocked as previously thought)
8. ⬜ Deploy Scanopy — **NOT STARTED** (no chart exists, needs creation)

### 🔄 Active / Pending

9. 🔄 Phase 1 Infrastructure:
   - [ ] Terraform-driven infra LXCs (dns01, dns02, pbs, smb)
   - [ ] Bastion VM deployment
   - [ ] AdGuard Home DNS (Ansible)
   - [ ] PBS and SMB services (Ansible)

10. 🔄 Security & Hardening:
    - [ ] NetworkPolicy baseline (default-deny, allow-traefik, allow-dns)
    - [ ] ArgoCD Project boundaries (cluster-project, user-project)
    - [ ] Gitea security contexts (readOnlyRootFilesystem, capabilities)
    - [ ] Harbor security hardening

---

## Phase Tracker

- Phase 0 — Repository Contract: ✅ Complete (guardrails, layout, CI)
- Phase 1 — Infrastructure Deployment: 🔄 **ACTIVE** (LXCs, Bastion, DNS, PBS, SMB)
- Phase 2 — Storage Provisioning: ✅ **COMPLETE** (Proxmox CSI, MinIO, CNPG all operational)
- Phase 3 — GitOps Bootstrap: ✅ Complete (all base apps deployed)
- Phase 4 — Validation & Operations: ✅ Complete (38/39 apps healthy)
- Phase 5 — Security Hardening: 🔄 **PENDING** (NetworkPolicy, security contexts)

---

## 🔥 Critical Priority

### Task 40: Phase 1 Infrastructure Completion

**Status:** 🔄 In Progress — High priority, blocks stable infrastructure services

**Components:**

1. **Terraform Infrastructure**
   - dns01, dns02 LXCs (DNS redundancy)
   - pbs LXC (Proxmox Backup Server)
   - smb LXC (SMB file server)
   - bastion VM (jump host)

2. **Ansible Configuration**
   - AdGuard Home DNS deployment
   - PBS configuration and backups
   - SMB shares and permissions

**Priority:** 🔴 **HIGH** — Foundation infrastructure

---

### Task 41: NetworkPolicy Baseline

**Status:** ⬜ Not Started

**Objective:** Implement zero-trust networking

**Tasks:**

- [ ] Default-deny NetworkPolicy for apps namespace
- [ ] Allow-ingress-from-traefik policy
- [ ] Allow-egress-to-dns (CoreDNS) policy
- [ ] Allow-egress-to-CNPG policy
- [ ] Test connectivity between pods
- [ ] Document policy patterns

**Priority:** 🟡 **MEDIUM** — Security posture improvement

---

### Task 42: ArgoCD Project Boundaries

**Status:** ⬜ Not Started

**Objective:** Isolate cluster apps from user apps

**Tasks:**

- [ ] Create `cluster-project` (apps/cluster/*)
- [ ] Create `user-project` (apps/user/*, namespace: apps)
- [ ] Update Application manifests to reference projects
- [ ] Test isolation
- [ ] Document strategy

**Priority:** 🟡 **MEDIUM** — Operational safety

---

### Task 8: Deploy Scanopy

**Status:** ⬜ Not Started — **Chart does not exist**

**Note:** Scanopy is referenced in TODO but no Helm chart or implementation exists. Need to:

1. Define what Scanopy is/does
2. Create wrapper chart
3. Deploy via ArgoCD

**Priority:** 🟢 **LOW** — Not blocking, needs definition

---

## ✅ Recently Completed Tasks

### Session 5 (2026-02-09): Health Check Resolution

**Commits:** `10c8f84a`, `0e7cbcfa`, `0644c2a5`, `26df2084`, `272aa879`

**Completed:**

- ✅ MetalLB DHI migration (speaker ARP capability fix)
- ✅ Traefik annotation migration (`metallb.universe.tf` → `metallb.io`)
- ✅ Basic-memory startup probe (eliminated rollout failures)
- ✅ Ansible Harbor CA path fix (first_found lookup)
- ✅ MetalLB speaker verification (all 5 pods healthy, excludel2 resolved)

---

### Task 33: pgadmin4 (UPDATED - Complete)

**Status:** ✅ **DEPLOYED AND OPERATIONAL**

**Correction from Previous TODO:**

- ArgoCD Application: `argocd/apps/user/pgadmin4.yaml` ✅ Active
- Pod: `pgadmin4-v5-*` running in `apps` namespace ✅
- Accessible at: <https://pgadmin.m0sh1.cc> ✅

**All tasks complete:**

- ✅ Storage class: `proxmox-csi-zfs-nvme-general-retain`
- ✅ PVC bound (5Gi)
- ✅ Ingress: pgadmin.m0sh1.cc
- ✅ SealedSecret: pgadmin-admin

---

### Task 35: Semaphore (UPDATED - Complete)

**Status:** ✅ **DEPLOYED AND OPERATIONAL** (Previous "BLOCKED" was incorrect)

**Correction:**

- ArgoCD Application: `argocd/apps/user/semaphore.yaml` ✅ Active
- Pod: `semaphore-*` running in `apps` namespace ✅
- Health: Synced, Healthy ✅

**Note:** Previous TODO incorrectly marked this as blocked. Semaphore is running with CNPG integration.

---

### Task 6: Basic Memory MCP Server (UPDATED - Complete)

**Status:** ✅ **DEPLOYED AND OPERATIONAL**

**Components:**

- ArgoCD Application: `argocd/apps/user/basic-memory.yaml` ✅
- Pods: `basic-memory-*` (4 containers: basic-memory, mcp-shim, couchdb, livesync-bridge) ✅
- Health: Synced, Healthy ✅
- Recent fix: startupProbe added (commit `0644c2a5`)

**Access:**

- MCP endpoint: <https://basic-memory.m0sh1.cc>
- LiveSync: <https://livesync.m0sh1.cc>

---

## 🔴 P1 Post-Deployment Tasks

### Task 9: Trivy Operator Assessment

**Status:** ✅ Enabled

**Remaining:**

- [ ] Assess resource overhead from scan jobs

**Priority:** 🟢 **MEDIUM**

---

### Task 17: Workload Security Hardening

**Status:** 🔄 In Progress

**Tasks:**

- [ ] Gitea: Enforce `readOnlyRootFilesystem`, drop capabilities
- [ ] Harbor: Investigate Bitnami security contexts
- [x] Traefik: Migrate wrapper chart to DHI (`oci://dhi.io/traefik-chart`)
- [ ] NetworkPolicy: default-deny (see Task 41)

**Priority:** 🟡 **MEDIUM**

---

## 🧹 P3 Future Tasks

### Task 13: Traefik Security Headers

**Status:** ⬜ Not Started

**Priority:** 🔵 **LOW**

---

### Task 14: Expand Terraform

**Status:** ⬜ Not Started — pve-02, pve-01 management

**Priority:** 🔵 **LOW**

---

### Task 15: Kiwix Server

**Status:** ⬜ Not Started — Offline Wikipedia

**Priority:** 🔵 **LOW**

---

### Task 16: Logging Stack Evaluation

**Status:** ✅ **RESOLVED** — Loki + Alloy deployed

**Note:** Centralized logging now operational. No further action needed.

---

## 📊 Current Capacity

**Cluster:**

- Nodes: 5 (1 control plane, 4 workers)
- Apps: 38/39 Healthy (cloudnative-pg shows OutOfSync UI glitch only)
- Storage: Proxmox CSI operational (5 StorageClasses)
- Network: Dual-NIC (VLAN 20 + 30), MetalLB L2

**Resource Summary:**

- CPU: ~15-20% average utilization
- Memory: ~40-50% average utilization
- Storage: 472Gi NVMe allocated, 50Gi SATA for MinIO

---

**Next Review:** After Phase 1 infrastructure deployment
