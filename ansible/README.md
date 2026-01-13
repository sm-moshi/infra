# Ansible Configuration Management

This directory contains Ansible playbooks, roles, and inventory for configuration management.

## Structure

```
ansible/
├── playbooks/        # Ansible playbooks
├── roles/            # Custom Ansible roles
├── inventory/        # Inventory files (encrypted with vault)
├── group_vars/       # Group variables (encrypt sensitive data)
├── host_vars/        # Host variables (encrypt sensitive data)
├── requirements.yml  # External roles and collections
└── README.md
```

## Prerequisites

- Ansible >= 2.9
- Python >= 3.6
- SSH access to target hosts
- Vault password file (stored outside repository)

## Usage

### Running Playbooks

```bash
cd ansible

# Run with vault password prompt
ansible-playbook -i inventory/production playbooks/site.yml --ask-vault-pass

# Run with vault password file
ansible-playbook -i inventory/production playbooks/site.yml --vault-password-file ~/.vault_pass

# Check mode (dry run)
ansible-playbook -i inventory/production playbooks/site.yml --check
```

### Installing Dependencies

```bash
ansible-galaxy install -r requirements.yml
```

## Ansible Vault

**Always encrypt sensitive data**

### Encrypting Files

```bash
# Encrypt a new file
ansible-vault encrypt group_vars/production/secrets.yml

# Encrypt existing file
ansible-vault encrypt inventory/production/hosts

# Edit encrypted file
ansible-vault edit group_vars/production/secrets.yml

# Decrypt file (use with caution)
ansible-vault decrypt group_vars/production/secrets.yml
```

### Vault Password File

**NEVER commit vault password file to repository**

Store vault password file outside the repository:

```bash
echo "my-secure-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

Reference in ansible.cfg:

```ini
[defaults]
vault_password_file = ~/.vault_pass
```

## Best Practices

- Use Ansible Vault for **all** sensitive data
- Encrypt entire inventory files if they contain secrets
- Use `no_log: true` for tasks handling sensitive data
- Use SSH keys instead of passwords
- Implement idempotent playbooks
- Use roles for reusability
- Pin collection and role versions
- Test in non-production first
- Use tags for selective execution

## Directory Structure Example

```
ansible/
├── ansible.cfg
├── playbooks/
│   ├── site.yml
│   ├── webservers.yml
│   └── databases.yml
├── roles/
│   ├── common/
│   ├── nginx/
│   └── postgresql/
├── inventory/
│   ├── production
│   └── staging
├── group_vars/
│   ├── all/
│   │   └── vars.yml
│   ├── production/
│   │   └── vault.yml  # Encrypted
│   └── staging/
│       └── vault.yml  # Encrypted
└── requirements.yml
```

## Security

- ⚠️ **Never commit** unencrypted secrets
- ⚠️ **Never commit** vault password files
- Always use `ansible-vault` for sensitive data
- Use `no_log` for tasks with secrets
- Restrict inventory file permissions
- Use SSH key-based authentication
- Rotate vault passwords regularly
- Review playbooks for credential leaks

## Vault Variables

Store secrets in vault files:

```yaml
# group_vars/production/vault.yml (encrypted)
vault_db_password: "super-secret-password"
vault_api_key: "secret-api-key"
```

Reference in playbooks:

```yaml
# playbooks/site.yml
- name: Configure database
  postgresql_user:
    password: "{{ vault_db_password }}"
  no_log: true
```

## Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Vault Guide](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
