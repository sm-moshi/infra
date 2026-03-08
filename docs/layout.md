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

```text
.
├── ansible/
├── apps/
├── argocd/
├── cluster/
├── docs/
├── terraform/
├── tools/
├── .claude/
├── .codex/
├── .github/
├── .dcignore
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .gitmodules
├── .kube-linter.yaml
├── .pre-commit-config.yaml
├── .rumdl.toml
├── .yamllint
├── AGENTS.md
├── CLAUDE.md
├── README.md
├── cliff.toml
├── config.yaml
└── mise.toml
```

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

- apps/cluster/ — cluster-scoped platform services (infrastructure)
  - secrets-cluster/ — Kustomise app for cluster credentials (API keys, tokens)
- apps/user/ — user-facing workloads and application security
  - secrets-apps/ — Kustomise app for user app credentials (passwords, OAuth secrets)

Rules:

- No raw upstream Helm repos in ArgoCD
- Wrapper charts are the contract boundary
- Values live in the wrapper, not ArgoCD
- Static credentials/tokens → secrets-cluster/ or secrets-apps/
- TLS certificates with reflector → wrapper chart templates/

---

### argocd/

ArgoCD **Application manifests only**.

Structure:

- argocd/apps/apps-root.yaml (app-of-apps)
- argocd/apps/cluster/*.yaml (platform apps + secrets-cluster)
- argocd/apps/user/*.yaml (workload apps + secrets-apps)
- argocd/disabled/** (temporarily disabled apps)

No Helm charts here.

---

### cluster/

Kubernetes cluster-level configuration.

Structure:

- cluster/bootstrap/ — minimal DR bootstrap only
- cluster/environments/lab/ — operational overlays

Bootstrap is **not** the deployment mechanism.

---

### docs/

Project documentation.

Structure:

- docs/getting-started.md — Operational procedures (bootstrap, ArgoCD, Terraform, Ansible)
- docs/layout.md — Authoritative structure (this file)
- docs/cluster-placement.md — Node scheduling and placement policy
- docs/authentik-contract.md — Supported Authentik integration modes and app inventory
- docs/path-drift-guardrail.md — Guardrail contract (enforced by infra-guard path-drift)
- docs/TODO.md — Active infrastructure tasks
- docs/done.md — Completed infrastructure work
- docs/history.md — Chart version changes and supply chain exceptions
- docs/diaries/ — Implementation plans, architecture documents, and security scans
- docs/archive/ — Superseded documents

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

- tools/ci/ — guardrails, validation scripts, and the `infra-guard` binary
- tools/scripts/ — ops and recovery helpers (sealed-secrets, node labels, DNS collection)
- tools/m0sh1-devops/ — Claude Code agent definitions, skills, and reference docs
- tools/cli/ — Go CLI tools submodule (infra-cli: infra-guard, helm-scaffold, dhi-db)

---

### .claude/

Claude Code configuration: hooks, skills, agents, and session settings.

---

### .codex/

Codex session metadata and local automation support files (kept in repo intentionally).

---

### .github/

GitHub-specific configuration.

Structure:

- .github/workflows/ — CI/CD pipelines
- .github/agents/ — Copilot agent definitions
- .github/renovate/ — Renovate configuration
- .github/renovate.json — Renovate entry point
- .github/CODEOWNERS — Code ownership rules
- .github/SECURITY.md — Security policy
