# Infrastructure Repository

GitOps-based infrastructure management using ArgoCD, Terraform, Ansible, and
Helm.

## 📋 Important Documents

- **[AGENTS.md](AGENTS.md)**: Mandatory rules for all automation and AI tools
- **[docs/warp.md](docs/warp.md)**: Operational guide for tools and workflows
- **[docs/layout.md](docs/layout.md)**: Authoritative repository structure
- **[docs/TODO.md](docs/TODO.md)**: Active infrastructure tasks
- **[docs/done.md](docs/done.md)**: Completed infrastructure work
- **[.github/SECURITY.md](.github/SECURITY.md)**: Security policies and vulnerability reporting

## Repository Structure

```text
.
├── .github/          # GitHub configuration (workflows, agents, CODEOWNERS)
├── apps/             # Helm wrapper charts (cluster/ and user/)
├── argocd/           # ArgoCD Application manifests (apps/ and disabled/)
├── cluster/          # Bootstrap and environment configs
├── terraform/        # Infrastructure as Code (Proxmox VMs, LXCs, network)
├── ansible/          # Configuration management (hosts, k3s, services)
├── docs/             # Documentation (layout.md, network, bootstrap)
├── memory-bank/      # AI project context and decision history
└── tools/            # CI scripts and DevOps automation (m0sh1-devops/)
```

## Prerequisites

- **Kubernetes Cluster**: k3s v1.35.0+k3s1 (1 control plane + 4 workers)
- **ArgoCD**: GitOps continuous delivery (app-of-apps pattern)
- **Proxmox VE**: 3-node cluster (pve-01, pve-02, pve-03)
- **Terraform**: >= 1.0.0 (for Proxmox resources)
- **Ansible**: >= 2.9 (for host configuration)
- **Helm**: >= 3.0.0 (wrapper charts only)
- **kubectl**: Configured for target cluster

## Security

### Critical policy: never commit secrets

- Use **Bitnami SealedSecrets** for Kubernetes secrets (kubeseal)
- Use **Ansible Vault** for Ansible sensitive data
- Use **Terraform backend** with encryption for state files (never commit .tfstate)
- Review [.github/SECURITY.md](.github/SECURITY.md) for security policies

## Network Architecture

**4-VLAN Design** (OPNsense routing):

| VLAN | Subnet | Gateway | Purpose |
|------|--------|---------|---------|
| none | 10.0.0.0/24 | 10.0.0.1 (Speedport) | Home WiFi clients |
| 10 | 10.0.10.0/24 | 10.0.10.1 (OPNsense) | Proxmox, DNS, PBS, SMB, Bastion |
| 20 | 10.0.20.0/24 | 10.0.20.1 (OPNsense) | K8s control plane + workers |
| 30 | 10.0.30.0/24 | 10.0.30.1 (OPNsense) | Traefik VIP, LoadBalancers |

See [docs/diaries/network-vlan-architecture.md](docs/diaries/network-vlan-architecture.md) for complete details.

## Getting Started

### 1. Bootstrap ArgoCD (Disaster Recovery Only)

**Bootstrap is for fresh cluster installation or catastrophic failure recovery only.**

```bash
# Apply minimal ArgoCD installation
kubectl apply -k cluster/bootstrap/argocd/

# Wait for ArgoCD ready
kubectl wait -n argocd --for=condition=available deploy/argocd-server --timeout=300s

# Deploy root application (app-of-apps pattern)
kubectl apply -f argocd/apps-root.yaml

# CRITICAL: Verify infra-root points to argocd/apps (NOT cluster/bootstrap)
kubectl get application infra-root -n argocd -o yaml | grep "path:"
# Expected: path: argocd/apps
```

**After bootstrap, ALL changes flow through Git → ArgoCD automated sync.**

Bootstrap procedure is captured in `cluster/bootstrap/`; after bootstrap, everything flows through ArgoCD.

### 2. ArgoCD App-of-Apps Pattern

Root application (`argocd/apps-root.yaml`) discovers and deploys all applications under `argocd/apps/**`:

- **Active apps**: `argocd/apps/cluster/*.yaml` (platform) + `argocd/apps/user/*.yaml` (workloads)
- **Disabled apps**: `argocd/disabled/**` (excluded from sync)

