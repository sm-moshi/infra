# Infrastructure Repository

GitOps-based infrastructure management using ArgoCD, Terraform, Ansible, and
Helm.

## 📋 Important Documents

- **[AGENTS.md](AGENTS.md)**: Mandatory rules for all automation and AI tools
- **[SECURITY.md](SECURITY.md)**: Security policies and vulnerability reporting
- **[CHANGELOG.md](CHANGELOG.md)**: Infrastructure change history
- **[docs/warp.md](docs/warp.md)**: Operational guide for working in this repo
- **[docs/checklist.md](docs/checklist.md)**: Infrastructure milestone tracker

## Repository Structure

```text
.
├── .github/          # GitHub configuration (workflows, CODEOWNERS)
├── apps/             # Helm wrapper charts (cluster/ and user/)
├── argocd/           # ArgoCD Application manifests
├── cluster/          # Bootstrap and environment configs
├── terraform/        # Infrastructure as Code
├── ansible/          # Configuration management
├── docs/             # Documentation (warp.md, layout.md, history.md)
└── tools/            # CI scripts and DevOps automation (m0sh1-devops/)
```

## Prerequisites

- **Kubernetes Cluster**: Target cluster for ArgoCD deployments
- **ArgoCD**: GitOps continuous delivery tool
- **Terraform**: >= 1.0.0
- **Ansible**: >= 2.9
- **Helm**: >= 3.0.0
- **kubectl**: Configured for target cluster

## Security

### Critical policy: never commit secrets

- Use **Sealed Secrets** for Kubernetes secrets
- Use **Ansible Vault** for Ansible sensitive data
- Use **Terraform backend** with encryption for state files
- Review [SECURITY.md](SECURITY.md) for security policies

## Getting Started

### 1. ArgoCD Applications

ArgoCD applications define what should be deployed to Kubernetes clusters:

```bash
cd argocd/
# Review and customize application manifests
kubectl apply -f <app-manifest>.yaml
```

### 2. Terraform Infrastructure

Provision cloud infrastructure:

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

**Note**: Terraform state is stored remotely and never committed to git.

### 3. Ansible Configuration

Run configuration management playbooks:

```bash
cd ansible/
# Encrypt sensitive files with ansible-vault
ansible-vault encrypt secrets.yml
ansible-playbook -i inventory playbook.yml --ask-vault-pass
```

### 4. Helm Charts

Deploy applications using Helm:

```bash
cd helm/
helm dependency update <chart-name>/
helm install <release-name> <chart-name>/
```

## Workflow

1. **Make changes** to infrastructure definitions in feature branches.
2. **Review changes** through pull requests.
3. **Merge to main** after approval.
4. **ArgoCD syncs** automatically from the main branch.
5. **Monitor deployments** via the ArgoCD UI.

## Contributing

1. Create a feature branch from `main`.
2. Make your changes following repository conventions.
3. Ensure no secrets are committed (use pre-commit hooks).
4. Submit a pull request with a clear description.
5. Address review comments from code owners.

## Directory Conventions

- **argocd/**: ArgoCD application definitions
    (Application, AppProject resources)
- **terraform/**: Terraform modules and root configurations
- **ansible/**: Playbooks, roles, and inventory (encrypted with
    vault)
- **helm/**: Wrapper charts with custom values files
- **docs/**: Architecture diagrams, runbooks, and additional
    documentation

## Code Owners

See [.github/CODEOWNERS](.github/CODEOWNERS) for approval requirements.

## Support

For security issues, see [SECURITY.md](SECURITY.md) for the responsible
disclosure process.
