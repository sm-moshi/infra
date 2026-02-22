# Security Posture Status

## Snapshot Timestamp (UTC)

- Evidence snapshot anchor: `2026-02-22T23:11:26Z`
- Kubernetes context: `default`
- Note: object counts are point-in-time and can drift quickly as scan reports rotate.
- Operator scan freshness:
  - Latest `configauditreports.aquasecurity.github.io`: `2026-02-22T23:11:34Z` (`woodpecker/pod-wp-01kj3sphns8d03mxrqshzn48sb`)
  - Latest `vulnerabilityreports.aquasecurity.github.io`: `2026-02-22T11:16:14Z` (`argocd/replicaset-5fbdf8cd`)

## Evidence Sources

- Live cluster (read-only):
  - `vulnerabilityreports.aquasecurity.github.io`
  - `configauditreports.aquasecurity.github.io`
  - `clustercompliancereports.aquasecurity.github.io`
  - `networkpolicies.networking.k8s.io`
- Repository documents:
  - `/Users/smeya/git/m0sh1.cc/infra/docs/TODO.md`
  - `/Users/smeya/git/m0sh1.cc/infra/docs/checklist.md`
  - `/Users/smeya/git/m0sh1.cc/infra/docs/done.md`
- Basic Memory (project `main`):
  - `kubernetes/security-hardening-remaining-work.md`
  - `kubernetes/Security Context Hardening Patterns.md`
  - `kubernetes/Trivy Operator + ArgoCD Trivy UI Extension Plan.md`
  - `kubernetes/Network Policy Deployment - Job-CronJob Coverage.md`
  - `sessions/2026-02-22 Security Hardening Session.md`
  - `sessions/2026-02-22-cluster-network-policies-rollout.md`
  - `sessions/2026-02-22-dhi-trivy-operator-switch.md`
- Supplemental operator output (user-run):
  - `trivy kubernetes --report summary --timeout 15m --disable-node-collector` at `2026-02-22T21:27:57+01:00`

## Status Matrix

| Domain | State | Evidence |
|---|---|---|
| Security Context Hardening | `In Progress (wave mostly complete)` | Browserless-Chromium, Authentik, and Woodpecker are now reduced to image-trust (`AVD-KSV-0125`) findings in current reports. Harbor remains partially hardened with explicit read-only-root-filesystem exceptions still open. |
| Network Policy Rollout | `Done (broad rollout complete)` | `151` NetworkPolicies across `18` namespaces; default-deny present in managed namespaces (`apps`, `woodpecker`, `argocd`, `monitoring`, `cert-manager`, `cnpg-system`, `traefik`, and others). |
| Trivy Runtime Scanning | `Done (operational)` | Trivy Operator is active and continuously producing ConfigAudit reports (`373` objects at snapshot). |
| Cluster Compliance Reporting | `Blocked/Incomplete Data` | `4` ClusterComplianceReport objects exist, but all have `report_summary_present=false` and `report_checks=0`. |

## Open Findings

### 1) Security hardening findings remain active (cluster-wide)

- ConfigAudit (top failing themes observed):
  - `Restrict container images to trusted registries`: `183`
  - `Runs with GID <= 10000`: `147`
  - `Runs with UID <= 10000`: `141`
  - `CPU not limited`: `85`
  - `Memory not limited`: `79`

### 2) Vulnerability backlog remains non-zero

- Vulnerability summary at snapshot:
  - Reports: `22`
  - Critical: `15`
  - High: `42`
  - Medium: `138`
  - Low: `24`
  - Unknown: `0`

### 3) Trivy Kubernetes digest warnings in CLI runs

- Warnings seen in user-run output:
  - `unable to parse digest "" for "goharbor/registry-photon:v2.14.2"`
  - `unable to parse digest "" for "goharbor/harbor-registryctl:v2.14.2"`
- Interpretation:
  - This is a known image-reference correlation issue in `trivy kubernetes` runs for tag-only references and does not invalidate the full report execution.

### 4) Compliance framework data gap

- `k8s-cis-1.23`, `k8s-nsa-1.0`, `k8s-pss-baseline-0.1`, `k8s-pss-restricted-0.1` objects are present but currently not populated with computed report summaries/checks.

