# Semaphore Implementation

**Date:** 2026-02-07
**Status:** Implemented (server + Authentik OIDC deployed; runners deferred)

## Goal

Deploy Semaphore UI via GitOps (Git -> ArgoCD -> Cluster) into the `apps`
namespace, backed by the shared CNPG cluster `cnpg-main`.

## Scope

- Semaphore server (UI + API)
- CNPG role + database provisioning (centralized in `apps/cluster/cloudnative-pg`)
- TLS ingress via Traefik

Non-goals for the first pass:

- Remote runners (historically brittle; defer until server is stable)
- OIDC integration was initially deferred; now implemented via a Secret-backed
  `config.json` mounted into the pod (no secrets in Git)

## What’s In Git

- Wrapper chart:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/semaphore`
  - `apps/user/semaphore/values.yaml` enables the upstream chart and uses CNPG:
    - DB host: `10.43.178.218:5432` (ClusterIP for `cnpg-main-rw`)
    - DB name: `semaphore`
    - Secret: `semaphore-postgres-auth`
- ArgoCD Application:
  - `/Users/smeya/git/m0sh1.cc/infra/argocd/apps/user/semaphore.yaml`
- SealedSecrets (managed by `secrets-apps`):
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/secrets-apps/semaphore-postgres-auth.sealedsecret.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/secrets-apps/semaphore-admin.sealedsecret.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/secrets-apps/semaphore-secrets.sealedsecret.yaml`
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/secrets-apps/semaphore-oidc.sealedsecret.yaml` (OIDC client + config.json)
- CNPG centralized provisioning:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/cluster/cloudnative-pg/values.yaml`:
    - enables role `semaphore` (login: true)
    - enables database `semaphore` (owner: semaphore)

## Authentik OIDC (Secret-Safe)

Upstream `semaphoreui/semaphore` builds `config.json` in a ConfigMap, which is
not compatible with storing an OIDC client secret safely.

The fix is:

- Store the full OIDC provider config (including `client_secret`) in a Kubernetes
  Secret created by a SealedSecret:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/secrets-apps/semaphore-oidc.sealedsecret.yaml`
- Mount that Secret as `/etc/semaphore/config.json` in the Semaphore pod.
- Bootstrap Authentik provider + application via a PostSync hook job:
  - `/Users/smeya/git/m0sh1.cc/infra/apps/user/authentik/templates/semaphore-oidc.job.yaml`

To make this work reproducibly under GitOps, the Semaphore wrapper vendors the
upstream chart sources (patched to support `config.existingSecret`):

- `/Users/smeya/git/m0sh1.cc/infra/apps/user/semaphore/charts/semaphore`
- `/Users/smeya/git/m0sh1.cc/infra/apps/user/semaphore/Chart.yaml` depends on:
  - `repository: file://charts/semaphore`

## Sync Order (GitOps)

1. `argocd app sync secrets-apps`
2. `argocd app sync cloudnative-pg` (ensure role+db exist)
3. `argocd app sync apps-root` (pick up newly enabled app manifests)
4. `argocd app sync semaphore`
5. OIDC (one-time / updates):
   - `argocd app sync authentik` (runs the OIDC bootstrap hook job)
   - `argocd app sync semaphore`

## Validation (Read-Only)

- ArgoCD:
  - `argocd app get semaphore`
  - `argocd app diff semaphore`
- Kubernetes:
  - `kubectl -n apps get deploy,po,svc,ingress | rg semaphore`
  - `kubectl -n apps logs deploy/semaphore --tail=200`
- DB connectivity:
  - Confirm role + db exist (via pgAdmin or psql using `cnpg-main-superuser`).

## DNS Gotcha (musl + AAAA NXDOMAIN)

Semaphore’s container image uses `nc` in a start script to wait for the DB
socket. On this cluster, Service AAAA lookups return NXDOMAIN (IPv6 suppressed),
and `nc` on musl/Alpine can fail name resolution hard even though A records
exist. Symptom: `nc: bad address 'cnpg-main-rw.apps.svc.cluster.local'`.

Workaround: use the `cnpg-main-rw` ClusterIP in values (and keep a comment with
the intended DNS name).

## Next Steps

1. Runners:
   - Bring runners back only after server is stable.
   - Prefer a GitOps-friendly approach (pre-provisioned runner tokens stored as
     SealedSecrets + mounted config), or keep runners external for now.
2. Authentik OIDC:
   - Implemented.
   - If `semaphore-oidc` changes, bump `semaphore.annotations.m0sh1.cc/oidc-config-rev`
     in `/Users/smeya/git/m0sh1.cc/infra/apps/user/semaphore/values.yaml` to trigger
     a rollout (Secret changes alone don't force a restart).
