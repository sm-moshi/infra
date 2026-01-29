# Infrastructure Completed Tasks

**Last Updated:** 2026-01-29 09:00 UTC

This document tracks completed infrastructure work that has been verified and is operational.

---

## ✅ Completed Checklist Milestones (2026-01-29)

- **Phase 0 — Repository Contract:** Guardrails, layout, CI validation, secrets strategy, mise tasks, and storage audit (NVMe + sata-ssd) completed.
- **Phase 2 — Storage Provisioning:** All Proxmox ZFS datasets created (pgdata/pgwal/registry/caches/minio), storage IDs configured, and `pvesm status` verified.
- **Phase 3 — GitOps Bootstrap:** ArgoCD bootstrapped and infra-root corrected to `argocd/apps`; base cluster apps deployed (Traefik, MetalLB, cert-manager, sealed-secrets, external-dns, origin-ca-issuer, namespaces, secrets-cluster); StorageClasses present; sealed-secrets keys restored; wildcard TLS issued.

---

## ✅ COMPLETED - Dual-NIC Deployment for MetalLB L2 (2026-01-29)

### ✅ Task: Deploy Dual-NIC Configuration for K8s Nodes

**Resolution:** Successfully deployed secondary NICs on VLAN 30 to all K8s nodes, resolving MetalLB L2 ARP limitation

**Completed Actions:**

1. ✅ User manually added secondary NICs to all 5 K8s VMs in Proxmox (VMID 201, 210-213)
2. ✅ Created Ansible playbook for systemd-networkd configuration:
   - ansible/playbooks/k3s-secondary-nic.yaml
   - Detects interface name (ens19, not eth1 altname)
   - Configures static IPs on VLAN 30 (10.0.30.50-54)
   - Adds route for 10.0.30.0/24 scope link
3. ✅ Fixed Ansible playbook issues:
   - Hostname mapping (lab-ctrl→labctrl, horse-01→horse01)
   - Interface detection using `ip -o link show | grep 'ens19:'`
   - Added `check_mode: no` for detection task
   - Added `set -euo pipefail` for shell script safety
4. ✅ Deployed systemd-networkd configurations to all 5 nodes:
   - labctrl: 10.0.30.50/24
   - horse01: 10.0.30.51/24
   - horse02: 10.0.30.52/24
   - horse03: 10.0.30.53/24
   - horse04: 10.0.30.54/24
5. ✅ Restarted MetalLB speaker pods to detect new interfaces
6. ✅ Validated MetalLB VIP assignment: traefik-lan → 10.0.30.10
7. ✅ Validated ArgoCD WebUI access from Mac:
   - URL: <https://argocd.lab.m0sh1.cc/>
   - HTTP 200 response
   - Login page accessible in browser
   - Certificate warning expected (*.m0sh1.cc vs*.lab.m0sh1.cc)
8. ✅ Updated Terraform configuration:
   - terraform/envs/lab/vms.tf (dual-NIC network_devices)
   - terraform/envs/lab/vms-dual-nic-CHANGES.tf.reference (documentation)
9. ✅ Fixed linting issues and committed to Git:
   - Commit: 921d8ff7 "feat(network): Deploy dual-NIC configuration for MetalLB L2"
   - Files: ansible/playbooks/k3s-secondary-nic.yaml, terraform/envs/lab/vms.tf, terraform/envs/lab/vms-dual-nic-CHANGES.tf.reference

**Network Architecture:**

- Primary NIC (eth0): VLAN 20 (10.0.20.0/24) - Pod network, cluster communication
- Secondary NIC (ens19): VLAN 30 (10.0.30.0/24) - MetalLB L2Advertisement only
- MetalLB pool: services-vlan30 (10.0.30.10-49)
- Traefik LoadBalancer: 10.0.30.10

**Problem Solved:**

