# Documentation

This directory contains operational guides, architectural documentation, and reference materials for the infrastructure repository.

## Primary Documents

### Architecture & Conventions

- **[layout.md](layout.md)**: Repository structure specification (authoritative)
- **[network-vlan-architecture.md](network-vlan-architecture.md)**: 4-VLAN network design (VLAN 10/20/30)
- **[terraform-vlan-rebuild.md](terraform-vlan-rebuild.md)**: VLAN infrastructure rebuild guide

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

## Related Files

- **[/AGENTS.md](/AGENTS.md)**: Automation enforcement rules (root)
- **[/.github/SECURITY.md](/.github/SECURITY.md)**: Security policies
- **[/.github/CODEOWNERS](../.github/CODEOWNERS)**: Code ownership (.github)
