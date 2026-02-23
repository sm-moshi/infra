# Security Posture Status

## Snapshot Timestamp (UTC)

- Evidence snapshot anchor: `2026-02-23T00:16:02Z`
- Kubernetes context: `default`
- Note: object counts are point-in-time and can drift quickly as reports rotate.
- Evidence manifest for this run:
  - `networkpolicies.networking.k8s.io`: `151` objects across `18` namespaces
  - `configauditreports.aquasecurity.github.io`: `348` objects
  - `vulnerabilityreports.aquasecurity.github.io`: `21` objects
  - `clustercompliancereports.aquasecurity.github.io`: `4` objects
- Operator scan freshness:
  - Latest `configauditreports.aquasecurity.github.io`: `2026-02-23T00:12:46Z` (`argocd/statefulset-argocd-application-controller`)
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
| Trivy Runtime Scanning | `Done (operational)` | Trivy Operator is active and continuously producing fresh ConfigAudit reports; latest ConfigAudit update in this snapshot window is `2026-02-23T00:12:46Z`. |
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
  - Reports: `20`
  - Critical: `12`
  - High: `29`
  - Medium: `122`
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
| 1 | `kube-system` | `ReplicaSet/local-path-provisioner-6bc6568469` | 3 | 7 | 18 | 0 |
| 2 | `kured` | `DaemonSet/kured` | 3 | 7 | 18 | 0 |
| 3 | `csi-proxmox` | `ReplicaSet/proxmox-csi-plugin-controller-6cfcb65bf9` | 2 | 7 | 14 | 0 |
| 4 | `monitoring` | `StatefulSet/loki-results-cache` | 2 | 4 | 18 | 0 |
| 5 | `apps` | `ReplicaSet/forgejo-57b6c9fd87` | 2 | 0 | 1 | 1 |
| 6 | `apps` | `ReplicaSet/netbox-worker-76bbd7cf49` | 0 | 4 | 50 | 22 |

### 7) Execution status for current wave

- `argocd` completed:
  - Applied explicit pod-level security context (`runAsNonRoot` + `seccompProfile RuntimeDefault`) and CPU limits for `applicationSet` + `repoServer` in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/argocd/values.yaml`.
  - Chart bumped in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/argocd/Chart.yaml`.
  - App is `Synced/Healthy` at revision `5edc3f75b1d519f179ca3a2f7a4e3552af89aeb4`.
  - Fresh Argocd ConfigAudit reports now show `KSV118=0` and `KSV011=0` for target controllers.
- `kube-system/local-path-provisioner` blocked:
  - Deployment is owned by k3s Addon controller (`objectset.rio.cattle.io/owner-gvk: k3s.cattle.io/v1, Kind=Addon`, owner `local-storage`) and not managed by the repo wrapper chart (wrapper only defines StorageClass).
  - Changing this from Git would require taking ownership from platform-managed resources.
- `kured` blocked:
  - Current deployed image `ghcr.io/kubereboot/kured:1.21.0` matches latest stable upstream chart appVersion.
  - No newer stable semver release tag is currently available in upstream chart line to patch Go/OpenSSL CVEs without moving to unreleased commit tags or custom image build.
- `loki-results-cache` mitigation deployed:
  - Upgraded memcached image tag from `1.6.39-alpine` to `1.6.40-alpine` in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/loki/values.yaml`.
  - Chart bumped in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/loki/Chart.yaml`.
  - Loki app reconciled to `Synced/Healthy` at `b1e738a61dfe0d6c71f386ffc8cf5007a2e0c71a`.
  - Trivy Operator `VulnerabilityReport` refresh for `loki-results-cache` is still pending next scan cycle.

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
3. Decide handling path for blocked `kube-system/local-path-provisioner`: keep as k3s-managed risk acceptance vs. migrate ownership into Git (higher platform risk).
4. Decide handling path for blocked `kured`: risk acceptance until upstream release vs. custom hardened image build pipeline.
5. Execute next actionable remediation on `csi-proxmox` with an explicit compatibility decision for CSI sidecar upgrades.
6. Re-check `loki-results-cache` VulnerabilityReport after next Trivy Operator cycle to confirm the expected C/H drop.
7. Investigate why `ClusterComplianceReport` objects remain empty and define a pass/fail acceptance gate for populated summaries/checks.

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

## Update: 2026-02-23T00:21:22Z — Priority Wave Progress (Argocd Done, Next Targets Triaged)

