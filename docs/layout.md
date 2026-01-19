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
├── memory-bank/
├── terraform/
├── tools/
├── .github/
├── AGENTS.md
├── README.md
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

### docs/

Project documentation.

Structure:

- docs/warp.md → Tools & operational guide
- docs/layout.md → Authoritative structure
- docs/checklist.md → Phase progression
- docs/archive/ → Superseded documents

---

### memory-bank/

AI project context and decision history.

Structure:

- activeContext.md → Current state and goals
- systemPatterns.md → Architecture and standards
- decisionLog.md → History of technical choices
- progress.md → Status tracking

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

### .github/

GitHub-specific configuration.

Structure:

- .github/workflows/ → CI/CD pipelines
- .github/agents/ → copilot agent definitions
- .github/copilot-instructions.md → repository-wide Copilot guidance
- .github/SECURITY.md → security policy

Agents enforce AGENTS.md rules and integrate Memory Bank.

---

## Non-Negotiable Rules

- No plaintext secrets
- No imperative cluster changes outside bootstrap recovery
- No undocumented top-level paths
- No generated artifacts committed

Violations are rejected by automation.
