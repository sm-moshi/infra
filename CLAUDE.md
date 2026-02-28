---

## Repository Type

**GitOps infrastructure repository** for m0sh1.cc homelab (ArgoCD + Helm wrappers + Terraform + Ansible).

**Authority Hierarchy:**
1. **[AGENTS.md](AGENTS.md)** - Mandatory enforcement contract for all automation
2. **[docs/warp.md](docs/warp.md)** - Operational guide and tool reference
3. **[docs/layout.md](docs/layout.md)** - Canonical repository structure
4. **Basic Memory MCP** (`project: main`) - Project context, decisions, and session history
5. **[tools/m0sh1-devops/](tools/m0sh1-devops/)** - DevOps tooling and references
6. **`~/.claude/`** - Hooks, skills (helm-upgrade, create-sealed-secret), agents (chart-compliance-reviewer)

---

## Non-Negotiables (from AGENTS.md)

- ❌ No imperative cluster operations (`kubectl apply/delete`, `helm install/upgrade`) outside bootstrap recovery
- ❌ No secrets in Git (use SealedSecrets for K8s, Ansible Vault for hosts)
- ❌ No repo structure drift or README files in wrapper chart directories
- ❌ No `terraform apply` (propose diffs only)
- ✅ All workload changes flow: **Git → ArgoCD → Cluster**

See [AGENTS.md](AGENTS.md) for complete rules.

---

## Essential Commands

```bash
# Validation (run before committing)
mise run helm-lint           # Helm lint
mise run path-drift         # Enforce repo structure

# Pre-commit hooks
mise run pre-commit-run     # All configured hooks

# Helm operations
mise run helm-deps-update   # Update all Chart.lock files

# Terraform (validate only, never apply)
mise run terraform-validate # fmt + validate (lab env, no backend)

# Ansible
mise run ansible-idempotency # Check playbook idempotency
```

See [mise.toml](mise.toml) for all available tasks.

---

## Architecture Patterns

### Wrapper Chart Contract Boundary

All workloads use wrapper charts in `apps/cluster/` (platform) or `apps/user/` (workloads):

```text
apps/{cluster,user}/<app-name>/
├── Chart.yaml          # Version + upstream dependency
├── values.yaml         # Environment overrides
└── templates/          # Additional resources (SealedSecrets, Certificates)
```

- Wrapper charts are the **contract boundary** around upstream Helm charts
- Values live in wrapper `values.yaml`, not ArgoCD Applications
- Chart version bumps mandatory when behavior changes

See [tools/m0sh1-devops/references/helm-wrappers.md](tools/m0sh1-devops/references/helm-wrappers.md)

### SealedSecrets Centralization

Credentials centralized in two Kustomize apps:

- **apps/cluster/secrets-cluster/** - Cluster credentials (API keys, tokens) - 11 SealedSecrets
- **apps/user/secrets-apps/** - User app credentials (passwords, OAuth) - 20 SealedSecrets

Controller: `sealed-secrets-controller` in `sealed-secrets` namespace

```bash
# Create sealed secret (example)
kubectl create secret generic <name> --dry-run=client -o yaml \
  --from-literal=key=value | \
  kubeseal --format=yaml > apps/user/secrets-apps/<name>.sealedsecret.yaml
```

### ArgoCD App-of-Apps

Root: `argocd/apps/apps-root.yaml` discovers:

- `argocd/apps/cluster/*.yaml` - Platform services
- `argocd/apps/user/*.yaml` - User workloads
- `argocd/disabled/**` - Disabled apps (excluded from sync)

Sync policy: Automated with `prune: true` and `selfHeal: true`

---

## Operating Protocol

1. **Read context first:** Use Basic Memory MCP (`project: main`) — search for active work, decisions, and patterns via `mcp__basic-memory__search_notes` or `mcp__basic-memory__recent_activity`
2. **Use ContextStream:** Search via ContextStream before local file scans
3. **Prefer mise tasks:** Use `mise run <task>` for validation and consistent tooling
4. **Propose diffs:** Never bypass guard scripts or apply changes directly to cluster
5. **Stop if blocked:** If requirements conflict with AGENTS.md or docs/layout.md, ask for clarification

---

## Gotchas

- **Bootstrap is recovery-only:** `cluster/bootstrap/` is minimal DR bootstrap. Never extend it for feature work - use ArgoCD Applications.
- **No wrapper chart READMEs:** Never create README.md in `apps/cluster/` or `apps/user/` wrapper chart directories. Documentation goes in `docs/`. (AGENTS.md §2.3)
- **Harbor authentication:** Use `harbor-build` account for image pushes to `harbor.m0sh1.cc/apps/`, not `monitoring_admin`.
- **4-VLAN network:** OPNsense routes VLANs 10 (infra), 20 (k8s), 30 (LoadBalancers). See [docs/diaries/network-vlan-architecture.md](docs/diaries/network-vlan-architecture.md)

---

## Persistent Knowledge with Basic Memory MCP

Use Basic Memory MCP for persistent knowledge across sessions.

**Endpoint:** `https://basic-memory.m0sh1.cc/mcp` (already configured)

**Update after:**

- Major implementations or deployments
- Architectural decisions or changes
- Troubleshooting sessions with valuable learnings
- Discovery of non-obvious patterns or solutions
- Multi-step workflows that should be repeatable

**Organization:**

- `kubernetes/<topic>.md` - Topic-based notes
- `sessions/YYYY-MM-DD-<task>.md` - Session logs
- `decisions/ADR-NNN-<name>.md` - Architecture decision records

**Sync:** Mac Obsidian ↔ GitHub (sm-moshi/knowledge-base) ↔ K8s ↔ Basic Memory MCP (30s bidirectional)

See [AGENTS.md §8.1](AGENTS.md) for mandatory documentation requirements.
