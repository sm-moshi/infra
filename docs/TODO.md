# Infrastructure TODO

Completed work is archived in [done.md](done.md).

**Last Updated:** 2026-02-22

**Current Focus:** Phase 1 Infrastructure (LXCs, Bastion, DNS) → Security hardening → New applications

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

**Objective:** Implement zero-trust networking

- [ ] Default-deny NetworkPolicy for apps namespace
- [ ] Allow-ingress-from-traefik policy
- [ ] Allow-egress-to-dns (CoreDNS) policy
- [ ] Allow-egress-to-CNPG policy
- [ ] Test connectivity between pods
- [ ] Document policy patterns

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

- [ ] Assess resource overhead from scan jobs

### pgAdmin4 Debian/glibc Rebuild

- [ ] Investigate Option 2: Debian/glibc rebuild to eliminate musl DNS bug and ClusterIP pinning

---

## 🔵 Low Priority

### Expand Terraform

- [ ] Manage pve-01, pve-02 via Terraform

### Kiwix Server

- [ ] Deploy offline Wikipedia instance
