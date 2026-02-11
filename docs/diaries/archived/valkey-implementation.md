# Valkey Implementation (Diary)

## Document Information

- Author: m0sh1-devops agent (regenerated)
- Date: 2026-02-06
- Last Updated: 2026-02-09
- Status: Deployed (GitOps via ArgoCD); DHI migration: implemented in Git (awaiting reconciliation)

## Scope

This diary documents the current Valkey deployment in the cluster and the wrapper-chart configuration in Git.

Hard rules:

- GitOps only: do not mutate the cluster imperatively. Changes flow Git -> ArgoCD -> cluster.
- No secrets in Git: credentials must be SealedSecrets (or Vault on the host side).

## Current State (Verified 2026-02-06)

ArgoCD:

- Application: `argocd/valkey`
- Health: `Healthy`
- Sync: `Synced`
- Sync wave: `30`
- Sync policy: automated (`prune: true`, `selfHeal: true`)

Kubernetes objects in namespace `apps`:

- Deployment: `apps/valkey` (1 replica)
- Pod: 1 running
- Service: `apps/valkey` (ClusterIP, port 6379)
- PVC: `apps/valkey` (10Gi, storageClass `proxmox-csi-zfs-nvme-fast-retain`)
- PDB: `apps/valkey-pdb` (`minAvailable: 1`, so `disruptionsAllowed: 0` with 1 replica)
- ConfigMap: `apps/valkey-init-scripts` (init script generates `/data/conf/valkey.conf`)

## Wrapper Chart (Git)

Path: `apps/cluster/valkey/`

`apps/cluster/valkey/Chart.yaml`:

- Wrapper chart version: `0.3.0`
- appVersion: `9.0.2`
- Dependency: DHI `valkey-chart` `0.9.3` from `oci://harbor.m0sh1.cc/dhi` (pinned via `Chart.lock`)

`apps/cluster/valkey/values.yaml` (high level):

- Image: `harbor.m0sh1.cc/dhi/valkey:9.0.2-debian13@sha256:710eea60444b4510b7eaac7c5d25e2d1cafb985aa0542f2f8ed2a323a6b94497`
- Pull secret: `global.imagePullSecrets: [kubernetes-dhi]`
- Auth: `valkey.auth.enabled: false` (currently unauthenticated)
- Replication: disabled (`valkey.replica.enabled: false`)
- Strategy: `Recreate` (avoids multi-attach issues with RWO PVC)
- Storage: `dataStorage` enabled, `10Gi`, class `proxmox-csi-zfs-nvme-fast-retain`
- Resources: requests `200m/256Mi`, limits `1 CPU / 1Gi`
- PDB: enabled, `minAvailable: 1`

`apps/cluster/valkey/templates/pdb.yaml`:

- Creates a PDB named `<release>-pdb` when `valkey.pdb.enabled` is true.

## Configuration Notes

Generated config (from `ConfigMap/apps/valkey-init-scripts`):

- `protected-mode no`
- `bind * -::*`
- `dir /data`

This is intentionally permissive for in-cluster connectivity. If we keep `auth.enabled: false`, access control must come from network policy / namespace boundaries.

## Read-Only Validation Commands

```bash
kubectl get application -n argocd valkey
kubectl get deploy -n apps valkey
kubectl get pod -n apps -l app.kubernetes.io/name=valkey
kubectl get svc -n apps valkey
kubectl get endpoints -n apps valkey
kubectl get pvc -n apps valkey
kubectl get pdb -n apps valkey-pdb
kubectl get configmap -n apps valkey-init-scripts
kubectl logs -n apps -l app.kubernetes.io/name=valkey --tail=200
```

## Operational Characteristics

Availability:

- Single replica + `Recreate` strategy means rollouts are a brief hard restart.
- PDB `minAvailable: 1` with a single replica blocks voluntary disruptions (expected). If node draining is needed, temporarily relaxing the PDB must be done via Git.

Persistence:

- PVC is `ReadWriteOnce`. The `Recreate` strategy avoids multi-attach issues.

Security posture (current):

- Workload runs as non-root (`runAsNonRoot: true`, `runAsUser: 1000`), drops all Linux capabilities, and uses `readOnlyRootFilesystem: true`.
- ServiceAccount token automount is disabled (`automountServiceAccountToken: false`).
- Auth is disabled in Valkey, and the generated config disables protected-mode and binds to all interfaces.

Implication: with auth disabled, assume anything that can reach `valkey.apps.svc.cluster.local:6379` can read/write.

## Recommendations (Near-Term)

1. NetworkPolicy

- If we keep auth disabled, add a NetworkPolicy allowing ingress only from known client pods/namespaces.
- If we enable auth later, keep NetworkPolicy anyway as a defense-in-depth layer.

