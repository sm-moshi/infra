# Valkey Implementation (Diary)

## Document Information

- Author: m0sh1-devops agent (regenerated)
- Date: 2026-02-06
- Status: Deployed (GitOps via ArgoCD); DHI migration: not started

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

- Wrapper chart version: `0.2.1`
- appVersion: `9.0.1`
- Upstream dependency: `valkey` chart `0.9.3` from `https://valkey.io/valkey-helm`

`apps/cluster/valkey/values.yaml` (high level):

- Image: `docker.io/valkey/valkey:9.0.1-alpine3.23`
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

## Docker Hardened Images (DHI) Migration

Target image:

- `dhi.io/valkey:9.0.2-debian13`

DHI highlights:

- Runtime image runs as `nonroot` by default (`uid/gid 65532`).
- Includes Valkey tools (`valkey-server`, `valkey-cli`, `valkey-benchmark`, `valkey-check-aof`, `valkey-check-rdb`) and Redis-compat symlinks.
- Entry point uses `tini` and a small entrypoint script.

Pre-req: registry auth

- The reflected pull secret `Secret/apps/kubernetes-dhi` exists in-cluster.
- The Valkey deployment must reference it via `imagePullSecrets` (either on the pod spec or ServiceAccount, depending on chart support).

Git-side changes (values.yaml) to switch to DHI:

- `valkey.image.registry: dhi.io`
- `valkey.image.repository: valkey`
- `valkey.image.tag: 9.0.2-debian13`
- Add `imagePullSecrets: [{ name: kubernetes-dhi }]` in the rendered pod spec.

Rigor note:

- The upstream chart currently overrides the container command (`valkey-server /data/conf/valkey.conf`), so the DHI entrypoint may be bypassed. That is usually fine, but it means you are not using `tini` from the image.
- Switching the image means the wrapper `appVersion` should be bumped to `9.0.2`, and the wrapper chart `version` should be bumped as well.

## Change Log

- 2026-02-06: Regenerated this diary after accidental deletion. Content reflects live cluster state and current Git configuration.
- 2026-02-06: Added a wiring audit of current Valkey consumers (Git and live cluster).

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
