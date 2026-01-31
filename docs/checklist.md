# Infrastructure Checklist

This checklist tracks **structural milestones**, not daily ops.

**Current State (2026-01-30):** Base cluster operational; Cloudflare Tunnel deployed; external access validated for argocd.m0sh1.cc.

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
- [x] MinIO storage on sata-ssd pool configured (50Gi, ZFS optimized)
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
  - [x] rpool/k8s/pgdata (16K recordsize)
  - [x] rpool/k8s/pgwal (128K recordsize)
  - [x] rpool/k8s/registry (128K recordsize)
  - [x] rpool/k8s/caches (128K recordsize)
  - [x] sata-ssd/minio (1M recordsize, parent)
  - [x] sata-ssd/minio/data (1M recordsize, actual storage)
- [x] Configure Proxmox storage IDs:
  - [x] k8s-pgdata
  - [x] k8s-pgwal
  - [x] k8s-registry
  - [x] k8s-caches
  - [x] minio-data
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
- [x] Create wildcard-s3-m0sh1-cc certificate for RustFS S3 ingresses (*.s3.m0sh1.cc, s3.m0sh1.cc, s3-console.m0sh1.cc)
- [ ] Enable Proxmox CSI ArgoCD Application (currently in argocd/disabled/cluster)
- [x] Enable local-path storage application
- [ ] Enable MinIO storage application (not enabled in argocd/apps/cluster)
- [ ] Verify StorageClasses created (local-path only until Proxmox CSI enabled)
- [x] Restore sealed-secrets encryption keys from backup
- [x] Regenerate all SealedSecrets with fresh API credentials
- [x] Create cert-manager Cloudflare API token SealedSecret
- [x] **cert-manager IPv6 FIX**: Added CoreDNS IPv6 AAAA suppression (template IN AAAA { rcode NXDOMAIN })
- [x] Issue wildcard TLS certificate (*.m0sh1.cc, m0sh1.cc) - successfully issued after IPv6 fix
- [x] Verify all critical applications Healthy/Synced
- [x] Disable user apps temporarily (all user apps moved to argocd/disabled/user)

---

## Phase 4 — Validation & Operations 🔄

**Status:** DNS infrastructure fixed, cert-manager stable, cloudflared deployed (external access validated)

- [x] MetalLB assigns 10.0.30.10 to Traefik (traefik-lan service)
- [x] SealedSecrets controller operational with restored keys (3 encryption keys)
- [x] SealedSecrets regenerated (Proxmox CSI, Cloudflare, MinIO)
- [ ] Proxmox CSI StorageClasses operational (Proxmox CSI app currently disabled)
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
- [ ] External access via other *.m0sh1.cc apps tested (Traefik ingress routes)
- [ ] Test Proxmox CSI provisioning (create test PVC, verify ZFS volume creation)
- [ ] MinIO PVC bound and operational
- [ ] Re-enable user apps: CNPG → Valkey → Renovate → pgadmin4 (after cloudflared validated)
- [ ] Garage fallback chart drafted and reviewed (datahub-local/garage-helm)
- [ ] Garage operator + UI stack drafted and reviewed (garage-operator + garage-ui)

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

**Temporarily Disabled Apps** (moved to argocd/disabled/):

- Cluster: cloudnative-pg, coredns, kubescape-operator, kured, tailscale-operator, trivy-operator, valkey
- User: adguardhome-sync, gitea, harbor, harborguard, headlamp, homepage, pgadmin4, renovate, semaphore, uptime-kuma

**External Access Plan:**

- Internal LAN: traefik-lan (10.0.30.10) via MetalLB ✅
- External Internet: Cloudflared tunnel (deployed and running)
  - SealedSecret deployed (credentials.json + cert.pem)
  - Tunnel connects to Cloudflare edge (pods Running)
  - External access validated for argocd.m0sh1.cc; other hostnames pending

---

## Future Enhancements (Post-Deployment)

- [ ] Implement NetworkPolicy baseline (default-deny)
- [ ] ArgoCD Project boundaries (cluster vs user)
- [ ] Trivy Operator evaluation (runtime scanning)
- [ ] Deploy NetBox IPAM/DCIM
- [ ] Kiwix Server (offline Wikipedia)
- [ ] Logging stack (if needed)
- [ ] Monitoring stack (if needed)
