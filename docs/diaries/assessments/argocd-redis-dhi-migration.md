# ArgoCD Redis / DHI / Valkey Migration Assessment (Updated)

**Date:** 2026-02-11
**Status:** Updated assessment with current upstream + DHI availability

## Current State

- ArgoCD currently runs embedded Redis from `docker.io/redis:8.4.0-alpine3.22`.
- Config location: `apps/cluster/argocd/values.yaml`.
- Usage remains cache/session for ArgoCD control-plane.
- Shared Valkey app already exists at `apps/cluster/valkey` and currently uses:
  - `dhi.io/valkey:9.0.2@sha256:710eea...`
  - `auth.enabled: false`

## What Changed Since Previous Assessment

1. **Upstream Redis moved from 8.4.0 to 8.4.1.**
   - Renovate PR #135 targeted `8.4.0-alpine3.22 -> 8.4.1-alpine3.22`.
   - Redis 8.4.1 release date: 2026-02-08.

2. **DHI Redis 8.4.1 is not currently visible in public DHI Redis catalog pages.**
   - Public DHI Redis catalog shows 8.2.x line (plus older lines).
   - This means an immediate 1:1 move to `dhi.io/redis:8.4.1-*` is not confirmed from public sources.

3. **Previous statement that ArgoCD chart has hardcoded Redis image is incorrect.**
   - Argo Helm `9.4.1` supports overriding `redis.image.repository` and `redis.image.tag`.
   - It also supports `externalRedis.host` for external Redis/Valkey.

## Option Comparison

### Option A: Stay upstream and take patch update (`8.4.1-alpine3.22`)

- **Effort:** Very low
- **Risk:** Low
- **Pros:**
  - No version downgrade
  - Fastest path to latest upstream fixes
- **Cons:**
  - No DHI hardening benefits
  - musl/alpine base remains

### Option B: Switch embedded ArgoCD Redis to DHI Redis `8.2.3`

- **Effort:** Low
- **Risk:** Low to medium
- **Pros:**
  - DHI hardened image supply-chain posture
  - Aligns with DHI strategy
- **Cons:**
  - Version gap vs current upstream 8.4.1
  - Publicly visible DHI Redis is currently 8.2.x, so this is a downgrade path

### Option C: Use shared in-cluster Valkey (`apps/cluster/valkey`) via `externalRedis`

- **Effort:** Medium
- **Risk:** Medium
- **Pros:**
  - Uses existing shared service already consumed by other apps
  - Moves ArgoCD off embedded Redis pod
  - Aligns with open Valkey direction
- **Cons:**
  - Shared service currently has `auth.enabled: false`
  - Requires explicit tenancy isolation choices (DB index + credentials)

## Direct Answer: Can ArgoCD use existing `apps/cluster/valkey`?

Yes. ArgoCD can use existing shared Valkey by disabling embedded Redis and setting `externalRedis.host`.

High-level values pattern:

```yaml
argo-cd:
  redis:
    enabled: false
  externalRedis:
    host: valkey.apps.svc.cluster.local
    port: 6379
```

ArgoCD chart also supports Redis DB selection through `configs.params` (`redis.db`) which maps to `REDISDB`.

## Enabling `auth.enabled: true` on Shared Valkey

This is feasible, but requires a coordinated migration for all consumers.

### Prerequisites

1. Keep using SealedSecrets (no plaintext secrets in Git).
2. Reuse or extend existing secret:
   - `apps/cluster/secrets-cluster/valkey-users.sealedsecret.yaml`
3. Ensure every consuming app has credentials wired before turning auth on.

### Required Valkey Chart Configuration

In `apps/cluster/valkey/values.yaml`:

```yaml
valkey:
  auth:
    enabled: true
    usersExistingSecret: valkey-users
    aclUsers:
      default:
        permissions: "~* &* +@all"
      argocd:
        permissions: "~* &* +@all"
      harbor:
        permissions: "~* &* +@all"
      netbox:
        permissions: "~* &* +@all"
      gitea:
        permissions: "~* &* +@all"
```

Important chart constraints (validated against `dhi.io/valkey-chart:0.9.3`):

- `auth.enabled: true` requires `aclUsers` or `aclConfig`.
- `default` user must exist in `aclUsers` when auth is enabled.
- Users need `permissions`.
- Passwords must come from inline `password` or `usersExistingSecret`.

### Required Client Updates

1. **ArgoCD**
   - Use `externalRedis`.
   - Provide secret with `redis-username` and `redis-password`.
   - Set dedicated DB index via `configs.params.redis.db` to avoid collisions.

2. **NetBox**
   - Currently points to shared Valkey with empty password.
   - Must set username/password for tasks and caching DB connections.

3. **Harbor**
   - Already has `harbor-valkey` secret with username/password fields.
   - Validate behavior carefully because Harbor template logic uses `lookup` for secret-based Redis creds.
   - This is the main operational caveat during ArgoCD-rendered deployments.

4. **Gitea**
   - Already uses secret-backed redis connection strings.
   - Confirm credentials match final ACL users/passwords.

## Recommended Migration Strategy

### Phase 1 (safe immediate)

Pick one:

1. Merge upstream patch update to `8.4.1-alpine3.22`, or
2. Keep current while preparing shared Valkey auth cutover.

### Phase 2 (shared Valkey auth-ready)

1. Add/verify all ACL users + passwords in `valkey-users` sealed secret.
2. Update all consumers (ArgoCD/NetBox/Harbor/Gitea) to credentialed connections.
3. Validate manifests and chart rendering in Git.
4. Flip `valkey.auth.enabled: true`.
5. Monitor all consumers closely.

### Phase 3 (cleanup)

1. Remove deprecated unauthenticated connection assumptions from app values.
2. Document final ACL user ownership and rotation process.

## Risk Summary

| Risk | Level | Notes |
|---|---|---|
| ArgoCD downtime during Redis endpoint switch | Medium | Expected brief restart/reconnect window |
| Breakage from shared Valkey auth flip | Medium-High | Any missed client credential causes immediate failures |
| Harbor lookup-based Redis secret behavior | Medium | Needs explicit validation in ArgoCD render path |
| Data loss | Low | ArgoCD cache/session workload |

## Decision Snapshot

- Shared `apps/cluster/valkey` is technically usable for ArgoCD today.
- Enforcing `auth.enabled: true` is possible and preferred for long-term posture.
- Full auth cutover must be coordinated across all current Valkey consumers, not ArgoCD alone.

## References

- ArgoCD wrapper values: `apps/cluster/argocd/values.yaml`
- Shared Valkey wrapper: `apps/cluster/valkey/values.yaml`
- Shared Valkey users secret: `apps/cluster/secrets-cluster/valkey-users.sealedsecret.yaml`
- NetBox shared Valkey usage: `apps/user/netbox/values.yaml`
- Harbor external Valkey usage: `apps/user/harbor/values.yaml`
- Gitea redis secret wiring: `apps/user/gitea/values.yaml`
- Renovate PR #135: <https://github.com/sm-moshi/infra/pull/135>
- Redis releases:
  - <https://github.com/redis/redis/releases/tag/8.4.1>
  - <https://github.com/redis/redis/releases/tag/8.2.3>
- DHI Redis catalog: <https://hub.docker.com/hardened-images/catalog/dhi/redis/images>
