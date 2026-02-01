# Helm Wrapper Charts (m0sh1.cc)

## Table of Contents

1. Wrapper Chart Contract
2. Layout Options
3. Values and Templates
4. ArgoCD Source Path

## 1. Wrapper Chart Contract

- Wrapper charts are the contract boundary; upstream charts may change, wrappers must not.
- No direct Helm repo dependencies in ArgoCD Applications.
- Values live inside the wrapper folder.

## 2. Layout Options

Preferred layout (per repo guidelines):

- `apps/cluster/<name>/`
- `apps/user/<name>/`

Some existing charts may be at `apps/<scope>/<name>/` root. Use the repo's
current pattern or pass `--layout` in scaffolding.

## 3. Values and Templates

- Use `values.yaml` for image, service, ingress, resources, env.
- Avoid plaintext secrets; reference SealedSecrets via `envFrom` or mounted files.

## 4. ArgoCD Source Path

- Application `spec.source.path` should point at the wrapper chart directory.
- Use `path:` not `chart:` to avoid direct Helm repo dependency.

## 5. Automated Scaffolding (helm_scaffold.py)

The `tools/m0sh1-devops/scripts/helm_scaffold.py` script generates wrapper charts and ArgoCD Applications:

### Modular Architecture (2026-02-01 Refactoring)

**Package Structure:**

```text
helm_scaffold/
├── __init__.py       # Package metadata
├── cli.py            # Argument parsing
├── detector.py       # Repo type/layout detection
├── scaffolder.py     # Core scaffolding logic
└── templates.py      # All template strings (Chart.yaml, values.yaml, etc.)
```

**Benefits:**

- Templates externalized for easy maintenance
- Each module independently testable
- Clear separation of concerns
- Reusable functions for other tools
- Backward compatible wrapper script

### Usage Examples

**Scaffold wrapper chart in infra repo:**

```bash
python tools/m0sh1-devops/scripts/helm_scaffold.py \
  --repo /path/to/infra \
  --scope user \
  --name my-app \
  --argocd
```

Generates:

- `apps/user/my-app/Chart.yaml`
- `apps/user/my-app/values.yaml`
- `apps/user/my-app/templates/{deployment,service,ingress}.yaml`
- `argocd/apps/user/my-app.yaml` (Application manifest)

**Scaffold standalone chart in helm-charts repo:**

```bash
python tools/m0sh1-devops/scripts/helm_scaffold.py \
  --repo /path/to/helm-charts \
  --name my-chart
```

Generates:

- `charts/my-chart/Chart.yaml`
- `charts/my-chart/values.yaml`
- `charts/my-chart/templates/{deployment,service}.yaml`

### Auto-Detection Features

- **Repo type**: Detects `infra` vs `helm-charts` based on directory structure
- **Layout**: Detects "root" (`apps/*/name/`) vs "helm" (`apps/*/name/helm/`) layout
- **Git origin**: Auto-populates ArgoCD Application `repoURL` from git remote

### Options

- `--layout {detect,helm,root}`: Override layout detection
- `--disabled`: Place ArgoCD Application under `argocd/disabled/`
- `--dest-namespace`: Override destination namespace (defaults: cluster apps → `<name>`, user apps → `apps`)
- `--repo-url`: Override git repository URL
- `--revision`: Set git branch/tag (default: `main`)
- `--force`: Overwrite existing files