```bash
# Add new application: create manifest in argocd/apps/
# ArgoCD auto-discovers within 3 minutes (or force refresh):
kubectl patch application apps-root -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Disable application: move to argocd/disabled/
# ArgoCD auto-prunes resources
```

### 3. Terraform Infrastructure

Provision Proxmox VMs and LXCs:

```bash
cd terraform/envs/lab/
terraform init
terraform plan
terraform apply
```

**Note**: State stored remotely (never committed). Use validation only: `mise run terraform-validate`

### 4. Ansible Configuration

Host provisioning and k3s cluster setup:

```bash
cd ansible/

# Run playbook with vault
ansible-playbook -i inventory playbooks/<playbook>.yaml --ask-vault-pass

# Dry-run first (recommended)
ansible-playbook -i inventory playbooks/<playbook>.yaml --check --diff
```

### 5. Helm Wrapper Charts

All Kubernetes workloads use wrapper chart pattern:

```text
apps/{cluster,user}/<app-name>/
├── Chart.yaml          # Version + upstream dependency pinned
├── values.yaml         # Environment-specific overrides
└── templates/          # Additional resources (SealedSecrets, ConfigMaps)
```

**Never deploy directly with helm install** - commit changes to Git, let ArgoCD sync.

## Workflow

**GitOps Enforcement** (see [AGENTS.md](AGENTS.md)):

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
- ❌ Never create new top-level directories (see [docs/layout.md](docs/layout.md))

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

## Contributing

1. Create feature branch from `main`
2. Make changes following repository conventions
3. Run validation: `mise run k8s-lint && mise run path-drift && mise run sensitive-files`
4. Ensure no secrets committed (pre-commit hooks enforce)
5. Submit pull request with clear description
6. Address review comments from code owners

## Current Infrastructure State

**Phase 3**: GitOps Bootstrap Complete

- ✅ ArgoCD deployed with app-of-apps pattern
- ✅ Base cluster apps: cert-manager, external-dns, sealed-secrets, reflector, MetalLB, Traefik, Proxmox CSI, MinIO, local-path
- ✅ Network: 4-VLAN architecture with OPNsense routing
- ✅ Storage: Proxmox CSI (5 ZFS datasets) + local-path + MinIO object storage
- ✅ DNS: CoreDNS with static Proxmox host entries (fixes CSI DNS failures)
- 🔄 User applications temporarily disabled pending CSI stability validation

See [docs/TODO.md](docs/TODO.md) for active tasks and [docs/done.md](docs/done.md) for completed milestones. Superseded docs live under [docs/archive/](docs/archive/).

## Directory Conventions

- **argocd/apps/**: Active ArgoCD Application manifests (cluster/ and user/)
- **argocd/disabled/**: Disabled applications (excluded from sync)
- **apps/cluster/**: Platform wrapper charts (ArgoCD, Traefik, cert-manager, Proxmox CSI, etc.)
- **apps/user/**: Workload wrapper charts (Harbor, Gitea, Semaphore, etc.)
- **cluster/bootstrap/**: Minimal ArgoCD installation for disaster recovery
- **terraform/**: Proxmox infrastructure (VMs, LXCs, network)
- **ansible/**: Host configuration (Proxmox, k3s, DNS, SMB, PBS)
- **docs/**: Architecture, runbooks, network diagrams
- **memory-bank/**: AI agent context (project brief, decisions, patterns, progress)
- **tools/**: CI scripts, DevOps guards, mise tasks

## Key Files

- [AGENTS.md](AGENTS.md): Hard rules for automation (no imperative operations, no secrets, no structure drift)
- [docs/layout.md](docs/layout.md): Authoritative repository structure
- [docs/warp.md](docs/warp.md): Operational guide (tools, commands, workflows)
- [docs/diaries/network-vlan-architecture.md](docs/diaries/network-vlan-architecture.md): 4-VLAN network design
- [docs/TODO.md](docs/TODO.md): Active tasks and phase tracker
- [docs/done.md](docs/done.md): Completed infrastructure work
- [docs/archive/](docs/archive/): Superseded documents and diagrams
- [mise.toml](mise.toml): Tool version management and task automation

## Code Owners

See [.github/CODEOWNERS](.github/CODEOWNERS) for approval requirements.

## Support

For security issues, see [.github/SECURITY.md](.github/SECURITY.md) for the responsible
disclosure process.
