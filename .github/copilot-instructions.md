# GitHub Copilot Instructions

This is a **GitOps-managed Kubernetes infrastructure repository**. Git is the single source of truth; all changes flow through **Git → ArgoCD → Cluster**.

## Critical Rules (Read [AGENTS.md](../AGENTS.md) for complete enforcement contract)

### Absolute Prohibitions

**Never run imperative cluster operations:**

- ❌ `kubectl apply/delete`
- ❌ `helm install/upgrade`
- ❌ `terraform apply` (propose diffs only)

**Never commit secrets:**

- ❌ `.env`, `op.env`, `*.tfvars`, `terraform.tfstate`
- ❌ Unsealed Kubernetes `Secret` manifests
- ✅ Use **Bitnami SealedSecrets** for K8s, **Ansible Vault** for hosts

**Never modify repo structure:**

- ❌ New top-level directories (layout defined in [docs/layout.md](../docs/layout.md))
- ❌ Moving apps between `apps/cluster/` ↔ `apps/user/`
- ❌ Restructuring wrapper charts (they're contract boundaries)

## Architecture Patterns

### Helm Wrapper Charts

All Kubernetes workloads use the **wrapper chart pattern**:

```
apps/{cluster,user}/<app-name>/
├── Chart.yaml          # version, upstream dependency pinned
├── values.yaml         # overrides for upstream chart
└── templates/          # additional resources (ingress, SealedSecrets, etc.)
```

**When modifying a chart, ALWAYS bump the version in Chart.yaml** - ArgoCD detects changes via chart version.

**Documentation**: Never create README.md files in wrapper chart directories. Comprehensive documentation belongs in `docs/` where it's centralized and discoverable.

Example: [apps/cluster/traefik/Chart.yaml](../apps/cluster/traefik/Chart.yaml)

### ArgoCD Applications

Each wrapper chart has a corresponding Application manifest:

```yaml
# argocd/apps/{cluster,user}/<app-name>.yaml
metadata:
  labels:
    app.kubernetes.io/part-of: apps-root # REQUIRED for app-of-apps pattern
spec:
  source:
    path: apps/cluster/<app-name> # Points to wrapper chart
```

Example: [argocd/apps/cluster/traefik.yaml](../argocd/apps/cluster/traefik.yaml)

### App-of-Apps Pattern

Root application: [argocd/apps/root.yaml](../argocd/apps/root.yaml) → deploys all `argocd/apps/**/*.yaml`

Disabled apps go to `argocd/disabled/` (excluded from sync).

## Developer Workflows

### Validation Commands (via mise)

```bash
# Run before committing
mise run path-drift          # Enforce repo structure allowlist
mise run sensitive-files     # Block secret leaks
mise run k8s-lint           # Helm lint + kubeconform + kube-linter
mise run terraform-validate # fmt+validate (no backend)
mise run pre-commit-run     # All pre-commit hooks

# Helm operations
mise run helm-deps-update   # Update Chart.lock for all wrapper charts
mise run helm-lint          # Lint all charts
helm lint apps/cluster/traefik/  # Lint single chart
```

**CI enforces these checks** - see [.github/workflows/](../.github/workflows/)

### DevOps Guard Scripts

Located in `tools/m0sh1-devops/scripts/`:

- **gitops_guard.py**: Validates ArgoCD Application manifests, ensures `app.kubernetes.io/part-of` labels
- **helm_scaffold.py**: Scaffolds new wrapper charts + ArgoCD Applications
- **supply_chain_guard.py**: Tracks image digest usage
- **terraform_lab_guard.py**: Validates Terraform lab env constraints

Use these before proposing architectural changes.

### Changelog Management

**Only update [CHANGELOG.md](../CHANGELOG.md) for milestones, not individual commits:**

- ✅ Phase completions (Phase 0: v0.1.0)
- ✅ Breaking changes (Terraform migrations, API upgrades)
- ❌ Individual chart version bumps (use `git log`)

See [docs/changelog-strategy.md](../docs/changelog-strategy.md) for details.

## Common Patterns

### Adding a New Wrapper Chart

```bash
# Scaffold via helper script
python tools/m0sh1-devops/scripts/helm_scaffold.py \
  --repo . \
  --scope user \
  --name my-app \
  --argocd

# Result:
# - apps/user/my-app/Chart.yaml + values.yaml + templates/
# - argocd/apps/user/my-app.yaml
```

### Terraform Workflow (lab env only)

Active environment: `terraform/envs/lab/`

```bash
# Validation only (CI enforces)
mise run terraform-validate

# Secrets come from op.env (never committed)
# State is remote (never in Git)
```

### Ansible Usage

```bash
# Dry-run first
ansible-playbook -i ansible/inventory <playbook> --check --diff

# Secrets from Ansible Vault
ansible-playbook <playbook> --ask-vault-pass
```

### Bootstrap Recovery Workflow

**Bootstrap is for disaster recovery only** - normal operations use ArgoCD.

When to use bootstrap (rare):

- Fresh cluster installation
- Complete cluster rebuild after catastrophic failure
- Restoring ArgoCD itself after loss

Bootstrap process:

1. Apply minimal bootstrap manifests: `kubectl apply -k cluster/bootstrap/argocd/`
2. Wait for ArgoCD to be ready: `kubectl wait -n argocd --for=condition=available deploy/argocd-server --timeout=300s`
3. Deploy root application: `kubectl apply -f argocd/apps/root.yaml`
4. Let ArgoCD take over - **never add more to bootstrap/**

After bootstrap, all changes go through Git → ArgoCD sync.

### Creating SealedSecrets

Generate, encode, and seal secrets for Git storage:

```bash
# 1. Generate strong random secret (e.g., password)
SECRET_VALUE=$(openssl rand -base64 32)

# 2. Create Kubernetes Secret manifest (not committed!)
kubectl create secret generic my-app-secret \
  --from-literal=password="$SECRET_VALUE" \
  --dry-run=client -o yaml > /tmp/secret.yaml

# 3. Seal the secret (requires cluster access and sealed-secrets controller)
kubeseal --format yaml < /tmp/secret.yaml > apps/user/my-app/templates/sealed-secret.yaml

# 4. Clean up plaintext
rm /tmp/secret.yaml
unset SECRET_VALUE

# 5. Commit only the SealedSecret (apps/user/my-app/templates/sealed-secret.yaml)
```

**Never commit the unsealed Secret** - only SealedSecrets go into Git.

### Phase Progression

Infrastructure phases (tracked in [docs/checklist.md](../docs/checklist.md)):

**Phase 0 → Phase 1: Foundation to Bootstrap**

- Prerequisites: All guardrails passing (`mise run path-drift`, `mise run k8s-lint`)
- Tag Phase 0 completion: `git tag v0.1.0`
- Install ArgoCD via bootstrap
- Verify root application deploys successfully
- Document any manual steps in `docs/history.md`

**Phase 1 → Phase 2: Bootstrap to GitOps Core**

- Prerequisites: ArgoCD healthy, root app syncing
- Enable cluster apps sync (apps/cluster/\*)
- Enable user apps sync (apps/user/\*)
- Verify automated pruning and self-healing work
- Disable/archive any obsolete apps to `argocd/disabled/`

**Phase 2 → Phase 3: GitOps Core to Observability Reset**

- Prerequisites: All critical workloads healthy
- Remove deprecated monitoring stack (if exists)
- Clean up leftover CRDs
- Establish new baseline (Prometheus only)

Only progress to next phase when current phase checklist is ✅ complete.

## Tool-Specific Best Practices

### Renovate PRs

- Always review Chart.yaml version changes
- Verify wrapper chart version is bumped alongside dependency updates
- Test rendered manifests: `helm template apps/cluster/<app>/ | kubeconform -`
- Check for upstream breaking changes in release notes before merging

### GitHub Actions

- Use `mise-action` for consistent tool versions (matches mise.toml)
- Never expose secrets in workflow logs
- Fork PRs cannot access repository secrets (this is by design)
- Shared CI logic lives in `tools/ci/` scripts, not workflow YAML

### Pre-commit Hooks

- Installed via `prek` (not legacy pre-commit framework)
- Run `mise run hooks-install` after cloning
- Hooks enforce: path structure, sensitive files, shellcheck, yamllint
- If hooks fail, fix the issue - don't bypass with `--no-verify`

## Documentation Hierarchy

1. [docs/](../docs/) is **authoritative** (overrides code comments)
2. Git manifests override runtime state
3. Reality reconciles **to Git**, never vice versa

Key docs:

- [AGENTS.md](../AGENTS.md): Hard rules for all automation
- [docs/layout.md](../docs/layout.md): Repo structure spec
- [docs/warp.md](../docs/warp.md): Operational guide
- [docs/checklist.md](../docs/checklist.md): Phase 0-4 milestones

## Tool Versions

Managed by [mise.toml](../mise.toml):

- Helm 4.0.5, kubectl 1.35.0, Terraform 1.14.3, Ansible 2.20.1

Run `mise install` to sync local environment.