2. Auth and ACL users

- There is already a `Secret/apps/valkey-users` containing per-app passwords/usernames, but the Valkey deployment is currently unauthenticated (`valkey.auth.enabled: false`) and does not appear to load any ACL config from that secret.
- Enabling ACLs will require wiring an ACL file/users into the upstream chart (or wrapper templates), and then updating client apps to use authenticated Redis URLs (or username/password fields) consistently.

3. Probes without shell

- Current probes are `exec: ["sh", "-c", "valkey-cli ping"]`.
- If we move to images that truly ship without a shell, switch probes to a direct exec command (if supported by the chart) or a `tcpSocket` probe.

## DHI Migration + 9.0.2 Update Runbook (Step-by-Step)

Context: Renovate PR `8ebd9ee70cecb169ea48dafe0daa237a1fa3c4b2` proposes bumping the current image from `9.0.1-alpine3.23` to `9.0.2-alpine3.23`. Instead of doing another Alpine/musl bump for a networked shared service, we should migrate Valkey to DHI (glibc-based Debian 13) while landing `9.0.2`.

### Expected Impact

- Downtime: brief hard restart (single replica + `Recreate`).
- Risk: low-to-medium (patch release, but base image change + chart dependency swap).
- Rollback: git revert (PVC remains intact).

### What We Are Changing

- Workload version: `9.0.1-*` -> `9.0.2-*` (patch upgrade).
- Base image: Alpine/musl -> Debian 13/glibc (DHI).
- Optional: chart dependency from upstream `valkey` -> DHI `valkey-chart` (same templates at `0.9.3`, but DHI default image pinning by digest).

### Target State (After Migration)

- Wrapper chart:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey/Chart.yaml`:
    - `appVersion: "9.0.2"`
    - dependency: `valkey-chart` `0.9.3` from `oci://harbor.m0sh1.cc/dhi` with `alias: valkey`
    - wrapper chart version bumped (recommended: `0.3.0`)
- Runtime image:
  - `harbor.m0sh1.cc/dhi/valkey:9.0.2-debian13@sha256:710eea60444b4510b7eaac7c5d25e2d1cafb985aa0542f2f8ed2a323a6b94497`
- Pull auth:
  - `valkey.global.imagePullSecrets: [kubernetes-dhi]` (or `valkey.imagePullSecrets: [kubernetes-dhi]`)
- No behavioral changes:
  - `auth.enabled: false`, `replica.enabled: false`, `deploymentStrategy: Recreate`, persistence unchanged.

### Breaking-Change Check (Valkey 9.0.2)

No explicit breaking changes are called out in the `9.0.2` release notes (patch release). Notable fixes include hash-field expiration command behavior fixes (HEXPIRE/H*EXPIRE*) and AOF/replication stability fixes. If any app depends on the older buggy behavior of the hash expiration feature set, validate that path explicitly before rollout.

### Argo CD + OCI Helm Charts (Practical Guidance for This Repo)

This Application is sourced from Git (`argocd/apps/cluster/valkey.yaml` points at `apps/cluster/valkey`), but it still uses Helm chart dependencies that are fetched at render time.

Repo policy note: `apps/**/charts/` is `.gitignore`'d (except for a few special cases like Semaphore), so dependencies are not committed. Argo CD (repo-server) must be able to run `helm dependency build` and fetch the dependency from the configured repository (`oci://harbor.m0sh1.cc/dhi`).

If Harbor's OCI registry requires authentication for chart pulls, add an Argo CD repository Secret (SealedSecret) of `type: helm` with `enableOCI: "true"` and credentials for `harbor.m0sh1.cc`. If Harbor is public for the chart project, no extra Argo CD repo credentials are required.

### Recommended Implementation Path (One PR)

This path upgrades to `9.0.2` and migrates to DHI while minimizing moving parts.

1. Preflight (read-only)

   - Confirm Valkey is healthy/synced and note the current Pod name for reference.
   - Identify whether AOF is enabled in your config (it is not enabled by default by the upstream chart; only relevant if you added it via `valkeyConfig`).
   - Scan consumers for hash-field expiration usage (only relevant if you adopted the new HEXPIRE/HSETEX family).

2. Update wrapper chart metadata (Git only)

   - Bump `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey/Chart.yaml`:
     - `appVersion: \"9.0.2\"`
     - wrapper chart `version`: bump (recommended: `0.3.0`).

