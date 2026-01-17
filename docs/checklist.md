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
- [ ] ~~Implement OpenCost~~
- [x] Implement HarborGuard (Progressing - DinD sidecar, CNPG integration, multi-scanner)
- [ ] Implement Kiwix Server (Docker OCI to Helm):
  - [ ] <https://github.com/kiwix/kiwix-tools/blob/main/docker/README.md>
  - [ ] <https://github.com/kiwix/kiwix-tools/pkgs/container/kiwix-tools>
  - [ ] <https://github.com/kiwix/kiwix-tools/pkgs/container/kiwix-serve>
  - [ ] <https://thehomelab.wiki/books/docker/page/setup-and-install-kiwix-serve-on-debian-systems>

**Note:** HarborGuard is deployed and syncing. Current issues to address:

- cloudnative-pg: OutOfSync (CNPG role/database changes pending)
- harborguard: Progressing (initial deployment stabilizing)
- valkey: Degraded (requires investigation)
-

Nothing in Phase 4 is assumed.

## Phase 5 - And the journey continues

- [ ] Regularly review and update infrastructure components
- [ ] Stay informed about new tools and best practices
- [x] HarborGuard: Fix 500 error - CNPG managed roles not created
  - Root cause: CNPG operator not reconciling managed roles from secrets
  - Solution: Created init-roles Job (sync-wave 11) to ensure roles exist
  - Manually created missing roles: harborguard, harbor, gitea, semaphore
  - Documented in docs/cnpg-managed-roles-issue.md
  - Automated via apps/cluster/cloudnative-pg/templates/init-roles-job.yaml
- [ ] Implement SealedSecret harbor-build-user (ns: apps) into:
  - ansible/roles/k3s_control_plane/templates/registries.yaml.j2
  - ansible/roles/k3s_worker/templates/registries.yaml.j2
