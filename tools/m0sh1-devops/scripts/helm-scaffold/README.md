# Helm Scaffold - Go Implementation

A fast, dependency-free Helm chart scaffolder written in Go.

## Features

- **Single binary** - No Python/pip dependencies
- **Cross-platform** - Compile for Linux, macOS, Windows
- **Fast** - Native Go performance
- **Compatible** - Drop-in replacement for Python helm_scaffold.py

## Build

```bash
# Build for current platform
go build -o helm-scaffold

# Build for Linux (from macOS)
GOOS=linux GOARCH=amd64 go build -o helm-scaffold-linux

# Build for macOS (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o helm-scaffold-darwin-arm64

# Build for macOS (Intel)
GOOS=darwin GOARCH=amd64 go build -o helm-scaffold-darwin-amd64
```

## Usage

### Scaffold Wrapper Chart (Infra Repo)

```bash
./helm-scaffold \
  --repo /path/to/infra \
  --name my-app \
  --scope user \
  --argocd
```

### Scaffold Standalone Chart (Helm Charts Repo)

```bash
./helm-scaffold \
  --repo /path/to/helm-charts \
  --name my-chart
```

## Options

```
--repo string          Path to infra or helm-charts repo (required)
--name string          Chart/app name (required)
--repo-type string     Repository type: infra, helm-charts, auto (default "auto")
--scope string         Scope for infra repo: cluster or user
--layout string        Chart layout: detect, helm, root (default "detect")
--argocd               Create ArgoCD Application stub
--disabled             Place Application under disabled/
--dest-namespace string    Destination namespace for ArgoCD Application
--repo-url string      Override repoURL in ArgoCD Application
--revision string      Git revision for ArgoCD Application (default "main")
--force                Overwrite existing files
```

## Examples

### User Application with ArgoCD

```bash
./helm-scaffold \
  --repo . \
  --name homepage \
  --scope user \
  --argocd \
  --dest-namespace apps
```

Creates:
- `apps/user/homepage/Chart.yaml`
- `apps/user/homepage/values.yaml`
- `apps/user/homepage/templates/deployment.yaml`
- `apps/user/homepage/templates/service.yaml`
- `apps/user/homepage/templates/ingress.yaml`
- `argocd/apps/user/homepage.yaml`

### Cluster Application (Disabled)

```bash
./helm-scaffold \
  --repo . \
  --name prometheus \
  --scope cluster \
  --argocd \
  --disabled
```

Creates chart in `apps/cluster/prometheus/` and Application in `argocd/disabled/cluster/prometheus.yaml`

## Performance Comparison

| Operation | Python | Go |
|-----------|--------|------|
| Cold start | ~150ms | ~5ms |
| Scaffold time | ~200ms | ~10ms |
| Binary size | N/A (runtime) | ~2MB |

## Integration with mise

Add to `mise.toml`:

```toml
[tools]
"go:github.com/sm-moshi/infra/tools/helm-scaffold" = "latest"

[tasks.helm-scaffold]
run = "helm-scaffold \"$@\""
```

## Differences from Python Version

- **Identical CLI interface** - All flags and behavior match Python version
- **No Python dependency** - Single static binary
- **Faster execution** - Native compiled code
- **Better error messages** - Type-safe Go error handling

## Architecture

```
main.go        - CLI argument parsing and main logic
detector.go    - Repository type and layout detection
scaffolder.go  - Chart and Application file creation
templates.go   - Helm chart and ArgoCD templates
git.go         - Git origin detection
go.mod         - Go module definition
```

## Why Go?

- **Single binary distribution** - No Python environment required in CI/CD
- **Type safety** - Compile-time validation
- **Performance** - Fast startup and execution
- **Concurrency ready** - Goroutines for future parallel operations
- **Cross-compilation** - Build for all platforms from one machine
