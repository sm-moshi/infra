# check-idempotency

Ansible playbook idempotency checker written in Go. Validates playbooks for common idempotency issues to ensure reliable, repeatable automation.

## Installation

```bash
cd tools/m0sh1-devops/scripts/check-idempotency
go build -o check-idempotency
```

Binary location: `tools/m0sh1-devops/scripts/check-idempotency/check-idempotency`

## Usage

```bash
# Check single playbook
check-idempotency ansible/playbooks/base.yaml

# Check multiple playbooks
check-idempotency ansible/playbooks/*.yaml

# Include informational issues (strict mode)
check-idempotency -strict ansible/playbooks/*.yaml

# Show only summary (no individual issues)
check-idempotency -summary ansible/playbooks/*.yaml
```

## Detected Issues

### 1. Command/shell tasks without changed_when

Ensures commands properly report when they make changes:

```yaml
# ❌ BAD
- name: Check if file exists
  command: test -f /tmp/myfile
  register: file_check

# ✅ GOOD
- name: Check if file exists
  command: test -f /tmp/myfile
  register: file_check
  changed_when: false
```

### 2. Shell tasks with pipes missing pipefail

Prevents silent failures in piped commands:

```yaml
# ❌ BAD
- name: Process logs
  shell: cat /var/log/app.log | grep ERROR

# ✅ GOOD
- name: Process logs
  shell: |
    set -euo pipefail
    cat /var/log/app.log | grep ERROR
  changed_when: false
```

### 3. Tasks handling secrets without no_log

Prevents credential leakage in logs:

```yaml
# ❌ BAD
- name: Create user
  user:
    name: appuser
    password: "{{ vault_password }}"

# ✅ GOOD
- name: Create user
  user:
    name: appuser
    password: "{{ vault_password }}"
  no_log: true
```

### 4. Tasks missing name attribute

Improves playbook readability and debugging:

```yaml
# ❌ BAD
- command: systemctl restart nginx

# ✅ GOOD
- name: Restart nginx service
  command: systemctl restart nginx
  changed_when: false
```

### 5. Deprecated short module names

Uses fully qualified collection names (FQCN) for clarity:

```yaml
# ❌ BAD (deprecated)
- name: Copy config
  copy:
    src: app.conf
    dest: /etc/app/app.conf

# ✅ GOOD (FQCN)
- name: Copy config
  ansible.builtin.copy:
    src: app.conf
    dest: /etc/app/app.conf
```

### 6. Command module with shell features

Suggests correct module for the task:

```yaml
# ❌ BAD
- name: Process data
  command: echo "test" | wc -l

# ✅ GOOD
- name: Process data
  shell: echo "test" | wc -l
  changed_when: false
```

## Exit Codes

- **0**: All playbooks passed validation
- **1**: Issues found in one or more playbooks
- **2**: Invalid usage (missing arguments, file not found)

## Performance

**5.5x faster than Python version:**

| Implementation | Time (18 playbooks) |
|---------------|---------------------|
| Python        | 61.18 ms            |
| **Go**        | **11.21 ms**        |

## Integration

### CI/CD Pipeline

```yaml
# .github/workflows/ansible-lint.yml
- name: Check Ansible idempotency
  run: |
    tools/ci/check-idempotency \
      ansible/playbooks/*.yaml
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: ansible-idempotency
      name: Check Ansible Idempotency
      entry: tools/ci/check-idempotency
      language: system
      files: ^ansible/playbooks/.*\.ya?ml$
```

### Mise Task

```toml
# mise.toml
[tasks.ansible-idempotency]
run = "tools/ci/check-idempotency ansible/playbooks/*.yaml"
```

## Comparison with Python Version

| Feature | Python | Go | Winner |
|---------|--------|----|---------|
| Execution time | 61ms | 11ms | **Go 5.5x** |
| Binary size | 100MB+ | 2.1MB | **Go** |
| Dependencies | Python + PyYAML | None | **Go** |
| Startup time | ~30ms | <1ms | **Go** |
| Output format | ✅ | ✅ | Identical |
| Exit codes | ✅ | ✅ | Identical |
| CLI flags | `--flag` | `-flag` | Compatible |

**Migration Status:** Python version deprecated to `tools/m0sh1-devops/scripts/deprecated/check_idempotency.py`

## Dependencies

- Go 1.22+
- `gopkg.in/yaml.v3` (YAML parsing)

## Development

```bash
# Build
go build -o check-idempotency

# Test
go test

# Format
go fmt

# Vet
go vet
```

## References

- Validation Report: [GO_VALIDATION_REPORT.md](GO_VALIDATION_REPORT.md)
- Agent Documentation: [../../m0sh1-devops.agent.md](../../m0sh1-devops.agent.md)
- Ansible Best Practices: <https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html>
