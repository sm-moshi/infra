# AGENTS — Repository Enforcement Contract

This document defines **mandatory rules** for all automated agents, CI systems,
and AI-assisted tooling interacting with this repository.

This includes (but is not limited to):

- GitHub Actions
- Gitea CI
- Renovate
- pre-commit hooks
- Copilot / ChatGPT / coding agents
- Any future automation

This file is **authoritative**. Violations are considered defects.

---

## 1. Scope & Intent

This repository is a **GitOps-managed infrastructure codebase**.

Primary goals:

- Declarative, reproducible infrastructure
- Public-by-design safety (no secrets in Git)
- Single source of truth in Git
- Enforcement over convention

Automation **must not improvise architecture**.

---

## 2. Absolute Prohibitions (Hard Rules)

### 2.1 No Imperative Operations

Automated agents MUST NOT:

- run `kubectl apply`, `kubectl delete`
- run `helm install`, `helm upgrade`
- mutate live cluster state outside bootstrap recovery

All changes flow through **Git → ArgoCD → Cluster**.

---

### 2.2 No Secrets in Git

Automated agents MUST NOT:

- introduce plaintext secrets
- commit `.env`, `op.env`, `terraform.tfstate`, `*.tfvars`
- generate unsealed Kubernetes `Secret` manifests

Allowed mechanisms:

- Kubernetes: **Bitnami SealedSecrets**
- Hosts / infra: **Ansible Vault**

Violations are blocked by CI and pre-commit guards.

---

### 2.3 No Repo Structure Drift

Automated agents MUST NOT:

- introduce new top-level directories
- move apps across `apps/cluster` ↔ `apps/user`
- restructure wrapper charts
- create README files in `apps/cluster/` or `apps/user/` wrapper chart directories

The authoritative layout is defined in `docs/layout.md`.

**Documentation placement**:

- Comprehensive documentation belongs in `docs/`
- Wrapper charts contain ONLY: `Chart.yaml`, `values.yaml`, `templates/`, `charts/`
- Never create README.md files in wrapper chart directories

---

## 3. Decision Authority

When conflicts arise:

1. `docs/` overrides comments and READMEs
2. Git manifests override runtime state
3. Reality must be reconciled **to Git**, never the opposite

Agents must not attempt “quick fixes” outside Git.

---

## 4. GitOps / Kubernetes Rules

- All workloads are deployed via ArgoCD Applications
- Wrapper charts are the **contract boundary**
- Upstream charts may change; wrapper charts must not
- Chart version bumps are mandatory when behavior changes

Bootstrap (`cluster/bootstrap/`) is:

- minimal
- recovery-only
- never extended post-handoff

---

## 5. Terraform Rules

- Only `terraform/envs/lab` is active
- No new backends without redesign
- No secrets in modules
- State must match reality before merges

Agents may propose diffs but must not apply plans.

---

## 6. Ansible Rules

- Idempotency is mandatory
- `ansible-lint` must pass
- Dry-runs (`--check`, `--diff`) preferred
- Secrets pulled exclusively from Vault

---

## 7. CI & Automation Behavior

- CI is **policy enforcement**, not convenience tooling
- Shared logic lives in `tools/ci/*`
- GitHub Actions orchestrate, not re-implement logic
- Fork PRs must never require secrets

---

## 8. AI / Copilot / Coding Agent Constraints

If ContextStream credits are unavailable, agents MAY use local tools without
ContextStream search to proceed.

AI systems MUST:

- propose changes as diffs
- respect existing architecture
- verify upstream architectural assumptions before implementation
- stop if a solution requires fighting the platform or extensive workarounds
- avoid speculative refactors
- never generate secrets, tokens, credentials, or sample keys without using Ansible Vault or SealedSecrets

AI systems MUST NOT:

- introduce new top-level directories (see §2.3)
- bypass guard scripts
- silence failing checks

---

## 9. Violations

If an agent cannot comply:

- it must fail loudly
- it must not attempt workarounds
- it must request human intervention

Silently “fixing” policy violations is forbidden.

---

**This file is binding.**

<!-- BEGIN ContextStream -->
### When to Use ContextStream Search

✅ Project is indexed and fresh
✅ Looking for code by meaning/concept
✅ Need semantic understanding

---

<!-- END ContextStream -->
