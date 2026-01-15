# Changelog Strategy

## Purpose

CHANGELOG.md tracks **significant infrastructure milestones**, not individual commits.

## When to Update

Update CHANGELOG.md when completing major milestones:

- ✅ **Phase completions** (Phase 0: Repository Contract complete)
- ✅ **Breaking changes** (Terraform state migration, API version upgrades)
- ✅ **New infrastructure** (New cluster, new namespace, new integrations)
- ✅ **Deprecations** (Removing observability stack, retiring old services)
- ✅ **Security updates** (Credential rotations, policy changes)

Do NOT update for:

- ❌ Individual Helm chart version bumps (tracked in git log)
- ❌ Value file tweaks (tracked in git log)
- ❌ Documentation updates (tracked in git log)

## Format

Use semantic versioning for infrastructure milestones:

- **v1.0.0**: Production-ready baseline (Phase 2 complete)
- **v0.9.0**: Pre-production (Phase 1 complete)
- **v0.1.0**: Repository foundation (Phase 0 complete)

## Workflow

### Manual Update (Recommended)

```bash
# Edit CHANGELOG.md manually when completing a phase
vim CHANGELOG.md

# Example entry:
## [0.1.0] - 2026-01-14

### Infrastructure
- ✅ Phase 0 complete: Repository contract, CI/CD, guardrails

### Features
- Added path-drift-check enforcement
- Added k8s-lint validation pipeline
- Added Helm wrapper chart scaffolding
```

### Automated Generation

```bash
# Preview unreleased changes
mise run changelog-unreleased

# Generate from conventional commits (if using)
mise run changelog
```

## Best Practices

1. **Keep it high-level**: Focus on what changed infrastructure-wise
2. **Reference phases**: Link to docs/checklist.md phases
3. **Include breaking changes prominently**: Alert operators
4. **Date milestones**: Track when infrastructure evolved
5. **Tag releases**: `git tag v0.1.0` when publishing changelog entries

## Related Files

- [cliff.toml](../cliff.toml): git-cliff configuration
- [docs/checklist.md](checklist.md): Phase tracking
- [mise.toml](../mise.toml): Changelog tasks (changelog, changelog-unreleased)

## For Detailed History

- **Git log**: `git log --oneline --graph` for commit history
- **ArgoCD UI**: For deployment history
- **docs/history.md**: For supply chain history (image tags)
