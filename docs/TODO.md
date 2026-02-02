# Infrastructure TODO

**Last Updated:** 2026-02-02 18:20 UTC
**Status:** ArgoCD WebUI operational ✅ | MetalLB L2 working ✅ | Base cluster deployed ✅ | Proxmox CSI operational ✅ | Cloudflared external access ✅ | RustFS disabled (PVCs removed) ✅ | MinIO operator+tenant deployed (ingress TLS fixed) ✅ | Tailscale subnet routing + split DNS access model operational ✅

This document tracks active and planned infrastructure tasks. Completed work is archived in [done.md](done.md).

**Current Focus:** Harbor deployment (Phase 5+) → Resolve ArgoCD app errors (cloudnative-pg/harbor/minio-tenant) → Observability stack → Re-enable user apps

## Prioritized Checklist (2026-02-02)

1. [ ] Complete Harbor deployment + verification (Phase 5–7 in Task 29).
2. [ ] Resolve ArgoCD app errors: cloudnative-pg ComparisonError/SharedResourceWarning, harbor OutOfSync, minio-tenant OutOfSync.
3. [ ] Install kube-prometheus-stack (docs/diaries/observability-implementation.md).
4. [ ] Install prometheus-pve-exporter (docs/diaries/observability-implementation.md).
5. [ ] Install Loki (docs/diaries/observability-implementation.md).
6. [ ] Install Alloy (docs/diaries/observability-implementation.md).
7. [ ] Deploy Authentik SSO/IdP (docs/diaries/authentik-implementation.md).
8. [ ] Deploy NetBox IPAM/DCIM (docs/diaries/netbox-implementation.md).
9. [ ] Re-enable remaining user apps in order: pgadmin4 → Uptime-Kuma (verify `wildcard-m0sh1-cc` in `apps` namespace, move ArgoCD app, verify UI) → Headlamp (move ArgoCD app, verify).
10. [ ] Deploy Basic Memory MCP server (docs/diaries/basic-memory-implementation.md).
11. [ ] Complete Semaphore CNPG migration, then re-enable Semaphore.
12. [ ] Deploy Scanopy.
13. [ ] Finish infra deployment (infra LXCs + Bastion VM + AdGuard Home + PBS/SMB Ansible rollout).
14. [ ] Post-deployment improvements (NetworkPolicy baseline, ArgoCD AppProjects, monitoring/logging).

**Postponed:** Gitea (revisit after Semaphore migration).

## Phase Tracker (merged from checklist)

- Phase 0 — Repository Contract: ✅ complete (guardrails, layout, CI, storage audit)
- Phase 1 — Infrastructure Deployment: 🔄 in progress (finish infra LXCs + bastion; AdGuard Home DNS; PBS/SMB Ansible rollout)
- Phase 2 — Storage Provisioning: 🔄 **ACTIVE** (Proxmox ZFS datasets → CSI testing → MinIO migration → CNPG integration)
- Phase 3 — GitOps Bootstrap: ✅ complete (infra-root corrected, base apps deployed, sealed-secrets restored)
- Phase 4 — Validation & Operations: 🔄 ongoing (MinIO migration, storage pipeline validation, database migrations)

---

## 🔥 P0 Critical Priority (Deployment Sequence)

### Task 29: Harbor CNPG Integration Implementation

**Status:** 🟡 Phases 2–4 complete; Phase 5 in progress; Phases 6–7 pending

**Objective:** Deploy Harbor with per-app CNPG cluster, MinIO S3 backups, and fixed storage classes

**Documentation:** [docs/diaries/harbor-implementation.md](diaries/harbor-implementation.md)

**Completed (moved to done.md):**

- ✅ MinIO prerequisites: tenant healthy + `cnpg-backups` bucket created
- ✅ Phase 2: Valkey storage fix (values + chart bump)
- ✅ Phase 3: Harbor secrets audit + SealedSecret rotation
- ✅ Phase 4: Harbor config changes + CNPG backup config + chart bump (0.4.18)

**Remaining Phases:**

