# Repository Layout (Authoritative)

This document defines the **canonical directory structure** for the `infra`
repository.

This file is the **single source of truth** for:

- guardrails
- CI validation
- contributor expectations

If reality diverges from this file, reality must be fixed.

---

## Top-Level Structure

.
├── ansible/
├── apps/
├── argocd/
├── cluster/
├── docs/
├── terraform/
├── tools/
├── .github/
├── AGENTS.md
├── WARP.md
├── README.md
├── SECURITY.md
├── CHANGELOG.md
├── config.yaml
├── mise.toml
├── renovate.json
└── cliff.toml

---

## Directory Responsibilities

### ansible/

Host provisioning and configuration:

- Proxmox nodes
- LXCs / VMs
- k3s nodes
- system services (DNS, SMB, backups)

Secrets: **Ansible Vault only**

---

### apps/

Helm **wrapper charts only**.

Structure:

- apps/cluster/ → cluster-scoped services
- apps/user/ → user-facing workloads

Rules:

- No raw upstream Helm repos in ArgoCD
- Wrapper charts are the contract boundary
- Values live in the wrapper, not ArgoCD

---

### argocd/

ArgoCD **Application manifests only**.

Structure:

- argocd/apps/root.yaml (app-of-apps)
- argocd/apps/cluster/*.yaml
- argocd/apps/user/*.yaml
- argocd/disabled/**

No Helm charts here.

---

### cluster/

Kubernetes cluster-level configuration.

Structure:

- cluster/bootstrap/ → minimal DR bootstrap only
- cluster/environments/lab/ → operational overlays

Bootstrap is **not** the deployment mechanism.

---

### terraform/

Infrastructure as Code:

- Proxmox VMs / LXCs
- Providers defined per environment
- No secrets committed

---

### tools/

Operational tooling and CI helpers.

Subdirectories:

- tools/ci/ → guardrails and validation
- tools/scripts/ → ops and recovery helpers
- tools/m0sh1-devops/ → reference tooling and skills

---

## Non-Negotiable Rules

- No plaintext secrets
- No imperative cluster changes outside bootstrap recovery
- No undocumented top-level paths
- No generated artifacts committed

Violations are rejected by automation.
