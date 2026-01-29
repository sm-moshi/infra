# Apt-Cacher NG Role

Ansible role to install and configure [apt-cacher-ng](https://wiki.debian.org/AptCacherNg), a caching proxy for Debian/Ubuntu package repositories.

## Purpose

This role installs and configures apt-cacher-ng to cache APT packages locally, reducing bandwidth usage and speeding up package installations across multiple systems.

## Features

- ✅ Idempotent installation and configuration
- ✅ Support for check mode (`--check`)
- ✅ Configurable PassThroughPattern for HTTPS repositories
- ✅ Optional local client configuration
- ✅ Configurable bind address and port
- ✅ Optional admin authentication
- ✅ Service management (enable/disable, start/stop)

## Requirements

- Debian 12 (Bookworm) or Debian 13 (Trixie)
- Ansible >= 2.15
- Root or sudo access

## Role Variables

All variables are prefixed with `apt_cacher_ng_` per Ansible best practices.

### Core Configuration

```yaml
# Package and service names
apt_cacher_ng_package: "apt-cacher-ng"
apt_cacher_ng_service: "apt-cacher-ng"
apt_cacher_ng_additional_packages:
  - "avahi-daemon"

# Network configuration
apt_cacher_ng_port: 3142
apt_cacher_ng_bind_address: "0.0.0.0"  # All interfaces, use "127.0.0.1" for localhost only

# Enable HTTPS passthrough (allows caching of HTTPS repositories)
apt_cacher_ng_passthrough_pattern_enabled: true

# Configure local host to use the cache
apt_cacher_ng_configure_local_client: true

# Service state
apt_cacher_ng_service_state: "started"
apt_cacher_ng_service_enabled: true
```

### Advanced Configuration

```yaml
# Cache and log directories
apt_cacher_ng_cache_dir: "/var/cache/apt-cacher-ng"
apt_cacher_ng_log_dir: "/var/log/apt-cacher-ng"

# Admin authentication (optional)
apt_cacher_ng_admin_user: ""
apt_cacher_ng_admin_password: ""

# Allow cache deletion via web interface
apt_cacher_ng_allow_cache_deletion: false
```

## Dependencies

None.

## Example Playbooks

### Basic Installation

```yaml
---
- name: Install apt-cacher-ng on cache server
  hosts: apt_cache_servers
  become: true
  roles:
    - role: apt_cacher_ng
      vars:
        apt_cacher_ng_configure_local_client: false  # Dedicated cache server
```

### Installation with Client Configuration

```yaml
---
- name: Install apt-cacher-ng with local client
  hosts: lxc_containers
  become: true
  roles:
    - role: apt_cacher_ng
      vars:
        apt_cacher_ng_configure_local_client: true
        apt_cacher_ng_passthrough_pattern_enabled: true
```

### Custom Port and Bind Address

```yaml
---
- name: Install apt-cacher-ng with custom config
  hosts: apt_cache
  become: true
  roles:
    - role: apt_cacher_ng
      vars:
        apt_cacher_ng_port: 8080
        apt_cacher_ng_bind_address: "10.0.10.24"
        apt_cacher_ng_configure_local_client: false
```

### With Admin Authentication

```yaml
---
- name: Install apt-cacher-ng with admin auth
  hosts: apt_cache
  become: true
  roles:
    - role: apt_cacher_ng
      vars:
        apt_cacher_ng_admin_user: "admin"
        apt_cacher_ng_admin_password: "{{ vault_apt_cacher_admin_password }}"
        apt_cacher_ng_allow_cache_deletion: true
```

## Client Configuration

To configure other hosts to use the apt-cacher-ng server, create `/etc/apt/apt.conf.d/00aptproxy.conf` on each client:

```text
Acquire::http::Proxy "http://<cache-server-ip>:3142";
```

Or use Ansible:

```yaml
---
- name: Configure APT clients to use apt-cacher-ng
  hosts: all
  become: true
  tasks:
    - name: Configure APT to use apt-cacher-ng proxy
      ansible.builtin.copy:
        content: |
          Acquire::http::Proxy "http://10.0.10.24:3142";
        dest: "/etc/apt/apt.conf.d/00aptproxy.conf"
        owner: "root"
        group: "root"
        mode: "0644"
```

## Accessing the Web Interface

After installation, access the apt-cacher-ng web interface at:

```text
http://<server-ip>:3142/acng-report.html
```

## Tags

This role does not define specific tags. Use standard Ansible tags with the role name:

```bash
ansible-playbook site.yml --tags apt_cacher_ng
```

## Idempotency

All tasks in this role are idempotent:

- Package installation uses `state: present`
- Configuration uses `lineinfile` with `regexp` for idempotent updates
- Service management uses `systemd_service` module
- File operations use proper `state` parameters

Running the playbook multiple times produces no changes after the initial run.

## Check Mode Support

This role fully supports Ansible check mode (`--check`):

```bash
ansible-playbook site.yml --check --diff
```

## License

MIT-0 (MIT No Attribution)

## Author

m0sh1

## References

- [Debian Wiki: AptCacherNg](https://wiki.debian.org/AptCacherNg)
- [apt-cacher-ng Documentation](https://www.unix-ag.uni-kl.de/~bloch/acng/)
- [Community Scripts ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)
