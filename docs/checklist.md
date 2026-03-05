# Infrastructure Checklist

This checklist tracks **structural milestones**, not daily ops.

**Current State (2026-02-22):** Base cluster operational; Cloudflare Tunnel deployed; Tailscale subnet routing + split DNS operational; Proxmox CSI operational; Harbor/Auth/Headlamp/pgadmin4/Uptime-Kuma/Woodpecker deployed via ArgoCD; broad NetworkPolicy baseline complete; Trivy Operator runtime scanning operational.

**Canonical current posture (live reconciled):** [security-posture-status.md](diaries/reports/security-posture-status.md)

---

## Phase 0 — Repository Contract ✅

---

## Phase 1 — Infrastructure Deployment 🔄

**Status:** In progress (base cluster deployed; infra LXCs and Ansible services pending)

- [~] Terraform: Deploy 4-VLAN network infrastructure
  - [~] Infrastructure LXCs (pbs, smb)
  - [~] Bastion VM (Fedora)
- [~] Ansible: Deploy infrastructure services (PBS, SMB)

---

## Phase 2 — Storage Provisioning 🔄

**Status:** Active (Proxmox CSI operational; MinIO operator+tenant deployed; CNPG integration pending)

---

## Phase 3 — GitOps Bootstrap 🔄

**Status:** Core bootstrap complete; major user apps enabled and under ongoing hardening/tuning

- [x] **Harbor implementation**: Phases 5–7 complete (proxy cache wiring + UI + backup validation)
- [~] Disable user apps temporarily (netzbremse + secrets-apps enabled; rest in argocd/disabled/user)

---

## Phase 4 — Validation & Operations 🔄

**Status:** DNS infrastructure fixed, cert-manager stable, cloudflared deployed (external access validated)

- [~] External access via other *.m0sh1.cc apps tested (Traefik ingress routes; s3-console routed via tunnel, s3 API LAN-only)
- [x] Re-enable user apps: pgadmin4, Uptime-Kuma, Headlamp (all synced/healthy in ArgoCD)
- [~] Garage fallback chart drafted (review pending) (datahub-local/garage-helm)
- [~] Garage operator + UI stack drafted (review pending) (garage-operator + garage-ui)
- [x] **Enable Uptime-Kuma**: Enabled and synced in `apps` namespace
- [x] **Deploy Harbor**: Phases 5–7 complete; CNPG + backups validated; UI verified
- [x] **Enable pgadmin4**: Enabled and synced in `apps` namespace
- [x] **Enable Headlamp**: Enabled and synced in `apps` namespace
- [ ] **Semaphore CNPG Migration**: 🚨 Requires 8-phase implementation (docs/diaries/semaphore-implementation.md)
- [~] **Re-enable remaining user apps**: Gitea and Semaphore (pgadmin4/headlamp already enabled)

**Resolved Issues:**

- ✅ **apps-root wrong path**: Re-applied with correct argocd/apps path
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

**Temporarily Disabled Apps** (historical snapshot; superseded by live ArgoCD state):

- Keep this list as historical context only.
- Use `security-posture-status.md` and current `argocd app list` output as source of truth.

**External Access Plan:**

- Internal LAN: traefik-lan (10.0.30.10) via MetalLB ✅
- External Internet: Cloudflared tunnel (deployed and running)
  - SealedSecret deployed (credentials.json + cert.pem)
  - Tunnel connects to Cloudflare edge (pods Running)
  - External access validated for argocd.m0sh1.cc; s3-console routed via tunnel; s3 API LAN-only

---

## Future Enhancements (Post-Deployment)

- [x] NetworkPolicy baseline rollout complete (default-deny + allow policies); ongoing tuning tracked in `security-posture-status.md`
- [ ] ArgoCD Project boundaries (cluster vs user)
- [x] Trivy Operator runtime evaluation complete; ongoing scan-quality and SLA tuning tracked in `security-posture-status.md`
- [ ] Deploy NetBox IPAM/DCIM
- [ ] Kiwix Server (offline Wikipedia)
- [ ] Logging stack (if needed)
- [ ] Monitoring stack (if needed)