- Completed `argocd` hardening wave and eliminated `KSV118`/`KSV011` from fresh target reports.
- Triaged `kube-system/local-path-provisioner` and marked blocked due k3s Addon ownership boundary.
- Triaged `kured` and marked blocked due lack of newer stable upstream image/chart release.
- Deployed `loki-results-cache` memcached image bump (`1.6.39-alpine` -> `1.6.40-alpine`); app is healthy, report refresh pending.

## Update: 2026-02-23T01:40:11Z — Harbor Post-Rollback ConfigAudit Refresh

- Captured fresh Harbor `ConfigAuditReport` evidence after rollback reconciliation.
- Latest Harbor-related report update timestamp: `2026-02-23T01:40:11Z` (`replicaset-harbor-core-74b6ffbc66`).
- Harbor app state remains `Synced/Healthy` in ArgoCD.
- Active Harbor workload findings remain in known-exception shape (no new regression pattern):
  - `replicaset-harbor-core-74b6ffbc66`: `H=1 M=1 L=2`
  - `replicaset-harbor-jobservice-6d59bd6d5b`: `H=1 M=1 L=2`
  - `replicaset-harbor-portal-5d4b454775`: `H=1 M=1 L=2`
  - `replicaset-harbor-registry-5494dff8fb`: `H=2 M=2 L=4`
  - `statefulset-harbor-trivy`: `H=1 M=1 L=2`
- Aggregate across core Harbor workloads: `Critical=0 High=6 Medium=6 Low=12`.
- Dominant remaining checks are unchanged:
  - `KSV014` (root filesystem not read-only)
  - `KSV0125` (trusted registry policy)
  - `KSV020` and `KSV021` (UID/GID thresholds)

## Update: 2026-02-23T01:58:02Z — CSI-Proxmox Resource Hardening Wave

- Applied `csi-proxmox` wrapper hardening in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/proxmox-csi/values.yaml`:
  - Fixed mis-keyed resource blocks (`controller.resources` -> `controller.plugin.resources`, `node.resources` -> `node.plugin.resources`).
  - Added explicit CPU/memory limits for controller sidecars (`csi-attacher`, `csi-provisioner`, `csi-resizer`, `liveness-probe`).
  - Added explicit CPU/memory limits for node sidecars (`csi-node-driver-registrar`, `liveness-probe`) and node plugin container.
- Bumped wrapper chart version in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/proxmox-csi/Chart.yaml` from `0.45.9` to `0.45.10`.
- Synced `argocd/proxmox-csi` to revision `1ce549a6c7f25c128815c3a84a6e6179e208145c`; app reached `Synced/Healthy`.
- Fresh `ConfigAuditReport` evidence (`2026-02-23T01:58:02Z`):
  - `replicaset-proxmox-csi-plugin-controller-84855d478d`: `Critical=0 High=0 Medium=0 Low=0` (controller low findings eliminated).
  - `daemonset-proxmox-csi-plugin-node`: `Critical=0 High=4 Medium=6 Low=9` (low findings reduced from `17` to `9`).
- Remaining node DaemonSet high/medium findings are structural to CSI node operation (`privileged`, `SYS_ADMIN`, `hostPath` mounts, root execution model) and require explicit exception policy or upstream chart/model redesign rather than wrapper-only value tuning.

## Update: 2026-02-23T02:05:05Z — Vaultwarden ROFS Gap Closed

- Enabled `readOnlyRootFilesystem` for Vaultwarden container in `/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml`.
- Bumped wrapper chart version in `/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/Chart.yaml` from `0.2.1` to `0.2.2`.
- Synced `argocd/vaultwarden` to revision `e7c04db599487378417d2edf276001678fe23577`; app reached `Synced/Healthy`.
- Runtime verification:
  - New pod `vaultwarden-677c7db55c-fgc25` is `Running` and ready.
  - Startup completes successfully (Rocket launched) after transient DB retry window.
- Fresh ConfigAudit evidence:
  - `replicaset-vaultwarden-677c7db55c` at `2026-02-23T02:05:05Z`
  - Summary: `Critical=0 High=0 Medium=0 Low=2`
- Result: `KSV014` (root file system not read-only) is no longer present for the active Vaultwarden ReplicaSet.

## Update: 2026-02-23T02:10:19Z — Uptime-Kuma Main Workload Hardening Completed

