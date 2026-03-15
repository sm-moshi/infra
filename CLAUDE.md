# CLAUDE — Runtime Instructions

This repository is GitOps infrastructure.

**Authoritative policy lives in [AGENTS.md](AGENTS.md).**
If this file conflicts with `AGENTS.md`, follow `AGENTS.md`.

## Critical rules Claude must enforce

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

## Essential commands

```bash
mise run policy              # Core repo policy guardrails (guard-build + infra-guard checks)
mise run k8s-lint            # Helm lint + kubeconform + kube-linter (all charts)
mise run k8s-lint-changed    # Same but only charts changed vs base branch
mise run helm-deps-update    # Update Chart.lock for all wrapper charts
mise run path-drift          # Enforce repo structure (top-level allowlist)
mise run sensitive-files     # Block secret filename leaks
mise run pre-commit-run      # All pre-commit hooks
mise run terraform-validate  # fmt + validate (lab env, no backend)
```

## Architecture (compact)

Wrapper charts in `apps/cluster/` (platform) and `apps/user/` (workloads):
```
apps/{cluster,user}/<app>/Chart.yaml + values.yaml + templates/
```
Wrapper charts are the contract boundary. Values live in the wrapper, not ArgoCD apps.
Bump wrapper chart version when behaviour changes.

**Submodules:** `tools/cli` → [infra-cli](https://github.com/sm-moshi/infra-cli) (Go CLI tools + Woodpecker pipelines). Has its own commit history; changes there need a submodule pointer update in this repo.

SealedSecrets are centralised in two Kustomise apps:
- `apps/cluster/secrets-cluster/` — cluster credentials (API keys, tokens)
- `apps/user/secrets-apps/` — user app credentials (passwords, OAuth)

```bash
# Create a sealed secret
kubectl create secret generic <name> -n <ns> --dry-run=client -o yaml \
  --from-literal=key=value | kubeseal --format=yaml \
  > apps/user/secrets-apps/<name>.sealedsecret.yaml
```

ArgoCD app-of-apps: root at `argocd/apps/apps-root.yaml` discovers `argocd/apps/cluster/*.yaml` + `argocd/apps/user/*.yaml`. Disabled apps live in `argocd/disabled/`.

## Gotchas

- **Woodpecker UI is a SPA.** `WebFetch` on pipeline URLs returns shell HTML, no log data. Use `woodpecker-cli` or the REST API instead.
- **Submodule push order.** Bottom-up: leaf repos (act, netzbremse) → infra-cli → infra. Each level must commit the submodule pointer update before the parent can reference it.
- **Woodpecker CLI.** Token is in fish universal var `WOODPECKER_TOKEN`. Server: `https://ci.m0sh1.cc`. Never inline tokens in commands.
- **staticcheck (not golangci-lint).** All Go repos use `go vet` + `staticcheck`. Directive syntax: `//lint:ignore SA1019 reason`. Exclude generated code via `go list | grep -v`.
- **Bootstrap is recovery-only.** `cluster/bootstrap/` is minimal DR bootstrap. Never extend it for feature work — use ArgoCD Applications.
- **No wrapper chart READMEs.** Never create `README.md` in `apps/cluster/` or `apps/user/` chart dirs. Documentation belongs in `docs/`.
- **DHI images.** Docker Hardened Images at `harbor.m0sh1.cc/dhi/`. Do not use DHI images during bootstrap — Harbor depends on the cluster being up.
- **Harbor push account.** Use `robot$harbor-build` for CI pushes to `harbor.m0sh1.cc/apps/`. The legacy `harbor-build-user` secret is not the working CI path.
- **Helm 4 shim.** `~/.local/bin/helm` strips `--client` flag for Helm 4 compatibility.
- **CNI is Cilium.** Policy enforcement ON (`policyEnforcementMode: "default"`). CNPs deployed across all namespaces via `apps/{cluster,user}/cilium-policies/`. ArgoCD has `cilium.io` wildcard in `resource.exclusions`.
- **4-VLAN network.** OPNsense routes VLAN 10 (infra), 20 (k8s nodes), 30 (LoadBalancers). See `docs/diaries/network-vlan-architecture.md`.

## Woodpecker MCP

- Endpoint: `https://woodpecker-mcp.m0sh1.cc/mcp` (streamable HTTP, auth via `WOODPECKER_MCP_AUTH_TOKEN`)
- `/healthz` is in-cluster only; ingress serves `/mcp` exclusively.

## Style

- Use British English in all prose (e.g. colour, organisation, behaviour, licence, normalise).

## Basic Memory

Folder convention is documented in MEMORY.md (auto-loaded). Use `mcp__basic-memory__search_notes` for context before starting work. Do not create notes in `sessions/` if the content belongs in a topic-specific directory.

## Operating protocol (compact)

1. Read context first from Basic Memory MCP (`mcp__basic-memory__search_notes`).
2. Prefer `mise run <task>` and repository guardrails.
3. Validate before proposing final changes.

## Fast references

- Policy: [AGENTS.md](AGENTS.md)
- Ops guide: [docs/getting-started.md](docs/getting-started.md)
- Repo layout: [docs/layout.md](docs/layout.md)
- Helm wrappers: [tools/m0sh1-devops/references/helm-wrappers.md](tools/m0sh1-devops/references/helm-wrappers.md)
- Tasks: [mise.toml](mise.toml)
- Memory requirements: [AGENTS.md §8.1](AGENTS.md#81-persistent-knowledge-basic-memory-mcp)
