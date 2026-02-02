# Infrastructure Checklist

This checklist tracks **structural milestones**, not daily ops.

**Current State (2026-02-02):** Base cluster operational; Cloudflare Tunnel deployed; external access validated for argocd.m0sh1.cc; Tailscale subnet routing + split DNS access model operational; Proxmox CSI operational; RustFS app disabled (namespace deleted); MinIO operator+tenant deployed (ingress TLS fix pending).

---

## Phase 0 — Repository Contract ✅

- [x] Guardrails defined (AGENTS.md, WARP.md)
- [x] Layout authoritative (docs/layout.md)
- [x] Path drift enforced (path-drift-check.sh)
- [x] Secrets strategy locked (SealedSecrets + Ansible Vault)
- [x] CI linting infrastructure (k8s-lint, ansible-idempotency, terraform-validate)
- [x] Pre-commit hooks configured (prek)
- [x] Mise task automation (cleanup, changelog, helm-lint, etc.)
- [x] Conventional commits enforced (cliff.toml)
- [x] Custom agent defined (m0sh1-devops with 12 toolsets)
- [x] Proxmox CSI configuration complete (5 datasets: pgdata, pgwal, registry, caches, minio)
- [x] Object storage datasets configured (sata-object 75G, nvme-object added)
- [x] Storage audit complete (472Gi nvme, 50Gi sata-ssd allocations validated)

---

## Phase 1 — Infrastructure Deployment 🔄

**Status:** Ready to begin fresh deployment

- [~] Terraform: Deploy 4-VLAN network infrastructure
  - [x] OPNsense VM (VMID 300, dual-NIC)
  - [~] Infrastructure LXCs (dns01, dns02, pbs, smb)
  - [~] Bastion VM (Fedora)
  - [x] K3s VMs (1 control plane, 4 workers)
- [x] OPNsense: Configure VLANs 10/20/30 and firewall rules
- [ ] Ansible: Deploy AdGuard Home DNS
- [~] Ansible: Deploy infrastructure services (PBS, SMB)
- [x] K3s: Bootstrap control plane (labctrl)
- [x] K3s: Join workers (horse01-04)
- [x] Retrieve kubeconfig from control plane

---

## Phase 2 — Storage Provisioning 🔄

**Status:** Documented, ready for deployment

- [x] Create ZFS datasets on all Proxmox nodes:
  - [x] rpool/k8s-nvme-fast (16K recordsize)
  - [x] rpool/k8s-nvme-general (128K recordsize)
  - [x] rpool/k8s-nvme-object (1M recordsize)
  - [x] sata-ssd/k8s-sata-general (128K recordsize)
  - [x] sata-ssd/k8s-sata-object (1M recordsize)
- [x] Configure Proxmox storage IDs:
  - [x] k8s-nvme-fast
  - [x] k8s-nvme-general
  - [x] k8s-nvme-object
  - [x] k8s-sata-general
  - [x] k8s-sata-object
- [x] Verify storage with `pvesm status`

---

## Phase 3 — GitOps Bootstrap 🔄

**Status:** Core bootstrap complete; storage/user apps still disabled

- [x] Bootstrap ArgoCD via install.yaml
- [x] Deploy root application (infra-root)
- [x] **FIX CRITICAL**: Re-applied infra-root with correct path (argocd/apps, not cluster/bootstrap)
- [x] CoreDNS integration with OPNsense Unbound (10.0.30.1) - wrapper chart disabled permanently
- [x] **CRITICAL DNS FIX**: Added UDP port to kube-dns Service (was TCP-only, broke all DNS)
- [x] MetalLB configured (IPAddressPool services-vlan30: 10.0.30.10-49)
- [x] Traefik LAN service assigned 10.0.30.10
- [x] Deploy cluster apps (ArgoCD, cert-manager, sealed-secrets, reflector, MetalLB, Traefik, external-dns, origin-ca-issuer, namespaces, secrets-cluster, secrets-apps)
- [x] Centralize 30 SealedSecrets: 9 cluster credentials to secrets-cluster/, 21 user app credentials to secrets-apps/
- [x] Create wildcard-s3-m0sh1-cc certificate for S3 ingresses (*.s3.m0sh1.cc, s3.m0sh1.cc, s3-console.m0sh1.cc)
- [x] Enable Proxmox CSI ArgoCD Application
- [x] Enable local-path storage application
- [x] Enable MinIO OSS operator + tenant apps (ingress TLS fix pending)
- [x] Verify StorageClasses created (local-path + Proxmox CSI)
- [x] Restore sealed-secrets encryption keys from backup
- [x] Regenerate all SealedSecrets with fresh API credentials
- [x] Create cert-manager Cloudflare API token SealedSecret
- [x] **cert-manager IPv6 FIX**: Added CoreDNS IPv6 AAAA suppression (template IN AAAA { rcode NXDOMAIN })
- [x] Issue wildcard TLS certificate (*.m0sh1.cc, m0sh1.cc) - successfully issued after IPv6 fix
- [x] Verify all critical applications Healthy/Synced
- [x] CloudNativePG wrapper: plugin-only Barman Cloud backups + ObjectStore + sidecar resources + zstd WAL compression
- [ ] CNPG backups verified to MinIO: WALs + base backup stored in `s3://cnpg-backups/cnpg-main/`
- [x] **Renovate configuration fixed**: Storage class nvme-fast-retain, 5Gi cache, renovate:43.0.9-full (Docker Hub)
- [x] **Uptime-Kuma configuration fixed**: Storage class nvme-fast-retain, chart bumped to 0.2.5
- [x] **Kured validated**: Production-ready, no changes needed
- [ ] **Harbor implementation**: 7-phase plan documented, storage classes + CNPG backups need fixes
- [ ] **Valkey storage fix**: Update to nvme-fast-retain storage class
- [~] Disable user apps temporarily (netzbremse + secrets-apps enabled; rest in argocd/disabled/user)

