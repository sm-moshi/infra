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
- [x] Custom agent defined (m0sh1-devops with 12 toolsets)

---

## Phase 1 — Bootstrap Baseline

- [x] ArgoCD installed via bootstrap
- [x] cert-manager minimal prerequisites only
- [x] rendered.yaml excluded from Git
- [x] Bootstrap documented as DR-only

---

## Phase 2 — GitOps Core

- [x] apps-root Application live
- [x] Cluster apps synced (29 applications)
- [x] User apps synced (Harbor, HarborGuard, pgAdmin4, Uptime-Kuma, etc.)
- [x] Disabled apps pruned cleanly

---

## Phase 3 — Observability Reset

- [x] Grafana removed
- [x] Loki removed
- [x] Alloy removed
- [x] MinIO removed
- [x] Leftover CRDs cleaned
- [x] References cleaned from configs

Target baseline:

- No monitoring stack (Prometheus/Alertmanager may be reintroduced if needed)
- No logging stack unless reintroduced deliberately

---

## Phase 4 — Expansion (Optional)

- [ ] Logging (if needed)
- [ ] Object storage (if needed)
- [ ] Implement OpenCost
- [x] Implement HarborGuard (Progressing - DinD sidecar, CNPG integration, multi-scanner)

**Note:** HarborGuard is deployed and syncing. Current issues to address:

- cloudnative-pg: OutOfSync (CNPG role/database changes pending)
- harborguard: Progressing (initial deployment stabilizing)
- valkey: Degraded (requires investigation)

Nothing in Phase 4 is assumed.
