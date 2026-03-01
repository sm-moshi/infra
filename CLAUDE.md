# CLAUDE — Runtime Instructions

This repository is GitOps infrastructure.

**Authoritative policy lives in [AGENTS.md](AGENTS.md).**
If this file conflicts with `AGENTS.md`, follow `AGENTS.md`.

### Critical rules Claude must enforce

- No imperative cluster writes outside bootstrap recovery.
  - Forbidden families: mutating `kubectl`, `helm install/upgrade/uninstall/rollback`, mutating `argocd app` commands.
  - Allowed: read-only observability and approved GitOps reconciliation commands in `AGENTS.md`.
- All changes must flow **Git → ArgoCD → Cluster**.
- Never add plaintext secrets or unsealed Kubernetes `Secret` manifests.
  - Never commit `.env`, `op.env`, `terraform.tfstate`, `*.tfvars`.
  - Use SealedSecrets / Ansible Vault.
- No repo structure drift:
  - no new top-level dirs,
  - no `apps/cluster` ↔ `apps/user` moves,
  - no wrapper chart restructuring,
  - no wrapper-chart `README.md` files.
- Propose diffs; do not bypass guard scripts; avoid speculative refactors.
- If blocked by policy/platform conflict: fail loudly and request human intervention.

### Style

- Use British English in all prose (e.g. colour, organisation, behaviour, licence, normalise).

### Operating protocol (compact)

1. Read context first from Basic Memory MCP.
2. Prefer `mise run <task>` and repository guardrails.
3. Validate before proposing final changes.

### Fast references

- Policy: [AGENTS.md](AGENTS.md)
- Ops guide: [docs/getting-started.md](docs/getting-started.md)
- Repo layout: [docs/layout.md](docs/layout.md)
- Tasks: [mise.toml](mise.toml)
- Memory requirements: [AGENTS.md §8.1](AGENTS.md#81-persistent-knowledge-basic-memory-mcp)