- MetalLB L2 mode requires nodes to be on same VLAN as LoadBalancer VIPs for ARP
- Original architecture: Nodes on VLAN 20, MetalLB VIPs on VLAN 30 (cross-VLAN ARP impossible)
- Solution: Add secondary NICs on VLAN 30 so MetalLB speakers can ARP for VIPs

**Validation:**

- Interface status: All 5 nodes have ens19 UP with VLAN 30 IPs
- MetalLB assignment: traefik-lan LoadBalancer assigned 10.0.30.10 successfully
- Connectivity: curl <https://argocd.lab.m0sh1.cc/> returns HTTP 200
- ArgoCD WebUI: Accessible from Mac, login page displays
- Ping status: ICMP fails (routing quirk) but HTTP/HTTPS works perfectly

**Documentation:**

- Deployment guide: [docs/diaries/dual-nic-deployment-guide.md](diaries/dual-nic-deployment-guide.md)
- Network architecture: [docs/diaries/network-vlan-architecture.md](diaries/network-vlan-architecture.md)

**Commits:** 921d8ff7

**Status:** ✅ Complete - ArgoCD WebUI operational, MetalLB L2 working

**Next:** Deploy Cloudflare Tunnel to fix certificate warning and enable external access

---

## ✅ COMPLETED - Kubescape Operator Deployment (2026-01-19)

### ✅ Task: Deploy Kubescape Operator for Cluster Security Scanning

**Resolution:** Kubescape Operator deployed successfully with GitOps-friendly configuration

**Completed Actions:**

1. ✅ Reviewed Kubescape values.yaml configuration:
   - Enabled standard scanning capabilities (configuration, continuous, node, vulnerability)
   - Disabled auto-upgrade for GitOps stability
   - Configured runtime path for container runtime detection
2. ✅ Monitored first ArgoCD sync:
   - Operator pods healthy
   - Scan pods running successfully
   - CRDs installed correctly
3. ✅ Deferred monitoring integration:
   - Decision: Wait until observability stack restored before Prometheus/Grafana integration
   - Kubescape can operate independently and store scan results in cluster

**Configuration:**

- Wrapper chart: apps/cluster/kubescape-operator/
- ArgoCD Application: argocd/apps/cluster/kubescape-operator.yaml
- Scanning capabilities: Configuration, Continuous, Node, Vulnerability
- Auto-upgrade: Disabled (GitOps-managed)

**Status:** ✅ Complete - Operator operational, scanning cluster for security compliance

---

## ✅ COMPLETED - Infrastructure Design (2026-01-22)

### ✅ Task: 4-VLAN Network Architecture Design

**Resolution:** Complete network architecture designed and validated for 4-VLAN infrastructure

**Completed Actions:**

1. ✅ Designed 4-VLAN network segmentation:
   - Home/WiFi (10.0.0.0/24): Consumer devices
   - VLAN 10 (10.0.10.0/24): Infrastructure hosts
   - VLAN 20 (10.0.20.0/24): Kubernetes nodes
   - VLAN 30 (10.0.30.0/24): Service VIPs (MetalLB)
2. ✅ Fixed IP conflicts:
   - dns02: 10.0.10.11 → 10.0.10.14 (was conflicting with pve-01)
   - smb: 10.0.10.110 → 10.0.10.23 (cleaner numbering)
3. ✅ Simplified MetalLB configuration:
   - Removed VLAN 10 and VLAN 20 pools
   - Single VLAN 30 pool (10.0.30.10-49) for all exposed services
   - Reduces L2/ARP failure modes
4. ✅ Updated Traefik configuration:
   - LoadBalancerIP: 10.0.30.10
   - Added metallb.universe.tf/address-pool annotation
5. ✅ Updated DNS rewrites (AdGuard Home):
   - Infrastructure hosts point to VLAN 10 IPs
   - K8s nodes point to VLAN 20 IPs
   - All apps point to Traefik VIP (10.0.30.10)
6. ✅ Updated Terraform configurations:
   - terraform/envs/lab/lxcs.tf (dns02, smb IPs fixed)
   - terraform/envs/lab/vms.tf (K8s nodes on VLAN 20)
   - terraform/envs/lab/main.tf (VLAN gateways defined)
