# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository role and critical policies

- This is a **GitOps-managed infrastructure repository** for Kubernetes, centered on ArgoCD, Helm wrapper charts, Terraform, and Ansible.
- Git is the single source of truth. All workload changes must flow **Git → ArgoCD → Cluster**.
- **Agents must not run imperative cluster operations**:
  - Never run `kubectl apply` / `kubectl delete`.
  - Never run `helm install` / `helm upgrade` against a live cluster.
- **No secrets in Git**:
  - Kubernetes: use Bitnami **SealedSecrets** only.
  - Ansible: use **Ansible Vault**.
  - Terraform: keep secrets in backends / external systems, not modules or `.tfvars` committed to Git.
- **Repo layout is guarded**:
  - Do not introduce new top-level directories.
  - Do not move apps between `apps/cluster` and `apps/user`.
  - Do not restructure wrapper charts; they are the contract boundary around upstream charts.

These rules are enforced by CI and pre-commit hooks; treat violations as hard errors, not something to work around.

## Tooling and environment

- Toolchain is managed by **mise** (`mise.toml`). It pins versions for `terraform`, `helm`, `kubectl`, `kustomize`, `kubeconform`, `kube-linter`, `ansible`, `python`, `rg`, `fd`, etc.
- Prefer running tasks via `mise` so the correct tool versions are auto-installed.

Common setup after cloning:

- Install tools and hooks (once):
  - `mise install`
  - `mise run hooks-install` # installs repo hooks via `prek`

## Common commands (build / lint / tests)

### Run full policy / safety checks

- Run the main policy checks used in CI (sensitive files + path layout):
  - `mise run policy`
- Individually:
  - `mise run sensitive-files` # forbid committing obvious secrets and sensitive filenames
  - `mise run path-drift` # enforce allowed top-level paths and forbid deprecated directory patterns

### Pre-commit / formatting / docs

- Run all configured pre-commit hooks over the repo:
  - `mise run pre-commit-run`
- Markdown linting / formatting (on docs, README, AGENTS, SECURITY):
  - `mise run markdown-lint`
  - `mise run markdown-fix`

### Kubernetes / Helm validation

Primary "test" suite for Kubernetes manifests is Helm + kubeconform (+ kube-linter):

- Update Helm chart dependencies for all wrapper charts:
  - `mise run helm-deps-update`
- Lint all Helm wrapper charts:
  - `mise run helm-lint`
- Full Kubernetes lint/validation pipeline (Helm lint + template + kubeconform, plus optional kube-linter on rendered manifests, and kubeconform for raw manifests):
  - `mise run k8s-lint`

Running checks for a **single chart**:

- Lint only one cluster chart, e.g. `traefik`:
  - `helm lint apps/cluster/traefik/`
- Lint only one user chart, e.g. `homepage`:
  - `helm lint apps/user/homepage/`

(Use `mise` to ensure the `helm` version matches `mise.toml`.)

### Terraform (lab environment only)

Terraform usage is constrained to the `lab` environment and should be validation-only for agents:

- Format and validate Terraform for the lab env **without touching the backend**:
  - `mise run terraform-validate`
    - Runs `terraform fmt -check -recursive` for the whole repo.
    - Runs `terraform init -backend=false` and `terraform validate` in `terraform/envs/lab`.
- **Agents must not run** `terraform apply` or any command that mutates real infrastructure.

### Ansible

Ansible is used for configuration management outside the cluster. The key agent-side check is idempotency:

- Check Ansible playbooks for idempotency issues:
  - `mise run ansible-idempotency`
  - Internally calls `tools/ci/ansible-idempotency.sh`, which in turn uses `tools/m0sh1-devops/scripts/check_idempotency.py` if present.

Agents must not introduce non-idempotent Ansible tasks and must not handle Vault secrets directly.

## High-level architecture

### ArgoCD bootstrap and applications

- **Bootstrap**:
  - `cluster/bootstrap/argocd/install.yaml` is a minimal manifest (namespace + ServiceAccount) used to bring up ArgoCD in a new or recovered cluster.
  - `tools/ci/render-bootstrap-argocd.sh` renders a fully configured ArgoCD manifest into `cluster/bootstrap/argocd/rendered.yaml` using the `apps/cluster/argocd` wrapper chart as the single source of settings.
  - Bootstrap is **recovery-only** and must not be extended for ongoing feature work.

- **Root application** (`argocd/apps/root.yaml`):
  - Defines the `apps-root` ArgoCD `Application` that points at two paths in this repo:
    - `apps/cluster` — cluster-scoped / platform components.
    - `apps/user` — user/workload-level applications.
  - Sync policy is automated with `prune: true` and `selfHeal: true`, with `CreateNamespace=true` via sync options.

