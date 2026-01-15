# Infrastructure Checklist

This checklist tracks **structural milestones**, not daily ops.

---

## Phase 0 — Repository Contract

- [x] Guardrails defined (AGENTS.md, WARP.md)
- [x] Layout authoritative (docs/layout.md)
- [x] Path drift enforced (path-drift-check.sh)
- [x] Secrets strategy locked (SealedSecrets + Ansible Vault)
- [x] CI linting infrastructure (k8s-lint, ansible-idempotency, terraform-validate)
- [x] Pre-commit hooks configured (prek)
- [x] Mise task automation (cleanup, changelog, helm-lint, etc.)
- [x] Conventional commits enforced (cliff.toml)

---

## Phase 1 — Bootstrap Baseline

- [ ] ArgoCD installed via bootstrap
- [ ] cert-manager minimal prerequisites only
- [x] rendered.yaml excluded from Git
- [ ] Bootstrap documented as DR-only

---

## Phase 2 — GitOps Core

- [ ] apps-root Application live
- [ ] Cluster apps synced
- [ ] User apps synced
- [ ] Disabled apps pruned cleanly

---

## Phase 3 — Observability Reset

- [ ] Grafana removed
- [ ] Loki removed
- [ ] Alloy removed
- [ ] MinIO removed
- [ ] Leftover CRDs cleaned

Target baseline:

- Prometheus (+ Alertmanager optional)
- No logging stack unless reintroduced deliberately

---

## Phase 4 — Expansion (Optional)

- [ ] Logging (if needed)
- [ ] Object storage (if needed)
- [ ] Cost analysis (optional)

Nothing in Phase 4 is assumed.
