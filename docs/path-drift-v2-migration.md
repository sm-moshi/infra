# Path Drift Check V2 Adoption Complete

**Date:** 2026-01-20
**Status:** ✅ Complete

## Changes Made

### 1. Replaced path-drift-check.sh with V2 implementation

**Old version** (`path-drift-check.sh`):

- Simple case statement for allowlist
- Basic forbidden dir checks
- Generic deprecated reference scanning

**New version** (adopted from `path-drift-check-v2.sh`):

- Regex-based allowlist (`ALLOWLIST_RE`)
- More comprehensive coverage:
  - Added: `CODEOWNERS`, `SECURITY.md`, `WARP.md`, `.devcontainer/`
  - Proper handling of `config.yaml.example`
- More specific deprecated path detection:
  - Old `apps/argocd/` tree migration
  - Old `apps/*/helm/` wrapper roots
  - Old `apps/argocd/disabled/` location
  - Explicit `ansible/op.env` and `terraform/op.env` detection
  - Legacy `apps/(cluster|user)/secrets/` directories
- Better structured code with `die()` function
- Clearer comments and organization

### 2. Moved documentation to canonical location

- Created: `docs/path-drift-guardrail.md` (from `tools/ci/path-drift-check-v2.md`)
- Updated: `docs/layout.md` to reference new documentation location
- Updated: `docs/warp.md` to describe V2 capabilities

### 3. Updated repository structure documentation

**docs/layout.md:**

- Added missing top-level files: `CODEOWNERS`, `SECURITY.md`, `WARP.md`
- Added reference to `docs/path-drift-guardrail.md`

**docs/warp.md:**

- Expanded path-drift-check.sh description with specific deprecated path examples
- Referenced `docs/path-drift-guardrail.md` for contract

## Files to Remove (Next Cleanup)

```bash
# These files are now obsolete and can be removed:
rm tools/ci/path-drift-check-v2.sh
rm tools/ci/path-drift-check-v2.md
```

## Testing

The new script maintains backward compatibility:

- All references in `.pre-commit-config.yaml`, `mise.toml`, and `.github/workflows/ci-lint.yaml` continue to work
- Script still located at `tools/ci/path-drift-check.sh`
- Exit codes and output format unchanged

## Benefits

1. **Better Coverage**: Catches more edge cases (op.env files, old directory structures)
2. **Clearer Intent**: Specific error messages identify exact migration issues
3. **Better Documented**: Comprehensive guardrail contract in `docs/path-drift-guardrail.md`
4. **More Maintainable**: Structured code with helper functions, clearer regex patterns

## Rollback Plan

If issues arise, restore from backup:

```bash
# Backup created during migration (if needed)
git show HEAD~1:tools/ci/path-drift-check.sh > tools/ci/path-drift-check.sh
```

---

**Migration completed successfully. V2 is now the active version.**