3. Switch to DHI chart dependency (optional but recommended)

   - In `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey/Chart.yaml`, swap the dependency:
     - from: `name: valkey` + `repository: https://valkey.io/valkey-helm/`
     - to: `name: valkey-chart` + `repository: oci://harbor.m0sh1.cc/dhi` + `alias: valkey`
   - Regenerate `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey/Chart.lock` so the dependency is pinned in Git:
     - `helm dependency update /Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey`
   - Optional local check:
     - `helm dependency build /Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey` (verifies the chart can be pulled from Harbor OCI)

   Why `alias: valkey` matters:

   - Our wrapper values are rooted at `valkey:` and our wrapper PDB selects `app.kubernetes.io/name: valkey`.
   - With `alias: valkey`, the dependency keeps both the values root and label selectors stable.

4. Update values to use DHI Valkey via Harbor mirror (Git only)

   In `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey/values.yaml`:

   - Replace image:
     - `valkey.image.registry: harbor.m0sh1.cc`
     - `valkey.image.repository: dhi/valkey`
     - `valkey.image.tag: 9.0.2-debian13@sha256:710eea60444b4510b7eaac7c5d25e2d1cafb985aa0542f2f8ed2a323a6b94497`
   - Ensure pull secret is set (prefer global since there may be multiple images later):
     - `valkey.global.imagePullSecrets: [kubernetes-dhi]`
     - or `valkey.imagePullSecrets: [kubernetes-dhi]`
   - Keep behavior the same:
     - `valkey.auth.enabled: false`
     - `valkey.replica.enabled: false`
     - `valkey.dataStorage.enabled: true`
     - `valkey.deploymentStrategy: Recreate`

   Optional (separate follow-up PR recommended): enable exporter + ServiceMonitor after the core migration is stable.

5. Local render validation (no cluster writes)

   - `helm lint /Users/smeya/git/m0sh1.cc/infra/apps/cluster/valkey`
   - Run repo guard checks if available:
     - `mise run pre-commit-run`
     - `mise run k8s-lint`
   - Render before/after and diff:
     - Service stays `valkey` in namespace `apps`
     - PVC name/mount stays consistent (`/data`)
     - Deployment strategy stays `Recreate`
     - PDB selector still matches pod labels

6. GitOps rollout (reconciliation only)

   - Merge the PR to `main`.
   - Observe rollout via Argo CD (no `--prune`, no `--force`):
     - `argocd app diff valkey`
     - `argocd app sync valkey`
     - `argocd app wait valkey`

7. Post-rollout verification (read-only)

   - Confirm the image is the expected `harbor.m0sh1.cc/dhi/valkey:9.0.2-debian13@sha256:...`.
   - Confirm Valkey responds to `PING` via logs/health (and consumers remain healthy).
   - Check Harbor and NetBox logs for Redis/Valkey errors during the restart window.

8. Rollback plan (Git only)

   - Revert the PR (or revert the commit(s) that switched chart/image).
   - Argo CD reconciles back; PVC remains intact.

### DHI References

- DHI Valkey image catalog: <https://hub.docker.com/hardened-images/catalog/dhi/valkey>
- DHI Valkey guides: <https://hub.docker.com/hardened-images/catalog/dhi/valkey/guides>
- DHI Valkey chart guides: <https://hub.docker.com/hardened-images/catalog/dhi/valkey-chart/guides>
- DHI Redis Exporter catalog: <https://hub.docker.com/hardened-images/catalog/dhi/redis-exporter>

## Change Log

- 2026-02-06: Regenerated this diary after accidental deletion. Content reflects live cluster state and current Git configuration.
- 2026-02-06: Added a wiring audit of current Valkey consumers (Git and live cluster).
- 2026-02-08: Added a concrete migration plan for moving from upstream Valkey Alpine tags to DHI Valkey `9.0.2-debian13`, including feasibility notes for the DHI `valkey-chart` OCI Helm chart.
- 2026-02-09: Implemented the DHI migration in Git (wrapper chart now depends on vendored DHI `valkey-chart` and uses DHI Valkey `9.0.2-debian13` by digest).

## Consumer Wiring Audit (Verified 2026-02-06)

This section answers: which apps are actually wired to `valkey.apps.svc.cluster.local:6379`, and is that wiring compatible with the current Valkey auth mode (`auth.enabled: false`)?

Notes:

- “Wired” here means “the app config points at the shared Valkey service”.
- This does not attempt to prove every runtime code path is exercised, but it uses live ConfigMaps/Secrets where available.

Consumers in namespace `apps`:

- **NetBox** (deployed)
  - Live config: `ConfigMap/apps/netbox` sets:
    - `REDIS.tasks`: host `valkey.apps.svc.cluster.local`, db `0`
    - `REDIS.caching`: host `valkey.apps.svc.cluster.local`, db `1`
  - Auth: username empty; password read from `Secret/apps/netbox-kv` (expected to be unset/empty while Valkey is unauthenticated).
  - Status: NetBox pods are running; no Redis errors observed in recent NetBox logs.

