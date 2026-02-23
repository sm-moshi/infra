# Security Posture Status

## Snapshot Timestamp (UTC)

- Evidence snapshot anchor: `2026-02-22T23:59:45Z`
- Kubernetes context: `default`
- Note: object counts are point-in-time and can drift quickly as reports rotate.
- Evidence manifest for this run:
  - `networkpolicies.networking.k8s.io`: `151` objects across `18` namespaces
  - `configauditreports.aquasecurity.github.io`: `348` objects
  - `vulnerabilityreports.aquasecurity.github.io`: `21` objects
  - `clustercompliancereports.aquasecurity.github.io`: `4` objects
- Operator scan freshness:
  - Latest `configauditreports.aquasecurity.github.io`: `2026-02-22T23:59:40Z` (`apps/job-renovate-sm-moshi-infra-1963556b2cmrv`)
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
  - `/Users/smeya/git/m0sh1.cc/infra/docs/security-posture-status.md`
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
| Security Context Hardening | `In Progress (wave mostly complete)` | `Browserless-Chromium`, `Woodpecker`, and `Authentik` target reports now show only low findings (`KSV020`, `KSV021`) in latest refreshed reports. `Harbor` Phase B global `readOnlyRootFilesystem=true` canary failed at runtime, was rolled back in Git (`ed63e0e3`), and is now reconciled as `Synced/Healthy` in ArgoCD. |
| Network Policy Rollout | `Done (broad rollout complete)` | `151` NetworkPolicies across `18` namespaces with default-deny present in managed namespaces (`apps`, `woodpecker`, `argocd`, `monitoring`, `cert-manager`, `cnpg-system`, `traefik`, and others). |
| Trivy Runtime Scanning | `Done (operational)` | Trivy Operator is active and continuously producing fresh ConfigAudit reports; latest ConfigAudit update in this snapshot window is `2026-02-22T23:47:31Z`. |
| Cluster Compliance Reporting | `Blocked/Incomplete Data` | `4` ClusterComplianceReport objects exist, each with empty summary and `0` checks (`k8s-cis-1.23`, `k8s-nsa-1.0`, `k8s-pss-baseline-0.1`, `k8s-pss-restricted-0.1`). |

## Open Findings

### 1) ConfigAudit findings remain active

- Current top failing checks in this snapshot window:
  - `Runs with GID <= 10000`: `37`
  - `Runs with UID <= 10000`: `37`
  - `Root file system is not read-only`: `35`
  - `Restrict container images to trusted registries`: `6`

### 2) Vulnerability backlog remains non-zero

- Vulnerability summary at snapshot:
  - Reports: `21`
  - Critical: `15`
  - High: `42`
  - Medium: `138`
  - Low: `24`
  - Unknown: `0`

### 3) Harbor Phase B ROFS canary failed (runtime regression confirmed)

- Observed startup failures after enabling global Harbor `readOnlyRootFilesystem=true`:
  - `cp: /harbor/ca-bundle.crt.original: Read-only file system`
  - `cp: /home/harbor/ca-bundle.crt.original: Read-only file system`
  - `cp: /home/scanner/ca-bundle.crt.original: Read-only file system`
  - `nginx: mkdir() "/tmp/client_body_temp" failed (30: Read-only file system)`
- Rollback status:
  - Git rollback committed and pushed: `ed63e0e3`
  - ArgoCD reconciliation completed: Harbor app is now `Synced/Healthy` at revision `528e7713ce059c9a32ec3df066137765751ff53d`.

### 4) Trivy Kubernetes digest warnings in CLI runs

- Warnings seen in user-run output:
  - `unable to parse digest "" for "goharbor/registry-photon:v2.14.2"`
  - `unable to parse digest "" for "goharbor/harbor-registryctl:v2.14.2"`
- Interpretation:
  - Known image-reference correlation limitation for some tag-only references; does not invalidate overall report completion.

### 5) Compliance framework data gap remains

- `ClusterComplianceReport` objects are present but still not populated with report summaries/check results.

### 6) Critical/High prioritization queue (Step 6)

| Priority | Namespace | Resource | Critical | High | Medium | Low |
|---|---|---|---:|---:|---:|---:|
| 1 | `argocd` | `ReplicaSet/argocd-applicationset-controller-79fd476d47` | 3 | 13 | 16 | 0 |
| 2 | `kube-system` | `ReplicaSet/local-path-provisioner-6bc6568469` | 3 | 7 | 18 | 0 |
| 3 | `kured` | `DaemonSet/kured` | 3 | 7 | 18 | 0 |
| 4 | `csi-proxmox` | `ReplicaSet/proxmox-csi-plugin-controller-6cfcb65bf9` | 2 | 7 | 14 | 0 |
| 5 | `monitoring` | `StatefulSet/loki-results-cache` | 2 | 4 | 18 | 0 |
| 6 | `apps` | `ReplicaSet/forgejo-57b6c9fd87` | 2 | 0 | 1 | 1 |
| 7 | `apps` | `ReplicaSet/netbox-worker-76bbd7cf49` | 0 | 4 | 50 | 22 |

## Plan State

| Workstream | State |
|---|---|
| Step 1: Pre-refresh baseline captured | `Done` |
| Step 2: No-op rollout refresh triggers committed and synced (all four workloads) | `Done` |
| Step 3: Post-refresh evidence and side-effect checks captured | `Done` |
| Step 4: Canonical status reconciliation (repo + memory) | `Done` |
| Step 5: Harbor Phase B ROFS canary | `Done (failed safely, rollback reconciled)` |
| Step 6: Critical/High vulnerability ownership queue | `Done` |
| Compliance-report completeness | `Blocked` |

## Next Actions

1. Capture next fresh Harbor ConfigAudit reports after rollback reconciliation and verify no new hardening regressions beyond known exceptions.
2. Keep Harbor on Phase A baseline and design component-scoped writable mounts before any future ROFS attempt.
3. Execute remediation wave for queue priorities 1-4 (`argocd`, `kube-system`, `kured`, `csi-proxmox`) with owner assignment and target dates.
4. Investigate why `ClusterComplianceReport` objects remain empty and define a pass/fail acceptance gate for populated summaries/checks.

## Freshness Targets (SLA)

- Trivy ConfigAudit freshness target: latest report within `24h`.
- Trivy VulnerabilityReport freshness target: latest report within `24h` (or flag scan cadence lag).
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

## Update: 2026-02-22T23:47:48Z — Harbor Canary Rollback and Priority Queue

- Confirmed Harbor global ROFS canary regression through pod logs across `core`, `jobservice`, `portal`, `registry`, and `trivy`.
- Rolled Harbor `readOnlyRootFilesystem` back to `false` in `/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/values.yaml` and bumped `/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/Chart.yaml` to `0.9.6` (commit `ed63e0e3`).
- Refreshed canonical posture metrics and published a critical/high vulnerability queue for next remediation wave.

## Update: 2026-02-22T23:59:45Z — Harbor Rollback Fully Reconciled

- Harbor ArgoCD app reached `Synced/Healthy` after rollback reconciliation (revision `528e7713ce059c9a32ec3df066137765751ff53d`).
- Post-rollback runtime checks are green for `harbor-core`, `harbor-jobservice`, `harbor-portal`, `harbor-registry`, and `harbor-trivy`.
- No recurring ROFS startup errors are present in current component logs.