---

## Phase 4 — Validation & Operations 🔄

**Status:** DNS infrastructure fixed, cert-manager stable, cloudflared deployed (external access validated)

- [x] MetalLB assigns 10.0.30.10 to Traefik (traefik-lan service)
- [x] SealedSecrets controller operational with restored keys (3 encryption keys)
- [x] SealedSecrets regenerated (Proxmox CSI, Cloudflare, MinIO)
- [x] Proxmox CSI StorageClasses operational
- [x] local-path StorageClass available
- [x] external-dns Healthy with fresh Cloudflare API token
- [x] origin-ca-issuer Healthy with fresh Cloudflare API token
- [x] cert-manager Healthy, wildcard certificate issued successfully (after IPv6 fix)
- [x] TLS secret wildcard-m0sh1-cc created in traefik namespace
- [x] **CoreDNS FIXED**: k3s CoreDNS integrated with OPNsense Unbound (10.0.30.1)
- [x] **CRITICAL DNS FIX**: Added UDP port to kube-dns Service (was TCP-only, broke all DNS)
- [x] DNS resolution validated (internal k8s services + external domains working)
- [x] CoreDNS wrapper chart permanently disabled (moved to argocd/disabled/)
- [x] **cert-manager TLS timeout FIXED**: IPv6 AAAA suppression resolves Let's Encrypt ACME connectivity
- [x] Test certificate validated (acme-check.m0sh1.cc issued successfully, expires 2026-04-29)
- [x] **cloudflared wrapper chart**: Converted from custom chart to community-charts/cloudflared v2.2.6
- [x] cloudflared SealedSecret generated with tunnel credentials.json
- [x] cloudflared Helm lint validation (chart validation vs existingSecret conflict)
- [x] cloudflared ArgoCD sync and deployment
- [x] Cloudflare Tunnel connectivity validated (Zero Trust dashboard shows Healthy)
- [x] Resolve WARP client CF_DNS_PROXY_FAILURE (Docker Desktop DNS proxy)
- [x] Fix Cloudflare published hostname routing (argocd.m0sh1.cc route above wildcard)
- [x] External access validated for argocd.m0sh1.cc (Cloudflare Tunnel + Access)
- [~] External access via other *.m0sh1.cc apps tested (Traefik ingress routes; s3-console routed via tunnel, s3 API LAN-only)
- [x] Test Proxmox CSI provisioning (test PVC bound and deleted)
- [x] MinIO OSS operator+tenant deployed; PVCs bound (nvme-object)
- [ ] Fix MinIO ingress TLS (reflect wildcard-s3-m0sh1-cc into minio-tenant + Traefik ServersTransport)
- [ ] Re-enable user apps: CNPG → Valkey → Renovate → pgadmin4 (netzbremse already enabled)
- [~] Garage fallback chart drafted (review pending) (datahub-local/garage-helm)
- [~] Garage operator + UI stack drafted (review pending) (garage-operator + garage-ui)
- [x] RustFS app disabled; namespace deleted
- [x] Tailscale subnet routing operational (pve-01 advertising VLAN10/20/30)
- [x] Tailscale ACL auto-approval for internal subnets verified
- [x] macOS and iOS clients validated with subnet routes (WiFi + mobile)
- [x] Split DNS via Tailscale DNS + OPNsense Unbound operational
- [x] Internal DNS override for argocd.m0sh1.cc → 10.0.30.10
- [x] IPv6 AAAA suppressed internally to prevent Cloudflare routing conflicts
- [x] Cloudflare Access bypassed on tailnet; enforced off-tailnet
- [x] Single-FQDN access model validated (dual trust planes)
- [ ] **Enable Kured**: Move to argocd/apps/cluster/ (no dependencies, ready immediately)
- [ ] **Enable Renovate**: Move to argocd/apps/user/ (no dependencies after Docker Hub change)
- [ ] **Enable Uptime-Kuma**: Verify wildcard-m0sh1-cc secret in apps namespace, then move to argocd/apps/user/
- [ ] **Deploy Harbor**: Execute 7-phase implementation plan (critical for user apps)
- [ ] **Enable pgadmin4**: ✅ Storage class fixed (nvme-general-retain), ready to move to argocd/apps/user/
- [ ] **Enable Headlamp**: ✅ Production-ready (no changes needed), ready to move to argocd/apps/user/
- [ ] **Semaphore CNPG Migration**: 🚨 Requires 8-phase implementation (docs/diaries/semaphore-implementation.md)
- [ ] **Re-enable user apps**: Gitea, Semaphore, pgadmin4, Headlamp (after prerequisites resolved)

