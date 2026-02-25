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

```bash
mise run policy          # Main policy checks (sensitive files + path drift)
mise run sensitive-files # Block secret leaks
mise run path-drift      # Enforce top-level directory allowlist
```

### Pre-commit / formatting / docs

```bash
mise run pre-commit-run  # All configured hooks
mise run Markdown-lint   # Markdown linting
mise run Markdown-fix    # Auto-fix markdown issues
```

### Kubernetes / Helm validation

Helm + kubeconform + kube-linter pipeline:

```bash
mise run helm-deps-update  # Update all Chart.lock files
mise run helm-lint         # Lint all wrapper charts
mise run k8s-lint          # Full validation (helm lint + template + kubeconform + kube-linter)

# Single chart validation
helm lint apps/cluster/<chart-name>/
helm template apps/cluster/<chart-name>/ | kubeconform -
```

### Terraform (lab environment only)

Validation-only workflow (agents must not apply):

```bash
mise run terraform-validate  # fmt -check + init -backend=false + validate
```

### Ansible

Check playbook idempotency:

```bash
mise run ansible-idempotency
```

Agents must not introduce non-idempotent tasks or handle Vault secrets directly.

## High-level architecture

### ArgoCD bootstrap and applications

- **Bootstrap**:
  - `cluster/bootstrap/argocd/install.yaml` is a minimal manifest (namespace + ServiceAccount) used to bring up ArgoCD in a new or recovered cluster.
  - `tools/ci/render-bootstrap-argocd.sh` renders a fully configured ArgoCD manifest into `cluster/bootstrap/argocd/rendered.yaml` using the `apps/cluster/argocd` wrapper chart as the single source of settings.
  - Bootstrap is **recovery-only** and must not be extended for ongoing feature work.

- **Root application** (`argocd/apps/apps-root.yaml`):
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

Policy enforcement scripts wired into pre-commit:

- **`path-drift-check.sh`**: Enforces top-level directory allowlist (see `docs/path-drift-guardrail.md`). New top-level entries require updates to both this script AND `docs/layout.md`.
- **`sensitive-files-guard`**: Blocks secret leaks by scanning for sensitive filenames.
- **`k8s-lint.sh`**: Validates all Helm charts (lint + template + kubeconform + optional kube-linter) and raw manifests.
- **`check-idempotency`**: Validates Ansible playbook idempotency when available.

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

### NetBox IPAM/DCIM Integration

NetBox (`apps/user/netbox/`) is the **source of truth for IP planning** (intent). The integration stack:

- **NetBox** (v4.5.3) — IPAM authority. Custom Harbor image with plugins (`netbox_diode_plugin`, `netbox_bgp`, `netbox_security`, etc.).
- **Diode** (`apps/user/diode/`) — gRPC ingestion pipeline: ingester + reconciler + Hydra (OIDC). Receives discovery data and reconciles into NetBox.
- **OrbAgent** (in `apps/user/diode/`) — Network scanner. TCP connect scans 4 VLANs (10.0.{0,10,20,30}.0/24) every 30min. Tags objects `orb-discovery`.
- **NetBox Operator** (`apps/user/netbox-operator/`) — Kubernetes CRDs for IP/prefix claims (IPAddressClaim, PrefixClaim, IpRangeClaim).
- **OPNsense Sync** — NetBox custom script (`opnsense_sync.py` baked into image). Pulls aliases, rules, zones, routes, VLANs, and DHCP/DNS name data (Kea + Unbound) from OPNsense → NetBox.

**Authority model** (one owner per domain, no overlaps):

| Domain             | Authority  | NetBox Role                    |
|--------------------|------------|--------------------------------|
| Routing/DHCP/DNS   | OPNsense   | Viewer (synced from OPNsense)  |
| VM lifecycle       | Terraform  | Inventory (discovered)         |
| IP planning/intent | NetBox     | Source of truth                |
| Network discovery  | OrbAgent   | Reality observer               |

**Day-2 operations:**

- **New VM**: Terraform creates VM → `proxmox-discover.py` syncs to NetBox → allocate IP in NetBox
- **New IP**: Create in NetBox IPAM → OPNsense remains enforcement authority
- **Drift check**: `drift-report.py` compares NetBox vs Proxmox/OPNsense/OrbAgent (nightly via Woodpecker)
- **OPNsense changes**: Auto-synced to NetBox via `opnsense_sync.py` custom script

**Scripts** (in `tools/cli/docker/netbox/`):

- `onboarding.py` — Idempotent seeder (`--mode seed`) + reconcile reporter (`--mode reconcile`)
- `opnsense-sync.py` — OPNsense → NetBox custom script (runs inside NetBox pod)
- `proxmox-discover.py` — Proxmox VM/CT discovery (standalone CLI)
- `drift-report.py` — Cross-system drift detection (standalone CLI, JSON output)

## Agent-specific guidance

- Always operate via Git diffs (conceptually) and respect the existing layout and conventions.
- Prefer editing existing manifests, charts, and tasks over introducing new frameworks or restructuring directories.
- When adding new workloads or infrastructure definitions, model them closely on existing examples in the same area (cluster vs user, Terraform envs, Ansible roles).
- When in doubt about where something belongs, stop and request human guidance rather than guessing and changing architecture.

## Preferred Rule Files

- Authoritative rule sources: `AGENTS.md`, `docs/warp.md`, Skills/Agents under `tools/`, and `~/.claude/` (hooks, skills, agents).
- Do not rely on `.cursorrules`, `.clinerules`, `.aiderconf.yaml`, or `GEMINI.md` (may be deleted locally).
- `.github/*.chatmode.md` files may be auto-generated by extensions and are not authoritative.