- **Environment applications** (example: `argocd/apps/cluster/lab-env.yaml`):
  - Define per-environment ArgoCD `Application`s; `lab-env` points at `cluster/environments/lab`.
  - These applications drive environment-specific overlays (see below) and are also fully automated with `prune` and `selfHeal`.

### Wrapper charts and workloads

- **Wrapper charts live under**:
  - `apps/cluster/<name>/` for platform components (e.g. `traefik`, `sealed-secrets`, `metallb`, `prometheus`).
  - `apps/user/<name>/` for user/workload apps (e.g. `homepage`, `harbor`, `uptime-kuma`).
- Each wrapper chart typically contains at minimum:
  - `Chart.yaml` — declares the chart and its dependency on an upstream chart.
  - `values.yaml` — opinionated configuration for this environment.
  - `templates/` — optional directory for additional resources (SealedSecrets, ConfigMaps, etc.).
- **Documentation**: Never create README.md files in wrapper chart directories. Comprehensive documentation belongs in `docs/` where it's centralized and discoverable. Wrapper charts should only contain deployment manifests.
- Some charts may include additional files (e.g. `netdata-debug.yaml` in `apps/cluster/netdata/`).

Key constraints for agents:

- Treat wrapper charts as the **API boundary**:
  - You may adjust `values.yaml` or add local templates when required.
  - Do not modify upstream charts directly.
- When behavior changes for a chart, bump the wrapper chart version in `Chart.yaml` according to existing conventions.
- Respect the split between `apps/cluster` and `apps/user`; moving a workload between them is an architectural decision and out of scope for automation.

### Cluster environments (Kustomize)

- Environment overlays for the Kubernetes cluster live under `cluster/environments/`.
  - Example: `cluster/environments/lab/kustomization.yaml` assembles environment-specific resources via a Kustomize `Kustomization`.
- ArgoCD environment `Application`s (e.g. `lab-env`) point at these directories.
- Changes here should be minimal and environment-scoped; global behavior should generally be controlled via Helm wrapper charts instead.

### CI and guard rails (`tools/ci/*`)

These scripts define the enforced policy surface and are wired into pre-commit:

- `tools/ci/path-drift-check.sh`:
  - Enforces an allowlist of top-level paths/files.
  - Rejects forbidden top-level directories.
  - Scans tracked files for deprecated path references.
  - Any change that adds a new top-level entry must be reflected here and in `docs/layout.md` (by a human) to be accepted.

- `tools/ci/sensitive-files-check.sh`:
  - Scans tracked (or staged) paths for filenames that strongly indicate secrets or private keys.
  - Explicitly ignores sealed secrets and some expected auto-generated or archived files.

- `tools/ci/k8s-lint.sh`:
  - Discovers all Helm charts under `apps/cluster/*/` and `apps/user/*/` (and any `apps/argocd/helm/`), then:
    - Runs `helm lint` on each chart.
    - Renders each chart with `helm template` and validates the output using `kubeconform`.
    - Optionally runs `kube-linter` on rendered manifests when `K8S_LINT_KUBE_LINTER` is not set to `0`.
  - Also runs `kubeconform` over raw Kubernetes manifests in `apps/argocd/applications` and `cluster/environments/lab`, excluding disabled and template files.

- `tools/ci/ansible-idempotency.sh`:
  - Optional check that runs an external Python-based idempotency checker over Ansible playbooks when available.
  - Skips gracefully if Ansible playbooks or the checker script are absent.

Agents should treat these scripts as **policy**, not as code to be simplified or bypassed.

### Terraform and Ansible (high level)

- **Terraform**:
  - Repository layout assumes `terraform/` with active environment under `terraform/envs/lab` only.
  - Modules must not contain secrets; backends must be explicitly designed and are not to be changed by agents.
  - Agents may assist with HCL changes and validation, but must not apply plans.

- **Ansible**:
  - `ansible/` contains playbooks, roles, and inventory.
  - Idempotency is a hard requirement; prefer using the idempotency checker task.
  - All sensitive data must come from Vault; do not introduce plain-text secrets, even in examples.

## Agent-specific guidance

- Always operate via Git diffs (conceptually) and respect the existing layout and conventions.
- Prefer editing existing manifests, charts, and tasks over introducing new frameworks or restructuring directories.
- When adding new workloads or infrastructure definitions, model them closely on existing examples in the same area (cluster vs user, Terraform envs, Ansible roles).
- When in doubt about where something belongs, stop and request human guidance rather than guessing and changing architecture.
