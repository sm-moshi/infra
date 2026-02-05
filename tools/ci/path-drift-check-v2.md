# Path Drift Guardrail

This document defines the **authoritative repository skeleton contract**.
It is consumed by automation (pre-commit + CI) and **must stay in sync**
with `docs/layout.md`.

If this file and `docs/layout.md` disagree, the guardrails are considered broken.

---

## Purpose

Prevent uncontrolled repository sprawl by enforcing:

- Allowed top-level directories
- Forbidden legacy paths
- Explicit, intentional changes only

This is a **hard guardrail**, not a suggestion.

---

## Allowed Top-Level Paths

The following directories are allowed at repository root:

- ansible/
- apps/
- argocd/
- cluster/
- docs/
- memory-bank/
- terraform/
- tools/
- .codex/
- .contextstream/
- .github/

The following root-level files are allowed:

- README.md
- AGENTS.md
- WARP.md
- SECURITY.md
- CODEOWNERS
- config.yaml
- mise.toml
- renovate.json
- cliff.toml
- .gitignore
- .gitattributes
- .editorconfig

Any new top-level entry MUST be added to:

1. `docs/layout.md`
2. this document
3. the allowlist in `tools/ci/path-drift-check.sh`

---

## Explicitly Forbidden Paths

The following MUST NOT exist at repository root:

- secrets/
- tooling/
- infra-root.yaml
- rendered.yaml (generated artifacts)

Historical or archived material belongs under `docs/archive/` only.

---

## Generated / Ignored Artifacts

Generated files must not be committed:

- cluster/bootstrap/**/rendered.yaml
- .rumdl_cache/
- .venv/
- .DS_Store

---

## Enforcement Rule

Any violation is considered **intentional drift** and must be resolved
before merge.

Automation failing here is working as designed.
