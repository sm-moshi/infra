# Security Policy

## Overview

This infrastructure repository manages critical systems using GitOps
principles. Security is paramount, and all contributors must follow these
guidelines.

## Reporting a Vulnerability

> ⚠️ Do not open public issues for security vulnerabilities.

If you discover a security vulnerability, please report it privately:

1. **Email**: Send details to the repository administrators (see
   `CODEOWNERS`).
2. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
3. **Response Time**: You will receive acknowledgment within 48 hours.
4. **Disclosure**: We follow coordinated vulnerability disclosure.

## Security Best Practices

### Secrets Management

> ❗ Never commit secrets to this repository.

- ✅ **DO**: Use Sealed Secrets for Kubernetes secrets
- ✅ **DO**: Use Ansible Vault for sensitive Ansible variables
- ✅ **DO**: Use Terraform backend encryption for state files
- ✅ **DO**: Use environment-specific secret management tools
- ❌ **DON'T**: Commit passwords, API keys, tokens, or certificates
- ❌ **DON'T**: Commit private keys or SSH keys
- ❌ **DON'T**: Commit kubeconfig files
- ❌ **DON'T**: Commit Terraform state files

### Kubernetes Secrets

Use **Sealed Secrets** for encrypting secrets that are safe to commit:

```bash
# Create a sealed secret (this CAN be committed)
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml
```

### Ansible Vault

Encrypt sensitive Ansible variables:

```bash
# Encrypt a file
ansible-vault encrypt vars/secrets.yml

# Decrypt for editing
ansible-vault edit vars/secrets.yml

# Use vault password file (stored outside repo)
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass
```

### Terraform State

- Store state in remote backend (S3, Azure Storage, GCS)
- Enable state file encryption
- Never commit `.tfstate` files to git
- Use state locking to prevent concurrent modifications

### Pre-Commit Checks

Before committing, ensure:

1. No secrets in files (use git-secrets or detect-secrets)
2. No sensitive files staged (check `git status`)
3. Review `git diff` for accidental sensitive data
4. Terraform plan has no leaked credentials

## Infrastructure Security

### Access Control

- Use principle of least privilege
- Implement RBAC in Kubernetes
- Use service accounts with minimal permissions
- Rotate credentials regularly

### Network Security

- Use network policies in Kubernetes
- Implement security groups/firewalls at infrastructure level
- Encrypt data in transit (TLS/SSL)
- Encrypt data at rest

### Auditing

- Enable audit logging for Kubernetes
- Monitor ArgoCD sync activities
- Review Terraform plans before applying
- Track all infrastructure changes via Git history

### Container Security

- Use minimal base images
- Scan images for vulnerabilities
- Don't run containers as root
- Use read-only file systems where possible

## Code Review Requirements

All changes must be reviewed for security:

- [ ] No secrets or credentials committed
- [ ] Proper use of Sealed Secrets or Ansible Vault
- [ ] Least privilege access controls
- [ ] Network policies defined
- [ ] Resource limits specified
- [ ] Security context constraints applied

## Compliance

This repository should maintain compliance with:

- Company security policies
- Industry standards (CIS benchmarks)
- Regulatory requirements (if applicable)

## Security Updates

Dependencies and tools should be kept up to date:

- Terraform providers
- Helm charts
- Ansible collections
- ArgoCD version
- Kubernetes version

## Incident Response

If a security incident occurs:

1. Immediately revoke compromised credentials
2. Assess impact and scope
3. Notify security team
4. Document timeline and actions taken
5. Conduct post-mortem review
6. Update security measures

## Resources

- Kubernetes Security Best Practices:
   <https://kubernetes.io/docs/concepts/security/>
- Terraform Recommended Practices:
   <https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices>
- Ansible Vault:
   <https://docs.ansible.com/ansible/latest/user_guide/vault.html>
- Sealed Secrets:
   <https://github.com/bitnami-labs/sealed-secrets>
- ArgoCD Security:
   <https://argo-cd.readthedocs.io/en/stable/operator-manual/security/>

## Contact

For security concerns, contact the infrastructure team via CODEOWNERS.
