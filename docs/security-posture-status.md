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
| Cluster Compliance Reporting | `Done (operational, status-path)` | `4` ClusterComplianceReport objects have populated summaries/results in `.status.*` (not `.report.*`): `k8s-cis-1.23` (`pass=108 fail=8`), `k8s-nsa-1.0` (`pass=20 fail=7`), `k8s-pss-baseline-0.1` (`pass=11 fail=0`), `k8s-pss-restricted-0.1` (`pass=17 fail=0`), `updateTimestamp=2026-02-23T00:00:00Z`. |

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

### 5) Compliance query-path mismatch (resolved)

- `ClusterComplianceReport` data is populated in `.status.summary` and `.status.detailReport`.
- Previous canonical parsing incorrectly checked `.report.*`, causing a false "empty report" conclusion.

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
  - Migrated to Docker Hardened Images memcached `dhi.io/memcached:1.6.40-debian13` in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/loki/values.yaml` (with documented Alpine fallback tag).
  - Chart bumped in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/loki/Chart.yaml`.
  - Loki app reconciled to `Synced/Healthy` at `b1e738a61dfe0d6c71f386ffc8cf5007a2e0c71a`.
  - Trivy Operator `VulnerabilityReport` for `monitoring/loki-results-cache` has not yet materialized; coverage/path requires follow-up validation.

## Plan State

| Workstream | State |
|---|---|
| Step 1: Pre-refresh baseline captured | `Done` |
| Step 2: No-op rollout refresh triggers committed and synced (all four workloads) | `Done` |
| Step 3: Post-refresh evidence and side-effect checks captured | `Done` |
| Step 4: Canonical status reconciliation (repo + memory) | `Done` |
| Step 5: Harbor Phase B ROFS canary | `Done (failed safely, rollback reconciled)` |
| Step 6: Critical/High vulnerability ownership queue | `Done` |
| Compliance-report completeness | `Done (data present via .status)` |

## Next Actions

1. Capture next fresh Harbor ConfigAudit reports after rollback reconciliation and verify no new hardening regressions beyond known exceptions.
2. Keep Harbor on Phase A baseline and design component-scoped writable mounts before any future ROFS attempt.
3. Decide handling path for blocked `kube-system/local-path-provisioner`: keep as k3s-managed risk acceptance vs. migrate ownership into Git (higher platform risk).
4. Decide handling path for blocked `kured`: risk acceptance until upstream release vs. custom hardened image build pipeline.
5. Execute next actionable remediation on `csi-proxmox` with an explicit compatibility decision for CSI sidecar upgrades.
6. Investigate Trivy VulnerabilityReport coverage for `monitoring/loki-results-cache` (report not present after DHI memcached migration) and confirm scanner scope/eligibility.
7. Update any scripts/docs/parsers that read ClusterComplianceReport data to use `.status.summary` and `.status.detailReport` as the canonical fields.

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

## Update: 2026-02-23T02:52:26Z — NetBox/NetBox-Worker Image Digest Pin and Rollout

- Repo changes:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/Chart.yaml`
- Change details:
  - Removed duplicate `netbox.image.tag` keys in values and set a single tag (`6fcea7e5`).
  - Added immutable image pin:
    - `netbox.image.digest: sha256:a270498b476fc43fbb21964a4cacba22cdd430bcab9b15a88d7267216740c62a`
  - This digest now applies to `netbox`, `netbox-worker`, and `netbox-housekeeping` workloads via upstream chart image handling.
- Motivation/evidence:
  - Chart previously referenced `harbor.m0sh1.cc/apps/netbox:v4.5.2-plugins.3`, which is no longer present in Harbor.
  - Live worker vulnerability report was tied to stale image snapshot (`replicaset-netbox-worker-76bbd7cf49-netbox-worker`, `C0/H4/M50/L22`, timestamp `2026-02-22T10:03:44Z`).
  - Direct image scan of new tag (`harbor.m0sh1.cc/apps/netbox:6fcea7e5`) returned `C0/H0` at scan time.
- Commits:
  - Image pin rollout: `f17d143c`
- Rollout state:
  - ArgoCD app `argocd/netbox` synced healthy at revision `f17d143ce6a6b46927d02b8f2b1560b5954de68a`.
  - New pods running:
    - `netbox-7f9c99fffd-26f5s` (`1/1`)
    - `netbox-worker-7788b7cdf4-gtksg` (`1/1`)
  - Both deployments now run the pinned digest image.
- Fresh ConfigAudit evidence:
  - `replicaset-netbox-7f9c99fffd` at `2026-02-23T02:49:06Z`: `C0/H0/M0/L4`
  - `replicaset-netbox-worker-7788b7cdf4` at `2026-02-23T02:49:06Z`: `C0/H0/M0/L8`
  - No high/medium config findings introduced by this rollout.

## Update: 2026-02-23T03:04:53Z — PgAdmin4 Hardening Compatibility Test and Compliance Schema Correction

- PgAdmin4 compatibility test (`argocd/pgadmin4`):
  - Attempted container-level hardening (`readOnlyRootFilesystem`, strict non-root container fields, dropped capabilities) in commit `60514cdb`.
  - Rollout failed with runtime startup errors:
    - `/entrypoint.sh: /pgadmin4/config_distro.py: Read-only file system`
    - `sudo: ... no new privileges ...`
    - `/venv/bin/python3: Operation not permitted`
  - Applied staged rollback/fix commits (`7a005133`, `5bbb1275`, `81eff8c0`) and restored the proven-compatible security posture.
  - Final state: `argocd/pgadmin4` is `Synced/Healthy`, pod `pgadmin4-v5-58cbc48547-mvk6m` is running.
  - Fresh ConfigAudit for `replicaset-pgadmin4-v5-58cbc48547` remains `C0/H1/M2/L5` (no score regression).

- Cluster compliance schema correction:
  - `ClusterComplianceReport` objects are populated in `.status` (not `.report`).
  - Live summaries at `2026-02-23T00:00:00Z`:
    - `k8s-cis-1.23`: `pass=108 fail=8`
    - `k8s-nsa-1.0`: `pass=20 fail=7`
    - `k8s-pss-baseline-0.1`: `pass=11 fail=0`
    - `k8s-pss-restricted-0.1`: `pass=17 fail=0`
  - Canonical status and next actions were updated to use `.status.summary` and `.status.detailReport` as source-of-truth fields.

- Loki vulnerability coverage note:
  - After DHI memcached migration in `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/loki/values.yaml`, `VulnerabilityReport` entries for `monitoring/loki-results-cache` were still absent at this check.
  - Follow-up remains open to validate scanner scope/eligibility and report generation path for this workload.

## Update: 2026-02-23T03:22:01Z — Trivy Vulnerability Report Regeneration Attempt (Partial, Blocked)

- Implemented Trivy operator hardening/fix wave:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator/values.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator/Chart.yaml`
  - Commits:
    - `e81eee02` (`vulnerabilityScannerScanOnlyCurrentRevisions=false`, namespace secret map cleanup)
    - `f6af34f2` (`accessGlobalSecretsAndServiceAccount=true` for private-registry scan jobs)
