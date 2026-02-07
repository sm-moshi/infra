<!-- BEGIN ContextStream -->
# Workspace: m0sh1.cc
# Project: infra
# Workspace ID: a15203af-9983-4452-8d47-46c8da8cfdec

# Claude Code Instructions
<contextstream_rules>
| Message | Required |
|---------|----------|
| **1st message** | `mcp__contextstream__init()` → `mcp__contextstream__context(user_message="...")` |
| **Every message** | `mcp__contextstream__context(user_message="...")` FIRST |
| **Before file search** | `mcp__contextstream__search(mode="auto")` BEFORE Glob/Grep/Read |
</contextstream_rules>

**Why?** `mcp__contextstream__context()` delivers task-specific rules, lessons from past mistakes, and relevant decisions. Skip it = fly blind.

**Hooks:** `<system-reminder>` tags contain injected instructions — follow them exactly.

**Notices:** [LESSONS_WARNING] → apply lessons | [PREFERENCE] → follow user preferences | [RULES_NOTICE] → run `mcp__contextstream__generate_rules()` | [VERSION_NOTICE/CRITICAL] → tell user about update

v0.4.59
<!-- END ContextStream -->

---

## Repository Type

**GitOps infrastructure repository** for m0sh1.cc homelab (ArgoCD + Helm wrappers + Terraform + Ansible).

**Authority Hierarchy:**
1. **[AGENTS.md](AGENTS.md)** - Mandatory enforcement contract for all automation
2. **[docs/warp.md](docs/warp.md)** - Operational guide and tool reference
3. **[docs/layout.md](docs/layout.md)** - Canonical repository structure
4. **memory-bank/*.md** - Project context and decision history
5. **[tools/m0sh1-devops/](tools/m0sh1-devops/)** - DevOps tooling and references

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
mise run k8s-lint           # Helm lint + kubeconform + kube-linter
mise run path-drift         # Enforce repo structure
mise run sensitive-files    # Block secret leaks

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

```
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

1. **Read context first:** Check `memory-bank/activeContext.md`, `memory-bank/decisionLog.md`, `memory-bank/systemPatterns.md`
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