7. ✅ Created comprehensive documentation:
   - docs/network-vlan-architecture.md (complete architecture)
   - docs/terraform-vlan-rebuild.md (implementation guide)

**Documentation:**

- Architecture: [diaries/network-vlan-architecture.md](diaries/network-vlan-architecture.md)
- Implementation: [diaries/terraform-vlan-rebuild.md](diaries/terraform-vlan-rebuild.md)

**Status:** ✅ Design complete, ready for deployment (terraform apply)

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

### ⏸️ Task 7: Deploy Semaphore (ABANDONED - 2026-01-19)

**Status:** Deployment abandoned after 37 chart iterations due to architectural incompatibility

**Decision:** Semaphore's runner registration architecture incompatible with Kubernetes ingress-based deployments

**Completed Work:**

1. ✅ Created Semaphore wrapper chart (v0.1.37)
2. ✅ Deployed Semaphore UI server (healthy, accessible at <https://semaphore.m0sh1.cc>)
3. ✅ Configured PostgreSQL integration via CNPG
4. ✅ Configured Valkey (Redis) caching
5. ✅ Created 2 runner deployments with pod anti-affinity
6. ✅ Attempted 6+ configuration strategies over 37 iterations

**Critical Issue:**

- Semaphore server advertises internal Kubernetes ClusterIP (`tcp://10.43.239.188:3000`) to runners during authentication
- Runners fail validation: `panic: value of field 'Port' is not valid: tcp://10.43.239.188:3000`
- No configuration override exists to force external ingress URL
- Architecture assumes runners can directly access internal service port

**Troubleshooting Attempts:**

- ❌ Removed port from runner ConfigMap web_host
- ❌ Added `SEMAPHORE_RUNNER_API_URL` to server env vars (not recognized)
- ❌ Tried pure environment variable configuration (runner requires --config file)
- ❌ Tested NodePort service (security compromise)
- ❌ Investigated database option table (empty, not used for this config)

**Final Action:**

- Moved `argocd/apps/user/semaphore.yaml` → `argocd/disabled/user/semaphore.yaml`
- ArgoCD will automatically prune all resources (pods, PVCs, deployments, configmaps, secrets)
- Wrapper chart preserved in `apps/user/semaphore/` for future reference
- Deployment plan updated with lessons learned: `docs/semaphore-deployment-plan.md`

**Alternative Approach:**

- Use Gitea Actions with self-hosted runners for Ansible playbook execution
- Ansible workflows managed via Git-based CI/CD pipelines
- No need for separate automation platform

**Lessons Learned:**

- Semaphore designed for environments where runners can directly reach server's service port
- Kubernetes ingress-based deployments require workarounds (NodePort, sidecars) that compromise security
- Time investment (37 iterations) exceeded benefit for homelab scale
- Alternative tools (AWX, Jenkins + Ansible, Gitea Actions) better suited for Kubernetes

**Commits:** (final cleanup commit pending)

**Outcome:** ⏸️ Semaphore deployment abandoned; wrapper chart archived for future reference if upstream adds ingress support

---

### ✅ Task 5: Configure registry auth (Harbor + Docker Hub + GHCR) (2026-01-19)

**Status:** ✅ Registry auth applied to K3s nodes

**Completed Actions:**

1. ✅ Updated K3s registries templates with Harbor, Docker Hub, and GHCR auth blocks:
   - `ansible/roles/k3s_control_plane/templates/registries.yaml.j2`
   - `ansible/roles/k3s_worker/templates/registries.yaml.j2`
2. ✅ Stored registry credentials in Ansible Vault (`harbor_registry_auth`, `dockerhub_auth`, `ghcr_io_auth`)
3. ✅ Re-ran K3s Ansible playbooks and verified `/etc/rancher/k3s/registries.yaml` renders correctly
4. ✅ Control plane recovered after fixing registry YAML indentation

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
