# Infrastructure TODO

Completed work is archived in [done.md](done.md).

**Last Updated:** 2026-03-05

**Current Focus:** Phase 1 Infrastructure (LXCs, Bastion, DNS) → ArgoCD project isolation → New applications

**Canonical Current-State Record:** [security-posture-status.md](diaries/reports/security-posture-status.md)

---

## 🔴 High Priority

### Phase 1 Infrastructure Completion

**Status:** Not Started

1. **Terraform Infrastructure**
   - [ ] smb LXC (SMB file server)
   - [ ] bastion VM (jump host)

2. **Ansible Configuration**
   - [ ] PBS configuration and backups
   - [ ] SMB shares and permissions

---

## 🟡 Medium Priority

### ArgoCD Project Boundaries

**Objective:** Isolate cluster apps from user apps

- [x] Create `cluster` AppProject (apps/cluster/*)
- [x] Create `user` AppProject (apps/user/*, namespace: apps)
- [x] Update Application manifests to reference projects
- [ ] Test isolation (verify ArgoCD sync after deploy)
- [ ] Document strategy

---

## 🔵 Low Priority

### Expand Terraform

- [ ] Manage pve-01, pve-02 via Terraform

### Kiwix Server

- [ ] Deploy offline Wikipedia instance