- Trivy operator app reconciled healthy after both changes:
  - `argocd/trivy-operator` `Synced/Healthy` at revision `f6af34f2382e2b4e03b31b02bc4999338f4fa8be`.
  - ConfigMap confirms:
    - `OPERATOR_VULNERABILITY_SCANNER_SCAN_ONLY_CURRENT_REVISIONS=false`
    - `OPERATOR_ACCESS_GLOBAL_SECRETS_SERVICE_ACCOUNTS=true`
- Forced two no-op GitOps rollouts for `loki-results-cache` to emit fresh workload events:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/loki/values.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/loki/Chart.yaml`
  - Commits:
    - `b4775fe6` (`trivy-refresh-rev: 20260223-1`)
    - `66f6d360` (`trivy-refresh-rev: 20260223-2`)
  - `argocd/loki` remained `Synced/Healthy`; `loki-results-cache-0` rolled successfully each time.
- Result:
  - `VulnerabilityReport` count remains `8` cluster-wide (unchanged).
  - No `monitoring/loki-results-cache` vulnerability report appeared after rollouts.
  - No active Trivy scan Jobs observed in cluster Job listings during verification windows.
- Current interpretation:
  - This is now a confirmed Trivy vulnerability-report generation path blocker, not a Loki rollout issue.
  - Next step should be targeted operator deep-diagnosis (controller debug level and/or upstream chart/operator version jump) rather than further workload churn.

## Update: 2026-02-23T04:57:08Z — Trivy Scan Path Recovery (Client-Server + NetworkPolicy)

- Repo changes applied:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator/values.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator/Chart.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/network-policies/templates/allow-trivy-server.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/network-policies/Chart.yaml`
- Commits in this recovery wave:
  - `55b754b9` — restored `operator.builtInTrivyServer=true` (ClientServer mode)
  - `d32a276a` — forced operator reconcile trigger (`trivy-config-rev`)
  - `31221ba8` — relaxed Trivy server ingress policy on TCP `4954` to avoid selector/DNAT edge-case refusals
  - `d91b792b` — forced second reconcile trigger after policy update

- Live verification:
  - ArgoCD apps:
    - `argocd/trivy-operator` synced to `d91b792be1cf31060d75f0756a5db5cb71d96e60` and healthy.
    - `argocd/network-policies` synced to `31221ba81ed9ab1f8608b8d233e51cee8ff3a82e` and healthy.
  - `trivy-server` is running and ready (`apps/trivy-server-0`), `trivy-service` has active endpoint `10.42.9.104:4954`.
  - Two fresh scan jobs completed successfully:
    - `scan-vulnerabilityreport-7488fc5674-ztsb9` (`Complete`)
    - `scan-vulnerabilityreport-55d94f7694-l9jfj` (`Complete`)
  - No fresh `cache may be in use` or `connect: connection refused` errors were observed in these completed job logs.

- Freshness/capacity snapshot for this run:
  - `networkpolicies.networking.k8s.io`: `152`
  - `configauditreports.aquasecurity.github.io`: `379`
  - `vulnerabilityreports.aquasecurity.github.io`: `8`
  - `clustercompliancereports.aquasecurity.github.io`: `4`
  - Latest `ConfigAuditReport`: `2026-02-23T04:57:07Z` (`apps/replicaset-harbor-registry-6fd7876fcc`)
  - Latest `VulnerabilityReport`: `2026-02-23T04:57:08Z` (`origin-ca-issuer/replicaset-origin-ca-issuer-5748857f68-origin-ca-issuer`)

- Current interpretation:
  - Trivy runtime scan execution path is recovered (jobs run and complete).
  - Vulnerability-report coverage is still low (`8` reports), so backlog/coverage expansion remains open and should be treated as `In Progress` rather than fully done.