- Updated `/Users/smeya/git/m0sh1.cc/infra/apps/user/uptime-kuma/values.yaml`:
  - Added explicit `podSecurityContext` (`runAsNonRoot`, `runAsUser`, `runAsGroup`, `fsGroup`).
  - Hardened container `securityContext` with `runAsNonRoot`, explicit UID/GID, and `readOnlyRootFilesystem: true`.
  - Added writable `/tmp` via `additionalVolumes` + `additionalVolumeMounts` (`emptyDir`).
- Bumped `/Users/smeya/git/m0sh1.cc/infra/apps/user/uptime-kuma/Chart.yaml` from `0.8.2` to `0.8.3`.
- Synced `argocd/uptime-kuma` to revision `bbf7b407d96c57e2a48bdd1aee45435896f67e9b`; app reached `Synced/Healthy`.
- Runtime verification:
  - `uptime-kuma-0` pod is `Running`.
  - Logs confirm normal startup and DB connection (`Connected to the database`, `Listening on 3001`).
- Fresh ConfigAudit evidence (`statefulset-uptime-kuma`, `2026-02-23T02:10:19Z`):
  - Summary changed to `Critical=0 High=0 Medium=0 Low=2`.
  - `KSV118`, `KSV014`, and `KSV012` are resolved; remaining lows are `KSV020`/`KSV021` only.

## Update: 2026-02-23T02:23:33Z — Basic Memory ROFS Fix Reconciled

- Applied writable-home ROFS fix in `/Users/smeya/git/m0sh1.cc/infra/apps/user/basic-memory/templates/deployment.yaml`:
  - Added `basic-memory-home-init` initContainer to copy `config.json` from read-only ConfigMap into writable `emptyDir`.
  - Added `basic-memory-home` `emptyDir` volume.
  - Switched `/home/appuser/.basic-memory` mount in `basic-memory` container from ConfigMap volume to writable `basic-memory-home`.
- Bumped chart version in `/Users/smeya/git/m0sh1.cc/infra/apps/user/basic-memory/Chart.yaml` from `0.3.37` to `0.3.38`.
- Commit and rollout:
  - Commit: `872ce7e0e7816107d31448ff68af864ecf512e2a`
  - ArgoCD app `argocd/basic-memory` reached `Synced/Healthy` on this revision after terminating a previously stuck operation.
- Runtime verification:
  - New pod `basic-memory-548666db64-k6pll` is `Running` (`4/4` ready) with zero restarts.
  - Previous crash (`OSError: [Errno 30] Read-only file system: /home/appuser/.basic-memory/basic-memory.log`) is resolved.
- Fresh ConfigAudit evidence:
  - `replicaset-basic-memory-548666db64` at `2026-02-23T02:23:33Z`
  - Summary: `Critical=0 High=0 Medium=0 Low=14`
  - Active low findings are UID/GID policy checks (`KSV020`, `KSV021`); no remaining ROFS high finding.

## Update: 2026-02-23T02:36:29Z — Headlamp Hardening Wave Succeeded

- Repo changes:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/values.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/Chart.yaml`
- Hardening controls applied:
  - Explicit pod security context (`runAsNonRoot`, UID/GID, `seccompProfile: RuntimeDefault`).
  - Enforced `readOnlyRootFilesystem: true` for `headlamp`, `headlamp-plugin`, and `custom-plugins` init container.
  - Added writable `/tmp` via `emptyDir`.
  - Added explicit CPU/memory requests+limits for plugin sidecar and init container.
  - Removed `:latest` image tag usage for `custom-plugins` by pinning digest.
- Runtime compatibility correction:
  - Initial rollout failed due invalid package version `@headlamp-k8s/pluginctl@0.13.1`.
  - Follow-up fix restored plugin manager runtime to `@headlamp-k8s/pluginctl@latest` while keeping all hardening controls.
- Commits:
  - Hardening wave: `9293f8f6`
  - Compatibility fix: `d56641d3`
- Rollout state:
  - ArgoCD app `argocd/headlamp` synced healthy at revision `d56641d332f7c72bcd6e68c7b23e11b121881862`.
  - Pod `headlamp-9b5896677-khrmm` is `2/2` ready with `0` restarts.
- Fresh ConfigAudit evidence:
  - `replicaset-headlamp-9b5896677` at `2026-02-23T02:36:29Z`
  - Summary improved from `C0/H5/M4/L18` to `C0/H0/M0/L6`.
  - Remaining checks are only UID/GID threshold lows (`KSV020`, `KSV021`).
