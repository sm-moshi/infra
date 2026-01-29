# Documentation

This directory contains operational guides, architectural documentation, and reference materials for the infrastructure repository.

## Primary Documents

### Architecture & Conventions

- **[layout.md](layout.md)**: Repository structure specification (authoritative)
- **[diaries/network-vlan-architecture.md](diaries/network-vlan-architecture.md)**: 4-VLAN network design (VLAN 10/20/30)
- **[diaries/terraform-vlan-rebuild.md](diaries/terraform-vlan-rebuild.md)**: VLAN infrastructure rebuild guide

## Archive

Previous versions of documentation files are preserved in [archive/](archive/).

## Documentation Structure

```text
docs/
├── README.md              # This file
├── layout.md              # Structure spec
├── history.md             # Supply chain docs
├── non-git/               # Self-Descriptive title
└── archive/               # Historical versions
```

## Renovate

- Config lives in `renovate.json` at repo root.
- Enabled managers: `argocd` (Application manifests) and `pre-commit` (hooks).
- `:enablePreCommit` preset is active for hook updates.

## Related Files

- **[/AGENTS.md](/AGENTS.md)**: Automation enforcement rules (root)
- **[/.github/SECURITY.md](/.github/SECURITY.md)**: GitHub security policies
- **[/.github/CODEOWNERS](../.github/CODEOWNERS)**: GitHub code ownership (.github)