**Resolved Issues:**

- ✅ **infra-root wrong path**: Re-applied with correct argocd/apps path
- ✅ **CoreDNS wrapper chart disaster**: Disabled permanently (immutable selector conflicts)
- ✅ **DNS completely broken**: CoreDNS wrapper destroyed kube-dns Service endpoint mapping
- ✅ **CRITICAL DNS FIX**: kube-dns Service missing UDP port - added UDP+TCP, DNS working
- ✅ **OPNsense Unbound integration**: CoreDNS forwards to 10.0.30.1 (VLAN30 Unbound)
- ✅ **CoreDNS configmap tracking**: Removed ArgoCD annotations
- ✅ **PVC provisioning blocked**: All 6 PVCs failed "no such host" - CoreDNS fix resolved
- ✅ **SealedSecrets decryption failures**: Keys restored from backup (3 keys active)
- ✅ **external-dns/origin-ca-issuer Degraded**: Regenerated with fresh Cloudflare tokens
- ✅ **Proxmox CSI Degraded**: Regenerated with fresh API credentials
- ✅ **cert-manager TLS timeout**: IPv6 AAAA suppression fixes Let's Encrypt connectivity
- ✅ **cert-manager ACME DNS-01 failures**: Created cloudflare-api-token SealedSecret
- ✅ **wildcard certificate issuance**: cert-manager Healthy, TLS secret created
- ✅ **DNS resolution**: Internal (argocd-redis) and external (google.com) validated
- ✅ **Proxmox CSI API failures**: CoreDNS static hosts pinned to 10.0.10.x + node zone labels aligned (pve-01/02/03)
- ✅ **external-dns/CNAME conflicts**: Disabled external-dns on tunneled ingresses (argocd, s3, s3-console); DNS managed via Cloudflare Tunnel + Unbound overrides
- ✅ **Remote access blocked on WiFi**: Implemented Tailscale subnet routing + split DNS; verified full internal access (ArgoCD, Nautik, mobile clients)

**Temporarily Disabled Apps** (moved to argocd/disabled/):

- Cluster: cloudnative-pg, coredns, kubescape-operator, **kured** (✅ ready), tailscale-operator, trivy-operator, **valkey** (⚠️ needs storage fix)
- User: adguardhome-sync, gitea, **harbor** (🔴 implementation required), harborguard, headlamp, homepage, pgadmin4, **renovate** (✅ ready), semaphore, **uptime-kuma** (✅ ready)

**External Access Plan:**

- Internal LAN: traefik-lan (10.0.30.10) via MetalLB ✅
- External Internet: Cloudflared tunnel (deployed and running)
  - SealedSecret deployed (credentials.json + cert.pem)
  - Tunnel connects to Cloudflare edge (pods Running)
  - External access validated for argocd.m0sh1.cc; s3-console routed via tunnel; s3 API LAN-only

---

## Future Enhancements (Post-Deployment)

- [ ] Implement NetworkPolicy baseline (default-deny)
- [ ] ArgoCD Project boundaries (cluster vs user)
- [ ] Trivy Operator evaluation (runtime scanning)
- [ ] Deploy NetBox IPAM/DCIM
- [ ] Kiwix Server (offline Wikipedia)
- [ ] Logging stack (if needed)
- [ ] Monitoring stack (if needed)