- [ ] **Phase 5: Harbor Deployment** (30 min)
- [ ] Resolve ArgoCD app errors: cloudnative-pg ComparisonError/SharedResourceWarning, harbor OutOfSync, minio-tenant OutOfSync
- [x] Install Harbor CA on all k3s nodes and configure registries to trust it (Ansible)
- [x] Add `dhi.io` mirror rewrite to k3s registries (Ansible)
- [~] Add `dhi.io` proxy cache project in Harbor values + grant build user access (pending sync + endpoint creds)
- [~] Rotate Harbor core secretKey to 32 bytes (SealedSecret updated; pending sync)
- [ ] Monitor ArgoCD sync
- [ ] Verify CNPG cluster creation (harbor-postgres)
- [ ] Verify PVCs bound to correct storage classes
- [ ] Verify Harbor pods running (core, portal, registry, jobservice, trivy, postgres)
- [ ] Check Harbor core logs for database connection

- [ ] **Phase 6: Backup Verification** (20 min)
- [ ] Check MinIO for backup files (s3://cnpg-backups/cnpg-main/)
- [ ] Verify Harbor backups once harbor-postgres is deployed

- [ ] **Phase 7: Harbor UI Verification** (15 min)
- [ ] Access Harbor UI (<https://harbor.m0sh1.cc>)
- [ ] Login with admin credentials
- [ ] Verify components healthy (database, redis, storage)
- [ ] Run bootstrap job (if configured)
- [ ] Add Docker Hub + DHI registry endpoints (verify save succeeds; AES error resolved)
- [ ] Verify proxy cache projects work (docker.io, ghcr.io, quay.io, registry.k8s.io, dhi.io)
- [ ] Test Docker login

**Storage Class Corrections:**

- PostgreSQL PGDATA: `proxmox-csi-zfs-pgdata-retain` → `proxmox-csi-zfs-nvme-fast-retain`
- PostgreSQL PGWAL: `proxmox-csi-zfs-pgwal-retain` → `proxmox-csi-zfs-nvme-general-retain`
- Harbor Registry: `proxmox-csi-zfs-registry-retain` → `proxmox-csi-zfs-sata-object-retain`
- Trivy Cache: `proxmox-csi-zfs-caches-delete` → `proxmox-csi-zfs-nvme-fast-retain`

**Priority:** 🔴 **CRITICAL** - Unblocks Harbor proxy cache + user apps

---

### Task 31: Enable Uptime-Kuma Monitoring

**Status:** ✅ Configuration Complete - Ready to Deploy (TLS verification needed)

**Completed Work:**

- ✅ Storage class fixed: `pgdata-retain` → `nvme-fast-retain`
- ✅ Chart version bumped: 0.2.5
- ✅ Committed to Git

**Prerequisites:**

- ✅ Traefik deployed
- ⚠️ TLS certificate `wildcard-m0sh1-cc` needs verification in `apps` namespace
- ✅ Reflector deployed (should replicate cert)

**Remaining Tasks:**

- [ ] Verify TLS secret: `kubectl get secret wildcard-m0sh1-cc -n apps`
- [ ] Move ArgoCD Application: `argocd/disabled/user/uptime-kuma.yaml` → `argocd/apps/user/uptime-kuma.yaml`
- [ ] Commit and push
- [ ] Monitor ArgoCD sync
- [ ] Verify StatefulSet pod running
- [ ] Verify PVC bound (5Gi on nvme-fast-retain, SQLite database)
- [ ] Access UI at <https://uptime.m0sh1.cc>
- [ ] Create admin account (first-time setup)
- [ ] Add monitoring targets

**Configuration:**

- **Database:** SQLite (embedded, 5Gi persistent storage)
- **Ingress:** uptime.m0sh1.cc (Traefik + TLS)
- **Resources:** 100m CPU / 128Mi memory (lightweight)

**Priority:** 🟢 **MEDIUM** - Ready after TLS cert verification

---

### Task 32: Enable Kured Reboot Daemon

**Status:** ✅ Production-Ready - No Changes Needed

**Configuration Validated:**

- ✅ Wrapper chart version 0.1.1 (upstream kured v5.11.0)
- ✅ Reboot sentinel: `/var/run/reboot-required` (Debian/Ubuntu standard)
- ✅ Concurrency: 1 (safe rolling reboots)
- ✅ Tolerations: control-plane + batch workloads
- ✅ No storage dependencies
- ✅ No secret dependencies

**Remaining Tasks:**

- [ ] Move ArgoCD Application: `argocd/disabled/cluster/kured.yaml` → `argocd/apps/cluster/kured.yaml`
- [ ] Commit and push
- [ ] Monitor ArgoCD sync (sync-wave 5, very early)
- [ ] Verify DaemonSet running on all nodes
- [ ] Check logs for reboot-required monitoring
- [ ] (Optional) Test with manual reboot flag: `touch /var/run/reboot-required` on worker node

**Expected Behavior:**

- DaemonSet runs on all nodes (including control-plane)
- Monitors `/var/run/reboot-required` file
- When detected: cordons node → drains pods → reboots → waits for ready → uncordons
- Proceeds to next node (concurrency: 1 ensures safety)

**Priority:** 🟢 **MEDIUM** - Infrastructure hygiene, no blockers

---

### Task 33: Enable pgadmin4 PostgreSQL Admin UI

**Status:** ✅ Configuration Complete - Ready to Deploy

**Completed Work:**

- ✅ Storage class fixed: `proxmox-csi-zfs-pgdata-retain` → `proxmox-csi-zfs-nvme-general-retain` (128K recordsize, suitable for SQLite + uploaded files)
- ✅ Chart version bumped: 0.2.1 → 0.2.2
- ✅ Committed to Git

**Prerequisites:**

- ✅ Traefik deployed
- ✅ TLS certificate `wildcard-m0sh1-cc` exists (Reflector propagates to all namespaces)
- ✅ SealedSecret `pgadmin-admin` exists in secrets-apps (admin credentials)

**Remaining Tasks:**

- [ ] Move ArgoCD Application: `argocd/disabled/user/pgadmin4.yaml` → `argocd/apps/user/pgadmin4.yaml`
- [ ] Commit and push
- [ ] Monitor ArgoCD sync
- [ ] Verify PVC bound (5Gi on nvme-general-retain, SQLite database)
- [ ] Access UI at <https://pgadmin.m0sh1.cc>
- [ ] Login with admin credentials from SealedSecret
- [ ] Add PostgreSQL server connections (Valkey, CNPG clusters)

**Configuration:**

- **Database:** SQLite (embedded, 5Gi persistent storage on NVMe general-purpose)
- **Ingress:** pgadmin.m0sh1.cc (Traefik + TLS)
- **Resources:** 25m CPU / 128Mi memory (lightweight)

**Priority:** 🟢 **MEDIUM** - Ready to deploy immediately

---

### Task 34: Enable Headlamp Kubernetes Web UI

**Status:** ✅ Production-Ready - No Changes Needed

**Configuration Validated:**

- ✅ Wrapper chart version 0.1.1 (upstream headlamp v0.39.0)
- ✅ Stateless (no storage dependencies)
- ✅ ServiceAccount with cluster-admin role (RBAC configured)
- ✅ 8 plugins configured (kubescape, trivy, cert-manager, opencost, etc.)
- ✅ TLS certificate `wildcard-m0sh1-cc` exists (Reflector propagates)

**Remaining Tasks:**

- [ ] Move ArgoCD Application: `argocd/disabled/user/headlamp.yaml` → `argocd/apps/user/headlamp.yaml`
- [ ] Commit and push
- [ ] Monitor ArgoCD sync
- [ ] Verify Deployment pod running
- [ ] Access UI at <https://headlamp.m0sh1.cc>
- [ ] Test RBAC permissions (cluster-admin capabilities)
- [ ] Verify plugins loaded (check kubescape + trivy integrations)

**Features:**

- Real-time cluster monitoring
- Resource management (create/edit/delete)
- Plugin system for extended functionality
- Kubescape security scanning
- Trivy vulnerability scanning
- cert-manager certificate management
- OpenCost cost analysis

**Priority:** 🟢 **MEDIUM** - Infrastructure visibility, no blockers

---

### Task 35: Semaphore CNPG Migration (Architecture Change)

**Status:** 🚨 **BLOCKED** - Requires 8-Phase Implementation (4-6 hours)

**Critical Issues:**

1. ❌ Chart disabled in values.yaml (`semaphore.enabled: false`)
2. ❌ References deprecated `cnpg-main-rw.apps.svc.cluster.local` (violates 2026-01-16 per-app cluster decision)
3. ❌ Storage class `proxmox-csi-zfs-pgdata-retain` non-existent
4. ❌ Missing per-app CNPG templates (`postgres-cluster.yaml`, `postgres-database.yaml`)
5. ❌ 4 secrets status unclear (semaphore-admin, semaphore-secrets, semaphore-runner, semaphore-postgres-auth)

**Implementation Plan:**

- 📄 **Documented:** [docs/diaries/semaphore-implementation.md](diaries/semaphore-implementation.md) (8 phases, comprehensive migration guide)
- **Architecture:** Migrate from shared CNPG cluster to per-app cluster pattern
- **Phases:**
  1. Prerequisites validation (CNPG operator, backup infrastructure)
  2. Secret generation (4 secrets: admin, secrets, runner, postgres-auth)
  3. CNPG templates (postgres-cluster.yaml, postgres-database.yaml)
  4. Configuration updates (database connection, storage classes, chart enable)
  5. Deployment and validation
  6. Backup configuration (Barman Cloud → MinIO S3)
  7. UI access and first-run setup
  8. Operational validation

**Required Changes:**

- **New Files:**
  - `apps/user/semaphore/templates/postgres-cluster.yaml` (CNPG cluster with Barman Cloud backups)
  - `apps/user/semaphore/templates/postgres-database.yaml` (Database + owner user)
  - 4 SealedSecrets in `apps/user/secrets-apps/templates/` (semaphore-*)

- **Modified Files:**
  - `apps/user/semaphore/values.yaml` (database connection, storage classes, enable chart)
  - `apps/user/semaphore/Chart.yaml` (version bump 0.1.38 → 0.2.0, major architecture change)

**Timeline:** 4-6 hours (estimated)

**Priority:** 🔴 **HIGH** - Architecture migration required, aligns with per-app CNPG pattern

---

### Task 23: Remote Access via Tailscale + Split DNS

**Status:** ✅ COMPLETE - Access model validated across desktop and mobile

**Objective:** Provide secure internal access to lab services from WiFi and mobile networks without relying on ISP router features or exposing internal services.

**Implemented Design:**

- Tailscale used as the authenticated access plane
- `pve-01` acts as the subnet router
- Advertised VLANs:
  - 10.0.10.0/24 (Infrastructure)
  - 10.0.20.0/24 (Kubernetes)
  - 10.0.30.0/24 (Ingress / Services)
- OPNsense remains the single L3 router and firewall
- No Tailscale installed on OPNsense (by design)

**DNS Behavior:**

- On Tailscale (trusted):
  - Split DNS via Tailscale DNS → OPNsense Unbound
  - `argocd.m0sh1.cc` resolves to `10.0.30.10`
  - IPv6 AAAA suppressed internally to prevent Cloudflare routing
- Off Tailscale (untrusted):
  - Public DNS → Cloudflare → Cloudflare Access

**Validation:**

- macOS client: curl + browser access verified
- iOS client: Nautik access verified
- Full VLAN 10/20/30 reachability confirmed
- Cloudflare Access bypassed on tailnet, enforced off-tailnet
- Single-FQDN access model confirmed

**Documentation:** `docs/network-vlan-architecture.md`

### Task 22: Fix RustFS Helm Lint Error (BLOCKER)

**Status:** ✅ COMPLETE - Helm lint passing

**Issue:** Helm lint failed with TLS configuration type mismatch (upstream expected object, wrapper provided array)

**Solution:** Fixed apps/cluster/rustfs/values.yaml ingress.tls structure:

```yaml
tls:
  enabled: true
  certManager:
    enabled: false
  secretName: wildcard-s3-m0sh1-cc
```

**Validation:** ✅ `helm lint apps/cluster/rustfs/` passes (1 chart linted, 0 failed)

**Next:** Verify MinIO internal S3 endpoint (LAN) after cutover, then proceed to CNPG

### Task 26: Centralize SealedSecrets to secrets-cluster and secrets-apps

**Status:** ✅ COMPLETE - 30 SealedSecrets centralized

**Objective:** Move all credential/token SealedSecrets from individual wrapper chart templates to centralized Kustomize applications

**Completed Work:**

**Cluster Secrets (secrets-cluster/):**

- Moved 9 SealedSecrets from apps/cluster/*/templates/
  - cloudflare-api-token (from cert-manager)
  - cloudflared-tunnel-token (from cloudflared)
  - cnpg-backup-credentials (from cloudnative-pg)
  - csi-proxmox (from proxmox-csi)
  - external-dns-cloudflare (from external-dns)
  - operator-oauth (from tailscale-operator)
  - origin-ca-issuer-cloudflare (from origin-ca-issuer)
  - rustfs-root-credentials (from rustfs)
  - valkey-users (from valkey)
- Updated secrets-cluster/kustomization.yaml (11 total resources)

**User App Secrets (secrets-apps/):**

- Moved 21 SealedSecrets from apps/user/*/templates/
  - renovate-github-token (from renovate)
  - adguardhome-sync-homepage-adguard (from adguardhome-sync)
  - harborguard-db-secret (from harborguard)
  - pgadmin-admin (from pgadmin4)
  - 8 Harbor credentials (admin, postgres, valkey, registry, core, jobservice, build-user)
  - 3 Homepage API credentials (proxmox, adguard, pbs)
  - 6 Gitea credentials (admin, db, redis, secrets, runner, harbor-robot)
- Created argocd/apps/user/secrets-apps.yaml (sync-wave 5)
- Updated secrets-apps/kustomization.yaml (21 total resources)

**Architecture Pattern Established:**

- Static credentials/tokens → secrets-cluster/ or secrets-apps/
- TLS certificates with reflector → wrapper chart templates/
- Used `git mv` to preserve file history

**Priority:** ✅ Complete - Infrastructure pattern enforced

---

### Task 21: Deploy Cloudflare Tunnel for External Access

**Status:** ✅ Deployed via ArgoCD - External access validated (route order fixed)

**Objective:** Enable external HTTPS access to ArgoCD and other services with valid TLS certificates

**Estimated Time:** 15-20 minutes (validation + external access checks remaining)

**Progress:**

- ✅ Converted to wrapper chart pattern (community-charts/cloudflared v2.2.6)
- ✅ Generated SealedSecret with tunnel credentials.json
- ✅ Configured ingress routes (*.m0sh1.cc → traefik-lan)
- ✅ Resolved Helm lint validation (base64 values vs existingSecret conflict)
- ✅ Deployed via ArgoCD sync (cloudflared pods Running, tunnel connected)
- ✅ Validate external access and tunnel connectivity (route order fixed; argocd.m0sh1.cc reachable)
- ✅ Remote access on WiFi and mobile networks restored using Tailscale subnet routing + split DNS

**Architecture:**

```text
Internet → Cloudflare Edge (TLS) → Encrypted tunnel → cloudflared pod → Traefik LAN → Services
```

**Tasks:**

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

### Task 23: Storage Provisioning Pipeline (Proxmox CSI → MinIO OSS → CloudNativePG)

**Status:** 🔄 In progress - MinIO migration pending

**Architecture:** MinIO OSS (S3 storage) + CloudNativePG (PostgreSQL) require Proxmox CSI StorageClasses

**Deployment Sequence:**

#### Phase 1: Proxmox ZFS Datasets (Manual Prerequisite)

**Status:** ✅ COMPLETE - All datasets created and verified

**Verified:**

```bash
# All 3 nodes (pve01, pve02, pve03) have:
rpool/k8s-nvme-fast         # 16K recordsize (fast tier)
rpool/k8s-nvme-general      # 128K recordsize (general NVMe)
rpool/k8s-nvme-object       # 1M recordsize (object storage, NVMe tier)
sata-ssd/k8s-sata-general   # 128K recordsize (general SATA, 25G quota)
sata-ssd/k8s-sata-object    # 1M recordsize (object storage, 75G quota)

# Proxmox storage IDs configured and active:
k8s-nvme-fast        zfspool     active
k8s-nvme-general     zfspool     active
k8s-nvme-object      zfspool     active
k8s-sata-general     zfspool     active
k8s-sata-object      zfspool     active
```

#### Phase 2: Enable Proxmox CSI (Sync-Wave 20)

**Status:** ✅ Operational (controller and node pods Running)

**Tasks:**

  ```bash
  kubectl get storageclass | grep proxmox-csi
  # Expected: proxmox-csi-zfs-nvme-fast-retain
  #           proxmox-csi-zfs-nvme-general-retain
  #           proxmox-csi-zfs-nvme-object-retain
  #           proxmox-csi-zfs-sata-general-retain
  #           proxmox-csi-zfs-sata-object-retain
  ```

#### Phase 3: Disable RustFS + Cleanup

**Status:** ✅ Complete (namespace deleted; PVCs removed; quotas adjusted)

**Dependencies:**

- ✅ Proxmox CSI operational
- ✅ StorageClass `proxmox-csi-zfs-sata-object-retain` available

**Tasks:**

#### Phase 3b: Enable MinIO OSS (Operator + Tenant)

**Status:** 🔄 In progress (operator/tenant synced; ingress TLS fix pending)

**Tasks:**

- [ ] Reflect wildcard-s3-m0sh1-cc TLS secret into minio-tenant
- [ ] Add Traefik ServersTransport + service annotations for HTTPS backend
- [ ] Verify s3-console.m0sh1.cc and s3.m0sh1.cc endpoints
- [ ] Create `cnpg-backups` bucket in MinIO if missing

#### Phase 4: Enable CloudNativePG (Sync-Wave 22)

**Status:** Application enabled at argocd/apps/cluster/cloudnative-pg.yaml

**Dependencies:**

- ✅ Proxmox CSI operational with nvme-fast + nvme-general StorageClasses
- 🔄 MinIO OSS S3 endpoint deployed; ingress TLS fix pending
- ✅ sealed-secrets controller running
- ✅ Configuration audited (values.yaml correct)
- ✅ CNPG wrapper: plugin-only Barman Cloud (ObjectStore + ScheduledBackup) with sidecar resources and zstd WAL compression

**Tasks:**

  ```bash
  mv argocd/disabled/cluster/cloudnative-pg.yaml argocd/apps/cluster/
  git add argocd/apps/cluster/cloudnative-pg.yaml
  ```

  ```bash
  kubectl get application -n argocd cloudnative-pg
  ```

  ```bash
  kubectl get pods -n cnpg-system
  # Expected: cloudnative-pg-operator pod Running
  ```

  ```bash
  kubectl get crd | grep barmancloud
  # Expected: objectstores.barmancloud.cnpg.io
  ```

  ```bash
  kubectl get cluster -n apps
  # Expected: cnpg-main (1/1 instances ready)
  kubectl get pods -n apps -l cnpg.io/cluster=cnpg-main
  ```

  ```bash
  kubectl get pvc -n apps
  # Expected: cnpg-main-1 (80Gi nvme-fast), cnpg-main-1-wal (20Gi nvme-general)
  ```

- [ ] Test backup to MinIO:

  ```bash
  kubectl get backup -n apps cnpg-main-backup-20260201-1
  # Verify objects in MinIO bucket:
  mc ls --recursive minio/cnpg-backups/cnpg-main/
  ```

  ```bash
  kubectl get schedulebackup -n apps
  # Expected: cnpg-main-backup (schedule: 0 0 2 * * *)
  ```

**Priority:** 🔴 **CRITICAL** - Core infrastructure for PostgreSQL databases

---

### Task 27: Garage Fallback (datahub-local/garage-helm)

**Status:** 🟡 Drafted - ArgoCD app disabled

**Objective:** Maintain a ready-to-enable Garage S3 fallback using the datahub-local chart with built-in WebUI + Gateway API support.

**Files:**

- Wrapper chart: `apps/cluster/garage/`
- Disabled ArgoCD app: `argocd/disabled/cluster/garage.yaml`
- Diary: `docs/diaries/garage-implementation.md`

**Tasks:**

- [ ] Review/adjust storage sizes and StorageClasses (meta vs data)
- [ ] Decide ingress domains (s3.garage.m0sh1.cc, web.garage.m0sh1.cc, garage-ui.m0sh1.cc)
- [ ] Enable ArgoCD app when needed
- [ ] Verify API/Web endpoints + WebUI

**Priority:** 🟡 **MEDIUM** - Fallback option only

---

### Task 28: Garage Stack POC (garage-operator + garage-ui)

**Status:** 🟡 Drafted - ArgoCD app disabled

**Objective:** Operator-managed GarageCluster with Garage UI and optional COSI support.

**Files:**

- Wrapper chart: `apps/cluster/garage-stack/`
- Disabled ArgoCD app: `argocd/disabled/cluster/garage-stack.yaml`
- Diary: `docs/diaries/garage-implementation.md`

**Tasks:**

- [ ] Verify GarageCluster service DNS (default `garage:3900/3903`)
- [ ] Decide whether to enable COSI in operator
- [ ] Enable ArgoCD app when ready
- [ ] Validate GarageCluster + UI

**Priority:** 🟡 **MEDIUM** - Exploratory fallback

---

### Task 24: Re-evaluate Cluster Topology Settings

**Status:** 🟡 HIGH PRIORITY - Cluster configuration changed

**Context:** Cluster topology changed significantly:

- ✅ pve03 added as worker node (3 workers total now)
- ✅ pve01 upgraded with more CPU/memory resources
- ⚠️ Many affinity/topology/tolerations were commented out pre-rebuild

**Impact:** Applications may not leverage HA capabilities properly

**Tasks:**

- [ ] Audit affinity settings in apps/cluster/ (ArgoCD, Traefik, CNPG, etc.)
- [ ] Audit topologySpreadConstraints across all apps
- [ ] Review tolerations for taint-based scheduling
- [ ] Re-enable appropriate spread constraints for HA workloads
- [ ] Test pod distribution: `kubectl get pods -o wide -A | grep <app>`

**Priority:** 🟡 **HIGH** - Affects HA and resource utilization

---

### Task 25: Re-evaluate Resource Limits and Quotas

**Status:** 🟡 HIGH PRIORITY - Cluster has more capacity

**Scope:**

- cluster/environments/lab/limits/*.yaml (ResourceQuota, LimitRange)
- apps/cluster/*/values.yaml (resources requests/limits)
- apps/user/*/values.yaml (resources requests/limits)

**Tasks:**

- [ ] Audit cluster/environments/lab/limits/ quotas
- [ ] Review resource requests/limits for cluster apps
- [ ] Review resource requests/limits for user apps
- [ ] Adjust based on new cluster capacity
- [ ] Test: verify pods can schedule without hitting quotas

**Priority:** 🟡 **HIGH** - May block application deployments

---

## 🔨 P2 Post-Bootstrap Tasks

### Task 12: Deploy NetBox IPAM/DCIM

**Status:** Planning Complete (Ready for Implementation)

**Plan:** [docs/diaries/netbox-implementation.md](diaries/netbox-implementation.md)

**Tasks:**

- [ ] Phase 1: Prerequisites & CNPG Config (DB, S3, Secrets)
- [ ] Phase 2: Create Wrapper Chart (apps/user/netbox)
- [ ] Phase 3: Create SealedSecrets
- [ ] Phase 4: ArgoCD Application & Deployment
- [ ] Phase 5: Verification (Login, Object Storage, HA)

**Priority:** 🟢 **MEDIUM**

---

### Task 9: Evaluate Trivy Operator Deployment

**Status:** ArgoCD Application disabled (argocd/disabled/cluster)

**Update:** Trivy Operator pinned to aquasec/trivy v0.68.2

**Context:** HarborGuard disabled due to bugs - Trivy Operator may be more suitable for runtime scanning

**Scanning Strategy:**

- Harbor built-in Trivy: Registry image scanning (pre-deployment) ✅ Active
- Trivy Operator: In-cluster workload scanning (runtime) 🔄 Under evaluation

**Tasks:**

- [ ] Decide: Re-enable or keep archived
- [ ] If re-enabled: confirm namespace and operator pods healthy
- [ ] If re-enabled: assess resource overhead (scan jobs + node collectors)

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
- ✅ ArgoCD WebUI accessible from Mac at <https://argocd.m0sh1.cc/> (HTTP 200)
- ✅ Dual-NIC deployment complete - all K8s nodes have VLAN 30 interfaces (10.0.30.50-54)
- ✅ local-path StorageClass available
- ✅ Proxmox CSI app enabled; StorageClasses available
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

- ⚠️ External-dns disabled for tunneled hostnames (argocd, s3, s3-console). DNS managed by Cloudflare tunnel CNAME + Unbound overrides.

**Next Phase:**

- [ ] Enable MinIO OSS operator + tenant ArgoCD apps and validate PVCs
- [ ] Re-enable remaining user apps (netzbremse + secrets-apps already enabled)

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
- [ ] Test ingress connectivity (*.m0sh1.cc)
- [ ] Verify CNPG PostgreSQL clusters provision successfully
- [ ] Check MinIO buckets created (cnpg-backups, k8s-backups)
- [ ] Validate Harbor registry accessible
- [ ] Test Gitea runner functionality

**Priority:** 🔴 **HIGH** - Post-bootstrap validation

---

### Task 20: Proxmox CSI DNS + Topology Labels Fix

**Status:** ✅ RESOLVED

**Root Causes:**

- CoreDNS static Proxmox host entries pointed at the wrong VLAN IPs
- Kubernetes node `topology.kubernetes.io/zone` labels used `pve01/02/03` while Proxmox nodes are `pve-01/02/03`

**Fix Applied:**

- CoreDNS static hosts updated in `cluster/environments/lab/coredns-configmap.yaml` to:
  - `pve01.m0sh1.cc` → `10.0.10.11`
  - `pve02.m0sh1.cc` → `10.0.10.12`
  - `pve03.m0sh1.cc` → `10.0.10.13`
- Node labels aligned with Proxmox node names:
  - `topology.kubernetes.io/zone=pve-01/02/03`
  - `topology.kubernetes.io/region=m0sh1-cc-lab`

**Validation:**

- Proxmox CSI controller logs clean (no JSON/DNS errors)
- StorageClasses present
- Test PVC bound and deleted successfully

**Priority:** ✅ CLOSED

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

- **nvme rpool** (fast storage)
  - k8s-nvme-fast (16K): latency-sensitive PVCs (DB WAL / fast tier)
  - k8s-nvme-general (128K): general NVMe-backed PVCs
  - k8s-nvme-object (1M): object storage backing (MinIO primary)
- **sata-ssd pool** (128GB SSD per node)
  - k8s-sata-general (128K): lower-priority PVCs
  - k8s-sata-object (1M): object storage backing (legacy, reduced quota)

**Object Storage Target (MinIO primary, Garage fallback):**

- StorageClass: proxmox-csi-zfs-nvme-object-retain (primary)
- StorageClass: proxmox-csi-zfs-sata-object-retain (fallback/legacy)
- Per-node quota: 75Gi on sata-ssd/k8s-sata-object
- Use case: CNPG backups + bulk object storage

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
- ✅ **ArgoCD WebUI accessible from Mac** at <https://argocd.m0sh1.cc/>
- ✅ HTTP 200 response, login page functional
- ✅ All base cluster apps deployed and operational (16 applications)
- ✅ Ansible playbook created: k3s-secondary-nic.yaml
- ✅ Fixed interface naming issue (ens19 vs eth1 altname)
- ✅ Fixed hostname mapping (labctrl vs lab-ctrl)
- ✅ Committed and pushed to Git (commit 921d8ff7)
- ✅ Cloudflare Tunnel external access validated (route order fixed)

**Network Architecture Validated:**

- VLAN 20: K8s primary interfaces (cluster communication)
- VLAN 30: K8s secondary interfaces (MetalLB L2Advertisement)
- MetalLB speakers: Detect ens19, ARP for 10.0.30.10
- Traefik: Reachable via LoadBalancer VIP from Mac

**Known Issues:**

- ⚠️ ArgoCD automated sync showing "Unknown" status (investigating)
- ⚠️ MinIO Degraded (CSI provisioning blocked - see Task 20)

**Next Immediate Steps:**

1. Test Proxmox CSI provisioning with PVC
2. Fix Proxmox cluster API endpoint (unblock MinIO)
3. Troubleshoot ArgoCD automated sync mechanism
4. Re-enable user apps (CNPG, Valkey, Renovate, pgadmin4)

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

**Last Updated:** 2026-01-30
**Next Review:** After Proxmox CSI PVC test
