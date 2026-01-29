# OPNsense Role

Ansible role for managing OPNsense firewall/router routine operations.

## Description

This role provides idempotent tasks for common OPNsense management operations including:

- Deploying utility scripts for package management
- Running shell commands via SSH
- Service management (reload, restart)
- Configuration backups
- System updates and package management
- Status checks

## Requirements

- OPNsense host accessible via SSH
- SSH key-based authentication configured
- Python 3.x on control node
- FreeBSD-compatible shell on OPNsense

## Role Variables

### Required Variables

None - all variables have defaults.

### Optional Variables

Available in `defaults/main.yml`:

- `opnsense_backup_dir` - Local directory for config backups (default: `/tmp/opnsense-backups`)
- `opnsense_backup_retention_days` - Days to retain local backups (default: `30`)
- `opnsense_command_timeout` - Timeout for command execution in seconds (default: `300`)
- `opnsense_scripts_dir` - Directory on OPNsense for utility scripts (default: `/usr/local/bin/opn-scripts`)

## Utility Scripts

The role deploys three package management utility scripts to OPNsense:

### pkg_wizard.sh

Searches for and installs packages from FreeBSD upstream repositories.

**Features:**

- Searches both OPNsense and FreeBSD upstream repos
- Uses `pkg+http://` SRV protocol for mirror resolution
- Interactive installation with dependency info
- Creates temporary repository config for searches
- Optional persistent repo configuration
- Color-coded output for easy reading
- Tries quarterly and latest branches

**Usage:**

```bash
# Search FreeBSD upstream repos (default)
/usr/local/bin/opn-scripts/pkg_wizard.sh htop

# Search only configured OPNsense repos
/usr/local/bin/opn-scripts/pkg_wizard.sh htop --local
```

**How it works:**

1. Checks FreeBSD quarterly and latest repositories
2. Uses `pkg+http://pkg.FreeBSD.org/${ABI}/quarterly` URL format with SRV mirror resolution
3. Creates temporary repo config for catalog updates
4. Displays package info, version, description, and dependencies
5. Optionally creates persistent repo config at `/usr/local/etc/pkg/repos/FreeBSD-Upstream.conf`
6. Installs package with dependencies
7. Recommends disabling upstream repo after installation

**Repository Configuration:**

The script creates a repository configuration with **low priority** to prevent accidentally upgrading OPNsense packages:

```ucl
FreeBSD-Upstream: {
    url: "pkg+http://pkg.FreeBSD.org/${ABI}/quarterly",
    mirror_type: "srv",
    signature_type: "fingerprints",
    fingerprints: "/usr/share/keys/pkg",
    enabled: yes,
    priority: 100  # Lower priority than OPNsense (0)
}
```

**CRITICAL SAFETY FEATURES:**

1. **Blocks critical packages**: Prevents installing `pkg`, `ca_root_nss`, `opnsense`, `opnsense-update` from upstream
2. **Low priority (100)**: Ensures OPNsense repo (priority 0) is always preferred for installed packages
3. **Explicit repo flag**: Uses `pkg install -r FreeBSD-Upstream <package>` to prevent cross-repo upgrades
4. **Auto-disable option**: Recommends disabling repo after installation

#### Repository Priority System

In pkg, **lower numbers = higher priority**:

- OPNsense repo: priority 0 (highest)
- FreeBSD-Upstream: priority 100 (lowest)

This ensures running `pkg upgrade` will never prefer FreeBSD upstream versions over OPNsense versions.

**Note:** Installing from FreeBSD upstream repos may introduce packages not officially supported by OPNsense. Use with caution and **always disable the repo after installation** to prevent unintended upgrades.

### pkg_available.sh

Checks for orphaned packages (installed but not in any repository).

**Features:**

- Scans all configured repositories
- Identifies packages not available in repos
- Color-coded output for easy identification
- Progress reporting and summary statistics

**Usage:**

```bash
/usr/local/bin/opn-scripts/pkg_available.sh
```

### pkg_list.sh

Verifies installed packages against repositories.

**Features:**

- Lists all installed packages
- Checks availability in repositories
- Progress indication with counters
- Quiet mode for scripting
- Summary statistics

**Usage:**

```bash
/usr/local/bin/opn-scripts/pkg_list.sh [--quiet]
```

## Dependencies

None

## Example Playbook

```yaml
---
- name: Manage OPNsense
  hosts: opnsense
  become: false
  roles:
    - role: opnsense
```

## Example with custom variables

```yaml
---
- name: Manage OPNsense with custom settings
  hosts: opnsense
  become: false
  vars:
    opnsense_backup_dir: /backup/opnsense
    opnsense_command_timeout: 600
  roles:
    - role: opnsense
```

## Tags

- `opnsense` - All tasks in this role
- `opnsense_scripts` - Deploy utility scripts
- `opnsense_backup` - Configuration backup tasks
- `opnsense_update` - Update and package management tasks
- `opnsense_service` - Service management tasks
- `opnsense_status` - Status checks

## Usage Examples

### Deploy utility scripts

```bash
ansible-playbook -i ansible/inventory ansible/playbooks/opnsense.yaml --tags opnsense_scripts
```

### Backup configuration

```bash
ansible-playbook -i ansible/inventory ansible/playbooks/opnsense.yaml --tags opnsense_backup
```

### Check system status

```bash
ansible-playbook -i ansible/inventory ansible/playbooks/opnsense.yaml --tags opnsense_status
```

### Using deployed scripts on OPNsense

After deploying scripts, SSH to OPNsense and run:

```bash
# Install a package with dependencies
/usr/local/bin/opn-scripts/pkg_wizard.sh htop

# Check for orphaned packages
/usr/local/bin/opn-scripts/pkg_available.sh

# List installed packages
/usr/local/bin/opn-scripts/pkg_list.sh
```

## Notes

- All tasks are idempotent and support check mode
- Commands are executed via SSH without requiring `become` privileges
- Uses FreeBSD-specific commands appropriate for OPNsense

## License

MIT
