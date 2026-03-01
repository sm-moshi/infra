# AGENTS — Repository Enforcement Contract

This file is the **authoritative policy** for all automation touching this repo
(CI, bots, and AI coding agents). Violations are defects.

## 1) Scope

Repository type: **GitOps-managed infrastructure**.

Core principles:

- Declarative and reproducible infra
- No secrets in Git
- Git is source of truth
- Enforcement over convention

Agents must not improvise architecture.

## 2) Hard Rules

### 2.1 No imperative cluster writes

Agents MUST NOT mutate cluster state outside bootstrap recovery.

Forbidden (examples):

- `kubectl apply/create/replace/patch/edit/delete/drain/cordon/uncordon`
- mutating `kubectl annotate/label`
- `helm install/upgrade/uninstall/rollback`
- `argocd app delete/create/set/patch`
- any other Kubernetes API write via plugins/tools

Allowed read-only operations include:

- `kubectl get/describe/logs/events/top/diff/api-resources/version/config view`
- `helm lint/template/dependency update/show ...` (no install/upgrade)
- client-side manifest generation only (e.g. `kubectl create --dry-run=client -o yaml`)

GitOps flow is mandatory: **Git → ArgoCD → Cluster**.

Allowed ArgoCD reconciliation commands:

- `argocd app sync|wait|get|diff <app>`
- `argocd proj get <proj>`

Do not use `--prune` or `--force` with `argocd app sync` unless a human explicitly requests it.

### 2.2 No secrets in Git

Agents MUST NOT:

- add plaintext secrets
- commit `.env`, `op.env`, `terraform.tfstate`, `*.tfvars`
- generate unsealed Kubernetes `Secret` manifests

Use:

- **Bitnami SealedSecrets** (Kubernetes)
- **Ansible Vault** (hosts/infra)

### 2.3 No repo structure drift

Agents MUST NOT:

- add top-level directories
- move apps between `apps/cluster` and `apps/user`
- restructure wrapper charts
- add `README.md` in wrapper chart directories

Authoritative layout: `docs/layout.md`.
Wrapper chart contents only: `Chart.yaml`, `values.yaml`, `templates/`, `charts/`.
Comprehensive docs belong in `docs/`.

## 3) Decision Authority

When conflicts arise:

1. `docs/` overrides comments/READMEs
2. Git manifests override runtime state
3. Reconcile reality **to Git**, never the reverse

No out-of-band quick fixes.

## 4) GitOps / Kubernetes Policy

- All workloads deploy via ArgoCD Applications
- Wrapper charts are the contract boundary
- Upstream charts may change; wrapper contracts must not
- Bump chart version when behavior changes
- `cluster/bootstrap/` is minimal, recovery-only, and not for feature work

### 4.1 Service addressing and base image policy

- Prefer Service DNS for in-cluster connectivity
- Do not introduce new hard-coded Service ClusterIPs
- Exception: only when DNS behavior is demonstrably incompatible; prefer glibc image first; document exception rationale in `docs/diaries/` or an ADR
- Default networked workloads to glibc-based images; use Alpine/musl only when validated or for static-binary workloads

## 5) Terraform Rules

- Active env: `terraform/envs/lab`
- No backend redesign without explicit redesign work
- No secrets in modules
- State must match reality before merge
- Agents may propose diffs, not apply plans

## 6) Ansible Rules

- Idempotency is required
- `ansible-lint` must pass
- Prefer `--check --diff`
- Secrets via Vault only

## 7) CI Behavior

- CI enforces policy; it is not convenience glue
- Shared logic lives in `tools/ci/*`
- Workflows orchestrate; they do not duplicate enforcement logic
- Fork PR paths must not require secrets

## 8) AI Agent Constraints

Agents MUST:

- propose changes as diffs
- respect architecture and guard scripts
- verify assumptions before implementation
- avoid speculative refactors
- stop and escalate if the required path conflicts with policy/platform

Agents MUST NOT:

- bypass §2.3 constraints
- silence failing checks
- generate secrets/credentials/sample keys outside approved mechanisms

### 8.1 Persistent knowledge (Basic Memory MCP)

Use Basic Memory MCP as durable cross-session memory.

- Endpoint: `https://basic-memory.m0sh1.cc/mcp`
- Record major implementations, architecture decisions, troubleshooting learnings, and repeatable workflows
- Include decisions, rationale, pitfalls, and links to relevant manifests/code
- Organize notes under:
  - `kubernetes/<topic>.md`
  - `sessions/YYYY-MM-DD-<task>.md`
  - `decisions/ADR-NNN-<name>.md`

## 9) Violations

If an agent cannot comply, it must:

- fail loudly
- avoid workarounds
- request human intervention

Silent policy bypass is forbidden.
