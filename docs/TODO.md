# Infrastructure TODO

Completed work is archived in [done.md](done.md).

**Last Updated:** 2026-02-22

**Current Focus:** Phase 1 Infrastructure (LXCs, Bastion, DNS) → Security hardening → New applications

**Canonical Current-State Record:** [security-posture-status.md](security-posture-status.md)

---

## 🔴 High Priority

### Phase 1 Infrastructure Completion

**Status:** Not Started

1. **Terraform Infrastructure**
   - [ ] pbs LXC (Proxmox Backup Server)
   - [ ] smb LXC (SMB file server)
   - [ ] bastion VM (jump host)

2. **Ansible Configuration**
   - [ ] AdGuard Home DNS deployment
   - [ ] PBS configuration and backups
   - [ ] SMB shares and permissions

---

## 🟡 Medium Priority

### NetworkPolicy Baseline

**Objective:** Maintain and tune zero-trust networking (baseline rollout complete)

- [x] Default-deny baseline rollout across managed namespaces
- [x] Core allow policies for ingress/egress, DNS, kube-api, and namespace-specific traffic
- [x] Connectivity validation and phased rollout recovery
- [x] Policy patterns documented
- [ ] Residual tuning for app-specific regressions and exceptions (tracked in `security-posture-status.md`)
- [x] Baseline completion is reconciled and tracked via canonical record (`security-posture-status.md`)

### ArgoCD Project Boundaries

**Objective:** Isolate cluster apps from user apps

- [ ] Create `cluster-project` (apps/cluster/*)
- [ ] Create `user-project` (apps/user/*, namespace: apps)
- [ ] Update Application manifests to reference projects
- [ ] Test isolation
- [ ] Document strategy

### Workload Security Hardening

- [ ] Forgejo: Enforce `readOnlyRootFilesystem`, drop capabilities
- [ ] Harbor: Investigate Bitnami security contexts

### Trivy Operator

- [x] Runtime scanning operational in-cluster (evaluation complete)
- [ ] Continue resource/cadence tuning based on scan-job behavior and report freshness SLA (see `security-posture-status.md`)
- [x] Runtime status reconciliation moved to canonical record (`security-posture-status.md`)

### pgAdmin4 Debian/glibc Rebuild

- [ ] Investigate Option 2: Debian/glibc rebuild to eliminate musl DNS bug and ClusterIP pinning

---

## 🔵 Low Priority

### Expand Terraform

- [ ] Manage pve-01, pve-02 via Terraform

### Kiwix Server

- [ ] Deploy offline Wikipedia instance