- **Harbor** (deployed)
  - Live config: `ConfigMap/apps/harbor-core` sets:
    - `_REDIS_URL_CORE`: `redis://valkey.apps.svc.cluster.local:6379/0?...`
    - `_REDIS_URL_REG`: `redis://valkey.apps.svc.cluster.local:6379/2?...`
  - Live config: `ConfigMap/apps/harbor-jobservice` sets:
    - `redis_url: redis://valkey.apps.svc.cluster.local:6379/1`
  - Auth: the URLs are unauthenticated (no username/password), which matches current Valkey mode.
  - Git note: `apps/user/harbor/values.yaml` includes `redis.external.existingKey: harbor-valkey`, but the deployed Harbor manifests are clearly using unauthenticated Redis URLs from ConfigMaps. If/when we move to authenticated Valkey, this mismatch should be reconciled in Git (the helper override template looks for `existingSecret`, not `existingKey`).

- **Gitea** (not deployed)
  - Live secret exists: `Secret/apps/gitea-redis` contains session/cache/queue Redis URLs that include a username/password and target:
    - `/0` (session), `/1` (cache), `/2` (queue)
  - Auth: this implies Gitea will attempt `AUTH` (or ACL auth), which is incompatible with the current Valkey configuration (`auth.enabled: false`).
  - Status: no `Deployment/apps/gitea` present at time of check, so this is a “config would fail if deployed” finding.

Non-consumers worth calling out:

- **Authentik** (deployed): does not appear to use Valkey/Redis; its worker logs show a Postgres-backed scheduler (`django_dramatiq_postgres.scheduler`) and there is no Redis/Valkey endpoint configured in its Pod spec.

## Database Allocation Strategy (Actual + Policy)

Valkey provides logical databases 0-15. This deployment is a shared service, so we need conventions.

Actual usage (verified from live configs on 2026-02-06):

- DB 0: NetBox tasks; Harbor core (`_REDIS_URL_CORE`)
- DB 1: NetBox caching; Harbor jobservice
- DB 2: Harbor registry cache (`_REDIS_URL_REG`); Gitea queue (planned via `Secret/apps/gitea-redis`)

Implication:

- Multiple apps share DBs today, which increases the risk of accidental key collisions and cross-app visibility (especially while Valkey auth is disabled).

Recommended policy map (proposal; adjust as you add consumers):

- DB 0-2: reserved for system/bootstrap/testing (or keep as-is until cutover)
- DB 3: Harbor core
- DB 4: Harbor jobservice
- DB 5: Harbor registry cache
- DB 6: NetBox tasks
- DB 7: NetBox caching
- DB 8: Gitea session
- DB 9: Gitea cache
- DB 10: Gitea queue
- DB 11-15: reserved

Notes:

- While `valkey.auth.enabled: false`, database separation is the only isolation mechanism Valkey provides. Any client that can connect can access any DB.
- When ACL auth is enabled later, consider whether to restrict users to selected DBs (if the chosen ACL approach supports it).

Connection string patterns (application dependent):

- Redis URL style: `redis://<host>:6379/<db>`
- Valkey URL style (some clients): `valkey://<host>:6379/<db>`

## Replication (Future)

Current state:

- Single instance (no replication).

Repo already contains replication-related values under `valkey.replica.*`, but `valkey.replica.enabled: false`.

If/when enabling replication, re-evaluate:

- Scheduling: keep anti-affinity / topology spread so primary and replica do not land on the same node.
- Storage: replicas with persistence will need additional PVC(s) and may increase storage cost.
- Write semantics: `minReplicasToWrite` and `minReplicasMaxLag` trade availability vs durability.

## Monitoring (Minimal)

This chart does not currently deploy a Valkey exporter.

Basic checks:

```bash
kubectl logs -n apps -l app.kubernetes.io/name=valkey --tail=200
kubectl get pod -n apps -l app.kubernetes.io/name=valkey -o wide
```

PVC usage (if kubelet volume metrics are available in Prometheus):

```promql
kubelet_volume_stats_used_bytes{namespace="apps",persistentvolumeclaim="valkey"}
/ kubelet_volume_stats_capacity_bytes{namespace="apps",persistentvolumeclaim="valkey"}
* 100
```

## Troubleshooting (Read-Only)

1. Image pull failures

- Confirm the secret exists: `kubectl get secret -n apps kubernetes-dhi`
- Confirm the pod spec includes `imagePullSecrets` when using `dhi.io/*` images.

2. Pod stuck Pending

- Check PVC and storage class binding: `kubectl get pvc -n apps valkey`
- Check pod events: `kubectl describe pod -n apps -l app.kubernetes.io/name=valkey`

3. Cannot connect

- Confirm endpoints: `kubectl get endpoints -n apps valkey`
- Confirm service port: `kubectl get svc -n apps valkey`
