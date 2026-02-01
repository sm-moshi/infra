# Supply Chain Rules (m0sh1.cc)

## Table of Contents

1. Pinning Policy
2. Image Rebuilds
3. Scan Exceptions
4. Documentation

## 1. Pinning Policy

- Pin actions and container images by digest where feasible.
- If a tag is used temporarily, document it in `docs/history.md`.

## 2. Image Rebuilds

- Rebuild images to pick up base CVE fixes.
- Do not waive critical findings without a note in `docs/history.md`.

## 3. Scan Exceptions

- Harbor scan exceptions must include rationale and expiry.

## 4. Documentation

- Record temporary tag usage, recovery actions, and exceptions in `docs/history.md`.

## 5. Automated Enforcement (supply_chain_guard.py)

The `tools/m0sh1-devops/scripts/supply_chain_guard.py` script enforces supply chain security policies:

### What It Checks

- **GitHub Actions**: Workflows must pin actions to full SHA (40 hex chars) instead of tags
- **Dockerfiles**: Base images must use `@sha256:` digest pinning
- **Helm values.yaml**: Images must be pinned by digest, not tags
- **Latest tags**: Using `latest` tag is an **error** (not just warning)
- **Documentation**: Warns if `docs/history.md` is missing

### Implementation (2026-02-01 Upgrade)

**YAML Parsing:**

- Uses proper `yaml.safe_load()` with recursive tree traversal (preferred)
- Handles nested structures, lists, YAML anchors/aliases correctly
- Falls back to regex-based parsing if PyYAML unavailable
- Provides detailed path context in error messages (e.g., "at .image.repository")

**Latest Tag Detection:**

- `tag: "latest"` or empty tags reported as **errors**
- Non-digest tags (without `@sha256:`) reported as **warnings**

**Usage:**

```bash
# Run checks with JSON output
python tools/m0sh1-devops/scripts/supply_chain_guard.py --repo . --json

# Strict mode (fail on any warnings)
python tools/m0sh1-devops/scripts/supply_chain_guard.py --repo . --strict
```

**Exit Codes:**

- `0`: All checks passed
- `1`: Issues found (in strict mode)
- `2`: Usage error (bad arguments)
