# Getting Started

This guide covers the operational procedures for managing the infrastructure repository.

## 1. Bootstrap ArgoCD (Disaster Recovery Only)

**Bootstrap is for fresh cluster installation or catastrophic failure recovery only.**

```bash
# Apply minimal ArgoCD installation
kubectl apply -k cluster/bootstrap/argocd/

# Wait for ArgoCD ready
kubectl wait -n argocd --for=condition=available deploy/argocd-server --timeout=300s

# Deploy root application (app-of-apps pattern)
kubectl apply -f argocd/apps/apps-root.yaml

# CRITICAL: Verify apps-root points to argocd/apps (NOT cluster/bootstrap)
kubectl get application apps-root -n argocd -o yaml | grep "path:"
# Expected: path: argocd/apps
```

**After bootstrap, ALL changes flow through Git → ArgoCD automated sync (`prune` + `selfHeal`).**

> **Bootstrap rendering:** `tools/ci/render-bootstrap-argocd.sh` renders a fully
> configured ArgoCD manifest into `cluster/bootstrap/argocd/rendered.yaml` using
> the `apps/cluster/argocd` wrapper chart as the single source of settings.

Bootstrap procedure is captured in `cluster/bootstrap/`; after bootstrap, everything flows through ArgoCD.

## 2. ArgoCD App-of-Apps Pattern

Root application (`argocd/apps/apps-root.yaml`) discovers and deploys all steady-state applications under `argocd/apps/**`:

- **Active apps**: `argocd/apps/cluster/*.yaml` (platform) + `argocd/apps/user/*.yaml` (workloads)
- **Disabled apps**: `argocd/disabled/**` (excluded from sync)
- **Recovery-only**: `argocd/disabled/bootstrap-root.yaml` stays out of steady-state discovery and is applied manually only for disaster recovery

```bash
# Add new application: create manifest in argocd/apps/
# ArgoCD auto-discovers within 3 minutes (or force refresh):
kubectl patch application apps-root -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Disable application: move to argocd/disabled/
# ArgoCD auto-prunes resources
```

## 3. Terraform Infrastructure

Provision Proxmox VMs and LXCs:

```bash
cd terraform/envs/lab/
terraform init
terraform plan
terraform apply
```

**Note**: State stored remotely (never committed). Use validation only: `mise run terraform-validate`

## 4. Ansible Configuration

Host provisioning and k3s cluster setup:

```bash
cd ansible/

# Run playbook with vault
ansible-playbook -i inventory playbooks/<playbook>.yaml --ask-vault-pass

# Dry-run first (recommended)
ansible-playbook -i inventory playbooks/<playbook>.yaml --check --diff
```

## 5. Helm Wrapper Charts

All Kubernetes workloads use wrapper chart pattern:

```text
apps/{cluster,user}/<app-name>/
├── Chart.yaml          # Version + upstream dependency pinned
├── values.yaml         # Environment-specific overrides
└── templates/          # Additional resources (SealedSecrets, ConfigMaps)
```

**Never deploy directly with helm install** - commit changes to Git, let ArgoCD sync.

## Validation Tasks (mise)

```bash
# Policy enforcement
mise run path-drift          # Enforce repo structure
mise run sensitive-files     # Block secret leaks

# Kubernetes manifests
mise run k8s-lint           # Helm lint + kubeconform + kube-linter
mise run helm-deps-update   # Update Chart.lock for all wrapper charts

# Terraform (lab env only)
mise run terraform-validate # fmt + validate (no backend)

# Ansible
mise run ansible-idempotency # Check playbook idempotency

# All pre-commit hooks
mise run pre-commit-run
```

### CI Guardrail Scripts

Policy enforcement scripts wired into pre-commit (in `tools/ci/`):

- **`path-drift-check.sh`**: Enforces top-level directory allowlist (see `docs/path-drift-guardrail.md`)
- **`sensitive-files-guard`**: Blocks secret leaks by scanning for sensitive filenames
- **`k8s-lint.sh`**: Validates all Helm charts (lint + template + kubeconform + optional kube-linter) and raw manifests
- **`check-idempotency`**: Validates Ansible playbook idempotency when available

Treat these scripts as **policy**, not code to simplify or bypass.

## GitOps Workflow

**GitOps Enforcement** (see [AGENTS.md](../AGENTS.md)):

1. **Make changes** in feature branches (never imperative kubectl/helm operations)
2. **Validate locally**: `mise run k8s-lint`, `mise run path-drift`, `mise run sensitive-files`
3. **Review changes** through pull requests
4. **Merge to main** after approval
5. **ArgoCD syncs automatically** (prune + selfHeal enabled)
6. **Monitor deployments** via ArgoCD UI or `kubectl get application -n argocd`

**Key Rules**:

- ❌ Never `kubectl apply` (except bootstrap recovery)
- ❌ Never `helm install/upgrade` (use wrapper charts + ArgoCD)
- ❌ Never commit secrets (use SealedSecrets + Ansible Vault)
- ❌ Never create new top-level directories (see [layout.md](layout.md))

## Related Documentation

- [AGENTS.md](../AGENTS.md) - Mandatory automation rules
- [layout.md](layout.md) - Repository structure specification
- [TODO.md](TODO.md) - Active infrastructure tasks
- [done.md](done.md) - Completed work