### 5) Harbor read-only root filesystem exception (Phase A)

- Harbor remains on values-only hardening in this phase.
- Global `containerSecurityContext` stays enforced, but `readOnlyRootFilesystem` is not forced cluster-wide for Harbor components yet due higher regression risk.

### 6) Workload wave delta (Harbor/Auth/Browserless/Woodpecker)

- `Authentik` (current ReplicaSet reports): only `AVD-KSV-0125` remains at medium severity.
- `Browserless-Chromium` (current ReplicaSet report): only `AVD-KSV-0125` remains at medium severity.
- `Woodpecker` (statefulset reports): only `AVD-KSV-0125` remains at medium severity.
  - Important: these report objects keep older `metadata.creationTimestamp`, but `report.updateTimestamp` is fresh (`2026-02-22`), so they are not stale scans.
- `Harbor` (current reports): `AVD-KSV-0014` (read-only root filesystem) and `AVD-KSV-0125` remain.

## Plan State

| Workstream | State |
|---|---|
| Canonical status source established | `Done` |
| Network policy baseline | `Done` |
| Trivy Operator runtime evaluation | `Done` |
| Security hardening closure for remaining workloads | `In Progress (Harbor ROFS exception + image-trust policy pending)` |
| Compliance-report completeness | `Blocked` |

## Next Actions

1. Decide and implement cluster-wide image-trust policy for `AVD-KSV-0125` (allowed registry list or documented accepted exceptions per namespace/workload).
2. Run Harbor Phase B read-only-root-filesystem experiments in staged scope only, with explicit rollback criteria.
3. Triage highest-impact vulnerability resources by `critical+high` counts and assign owners.
4. Investigate why ClusterComplianceReports are not populated, then define acceptance checks for completed framework scans.
5. Keep this file as the canonical current-state source and keep detailed execution history in diaries/session notes.

## Freshness Targets (SLA)

- Trivy ConfigAudit freshness target: latest object within `24h`.
- Trivy VulnerabilityReport freshness target: latest object within `24h` (or flag scan cadence lag).
- Canonical status review target: update after major security rollout changes or at least weekly.

## Reconciliation Checklist (Repeatable)

- [ ] Confirm kube context and capture UTC snapshot timestamp.
- [ ] Collect object counts and latest timestamps for Trivy CRDs and NetworkPolicies.
- [ ] Verify status matrix values still match live evidence.
- [ ] Confirm stale claims in planning docs are either removed or explicitly scoped.
- [ ] Update Basic Memory canonical note and mark superseded notes where needed.

## Supersedes

- `/Users/smeya/git/m0sh1.cc/infra/docs/TODO.md` sections that previously tracked completed network-policy baseline tasks.
- `/Users/smeya/git/m0sh1.cc/infra/docs/checklist.md` future-enhancement items that previously marked network-policy baseline and Trivy runtime evaluation as pending.
- Basic Memory note `kubernetes/security-hardening-remaining-work.md` lines implying system-namespace network-policy rollout is pending.

## Update: 2026-02-22T22:43:33Z — Workload Wave Comparison Published

- Added consolidated comparison report:
  - `/Users/smeya/git/m0sh1.cc/infra/docs/reports/security-hardening-wave-2026-02-22.md`
- Scope covered in report: `Harbor`, `Authentik`, `Browserless-Chromium`, `Woodpecker`.
- Key live outcomes:
  - Fresh ConfigAudit reports observed for Authentik and Browserless-Chromium.
  - Harbor shows mixed freshness (fresh ReplicaSet reports, stale older component reports).
  - Woodpecker statefulset report objects retain older creation timestamps, but `report.updateTimestamp` refreshed on `2026-02-22`, so scans are current.
  - VulnerabilityReport coverage for these four workloads is currently `0` matching objects at snapshot time (data gap explicitly called out).
- Additional runtime alignment applied in this update window:
  - Trivy Operator now includes `woodpecker: "kubernetes-dhi"` in `privateRegistryScanSecretsNames` via `/Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator/values.yaml` (commit `128c2d8c`).
