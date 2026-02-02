# sensitive-files-guard

Repository security guard that prevents committing sensitive files like credentials, private keys, and environment files. Written in Go for fast, reliable protection.

## Installation

```bash
cd tools/m0sh1-devops/scripts/sensitive-files-guard
go build -ldflags="-s -w" -o sensitive-files-guard
```

Binary location: `tools/m0sh1-devops/scripts/sensitive-files-guard/sensitive-files-guard`

## Usage

```bash
# Check for sensitive files (pre-commit or CI)
sensitive-files-guard

# List all patterns
sensitive-files-guard -list-patterns
```

## Detected Patterns

### Sensitive Files (Forbidden)

- **Environment files**: `.env`, `op.env`, `config.yaml`
- **SSH keys**: `id_rsa`, `id_ed25519`
- **Certificates**: `*.p12`, `*.pfx`, `*.key`, `*privkey*.pem`, `*private*.pem`
- **Terraform state**: `*.tfstate`, `*.tfvars`, `secrets.auto.tfvars`
- **Kubernetes configs**: `kubeconfig`
- **Unsealed secrets**: `*-unsealed.yaml`, `*unsealed*.yaml`

### Allowed Exceptions (Ignore List)

- **SealedSecrets**: `*.sealedsecret.yaml` (encrypted)
- **Managed secrets**: `apps/cluster/secrets-cluster/`, `apps/cluster/sealed-secrets/`
- **Ansible roles**: `ansible/roles/*/tasks/config.yaml`, `ansible/roles/*/handlers/config.yaml`
- **Helm charts**: `apps/*/charts/`, `apps/*/Chart.lock`
- **Documentation**: `docs/archive/`
- **Terraform defaults**: `defaults.auto.tfvars`

## How It Works

1. **Pre-commit mode**: Scans staged files (`git diff --cached`)
2. **CI mode**: Scans all tracked files (`git ls-files`)
3. **Pattern matching**: Uses compiled regex for fast checks
4. **Exception handling**: Allows SealedSecrets and managed secrets
5. **Exit codes**:
   - `0`: No sensitive files detected
   - `1`: Sensitive files found (blocks commit/CI)
   - `2`: Invalid usage or system error

## Performance

**4.4x faster than shell version:**

| Implementation | Time (full repo scan) |
|---------------|----------------------|
| Shell (grep)  | 46.68 ms             |
| **Go**        | **10.51 ms**         |

## Integration

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: sensitive-files
      name: Check for sensitive files
      entry: tools/m0sh1-devops/scripts/sensitive-files-guard/sensitive-files-guard
      language: system
      pass_filenames: false
      always_run: true
```

### CI Pipeline

```yaml
# .github/workflows/ci.yml
- name: Check for sensitive files
  run: |
    tools/m0sh1-devops/scripts/sensitive-files-guard/sensitive-files-guard
```

### Mise Task

```toml
# mise.toml
[tasks.sensitive-files]
run = "tools/m0sh1-devops/scripts/sensitive-files-guard/sensitive-files-guard"
```

## Examples

### ✅ Clean Repository

```bash
$ sensitive-files-guard
✅ Sensitive file check passed
```

### ❌ Sensitive File Detected

```bash
$ sensitive-files-guard
❌ Forbidden sensitive files detected:
terraform/op.env
ansible/.env
apps/user/myapp/unsealed-secret.yaml
```

### 📋 List Patterns

```bash
$ sensitive-files-guard -list-patterns
Sensitive Patterns:
  (^|/)(config\.yaml)$
  (^|/)(ansible|terraform)/op\.env$
  (^|/)\.env([._-].*)?$
  (^|/)(kubeconfig)(\..*)?$
  (^|/).*id_(rsa|ed25519)(\..*)?$
  ...

Ignore Patterns:
  (^|/)apps/cluster/secrets-cluster/
  (^|/)apps/cluster/sealed-secrets/
  \.sealedsecret\.ya?ml$
  ...
```

## Comparison with Shell Version

| Feature | Shell | Go | Winner |
|---------|-------|----|---------|
| Execution time | 46.68ms | 10.51ms | **Go 4.4x** |
| Dependencies | grep, git | None | **Go** |
| Regex compilation | Runtime | Compile-time | **Go** |
| Error messages | Basic | Detailed | **Go** |
| Pattern listing | N/A | Built-in | **Go** |
| Cross-platform | POSIX only | All platforms | **Go** |

**Migration Status:** Shell version deprecated; Go binary is the default via `tools/ci/sensitive-files-guard`.

## Why This Matters

Committing sensitive files can lead to:

- **Credential leaks**: API keys, passwords exposed publicly
- **Security breaches**: Private keys accessible to attackers
- **Compliance violations**: GDPR, PCI-DSS, SOC 2 failures
- **Incident response**: Costly key rotation, service disruption

This tool provides the **first line of defense** against accidental secrets exposure.

## Adding Custom Patterns

Edit `main.go` to add new patterns:

```go
var sensitivePatternStrings = []string{
    // Existing patterns...
    `(^|/)\.npmrc$`,              // Add npm credentials
    `(^|/)\.pypirc$`,             // Add PyPI credentials
    `(^|/).*\.kube.*config.*$`,   // Add kubeconfig variants
}
```

Rebuild after changes:

```bash
go build -ldflags="-s -w" -o sensitive-files-guard
```

## Dependencies

- Go 1.22+
- Git (for repository operations)
- No external Go packages (uses standard library only)

## Development

```bash
# Build
go build -o sensitive-files-guard

# Test
go test

# Format
go fmt

# Vet
go vet
```

## References

- CI Binary: `tools/ci/sensitive-files-guard`
- Agent Documentation: [../../m0sh1-devops.agent.md](../../m0sh1-devops.agent.md)
- Repository Layout: [../../../../docs/layout.md](../../../../docs/layout.md)
