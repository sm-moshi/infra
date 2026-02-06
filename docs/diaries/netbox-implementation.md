# NetBox Implementation Notes

**Status:** Running (2026-02-06)
**Target:** `apps/user/netbox`
**Stack:** CNPG (`cnpg-main`), Valkey (shared, no auth), MinIO (S3 media), Traefik ingress
**Created:** 2026-02-02
**Updated:** 2026-02-06

## What Was Broken

1. NetBox ingress showed Traefik `no available server`.
   - Root cause: the `netbox` pod was in `CrashLoopBackOff` because the upstream chart's default liveness probe hits the NGINX Unit status endpoint on port `8081`, but the container was running the app server on `8080` (granian). The liveness probe repeatedly failed and Kubernetes restarted the pod.
2. Early deployments also hit DB role bootstrapping failures when CNPG role init ordering broke (DHI postgres images are intentionally minimal and some init scripts relied on extra tooling).

## Fixes Applied (Git)

1. **Override NetBox liveness probe to match the real server**
   - File: `apps/user/netbox/values.yaml`
   - Change: `netbox.customLivenessProbe` now probes `GET /login/` on port `http` with the correct `Host` header.

2. **Make DB provisioning self-contained (no cross-app ordering dependency)**
   - File: `apps/user/netbox/templates/db-init.job.yaml`
   - Behaviour: the ArgoCD `PreSync` Job:
     - waits for `cnpg-main-rw.apps.svc.cluster.local:5432`
     - ensures role `netbox` exists and sets/rotates its password from Secret `netbox-postgres-auth`
     - creates/owns database `netbox`

## Validation (Read-Only)

ArgoCD:

- `argocd app sync secrets-apps`
- `argocd app sync netbox`
- `argocd app wait netbox --health`

Kubernetes:

- `kubectl -n apps get pods -l app.kubernetes.io/name=netbox`
- `kubectl -n apps get endpoints netbox` (should show ready addresses, not `notReadyAddresses`)
- `kubectl -n apps logs job/netbox-db-init --tail=200`
- `kubectl -n apps logs deploy/netbox --tail=200`

HTTP:

- `curl -kI https://netbox.m0sh1.cc/login/`

## Notes / Follow-Ups

- The NetBox log warning about `API_TOKEN_PEPPERS` is not fatal, but you should set it in `netbox-existing` if you want v2 API tokens.
- Authentik SSO is intentionally deferred; this deployment keeps auth local-first for initial bring-up.
- If the **NetBox News** panel shows an RSS error like `SSLCertVerificationError: unable to get local issuer certificate`, ensure we are not overriding global Python/requests trust with `REQUESTS_CA_BUNDLE`. We only set `AWS_CA_BUNDLE` for MinIO S3 (boto3/botocore), so external HTTPS (like the NetBox Labs newsfeed) continues to use the system CA bundle.
