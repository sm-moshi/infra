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
├── apps/             # Helm wrapper charts (cluster/ + secrets-cluster/, user/ + secrets-apps/)
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
  - Cluster credentials centralized in secrets-cluster/ (9 SealedSecrets)
  - User app credentials centralized in secrets-apps/ (21 SealedSecrets)
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

## Tech Stack

**Infrastructure:**

- **Hypervisor**: Proxmox VE 3-node cluster (ZFS storage, 4-VLAN networking)
- **Orchestration**: k3s v1.35.0+k3s1 (1 control plane + 4 workers)
- **GitOps**: ArgoCD (app-of-apps pattern, automated sync)
- **Storage**: Proxmox CSI (ZFS), MinIO S3 (object storage), CloudNativePG (PostgreSQL)

**Deployment:**

- **IaC**: Terraform (Proxmox provider for VMs/LXCs/network)
- **Config Management**: Ansible (host provisioning, k3s setup, system services)
- **Package Management**: Helm 3 (wrapper chart pattern)

**Security:**

- **Secrets**: Bitnami SealedSecrets (Kubernetes), Ansible Vault (hosts)
- **Ingress**: Traefik (cert-manager for TLS, Cloudflare Tunnel for external access)
- **Network**: OPNsense firewall (VLAN routing, VPN gateway)

**Observability:**

- Prometheus (metrics), Grafana (dashboards), Loki (logs) n- *planned*

## Project Status

**Current Phase:** GitOps Core Operational

✅ **Completed:**

- ArgoCD app-of-apps deployment with 30+ applications
- SealedSecrets centralization (9 cluster + 21 user app credentials)
- 4-VLAN network architecture with OPNsense
- Storage pipeline ready (Proxmox CSI → MinIO → CloudNativePG)
- External access via Cloudflare Tunnel (argocd.m0sh1.cc)

🔄 **In Progress:**Pl

- Security hardening (437 Snyk findings, 5-phase remediation plan)
- PostgreSQL migration to per-app CNPG clusters
- Application deployments (Harbor, Gitea, Semaphore, NetBox)

📋 **Planned:**

- Observability stack (Prometheus, Grafana, Loki)
- Backup automation (Velero, CNPG S3 backups)
- Disaster recovery testing

See [docs/TODO.md](docs/TODO.md) for active tasks and [docs/done.md](docs/done.md) for completed milestones.

## Documentation

Operational guides and architecture documentation live in [docs/](docs/):

- **[docs/getting-started.md](docs/getting-started.md)**: Bootstrap procedures and operational workflows
- **[docs/warp.md](docs/warp.md)**: Tool reference and validation commands
- **[docs/layout.md](docs/layout.md)**: Repository structure specification
- **[AGENTS.md](AGENTS.md)**: Automation rules and GitOps enforcement

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

## Development

This is a personal home lab repository. For operational procedures, see [docs/getting-started.md](docs/getting-started.md).

## Directory Conventions

- **argocd/apps/**: Active ArgoCD Application manifests (cluster/ and user/)
- **argocd/disabled/**: Disabled applications (excluded from sync)
- **apps/cluster/**: Platform wrapper charts (ArgoCD, Traefik, cert-manager, Proxmox CSI, etc.)
- **apps/cluster/secrets-cluster/**: Centralized cluster credentials (Kustomize, 11 SealedSecrets)
- **apps/user/**: Workload wrapper charts (Harbor, Gitea, Semaphore, etc.)
- **apps/user/secrets-apps/**: Centralized user app credentials (Kustomize, 21 SealedSecrets)
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
