# Authentik Implementation Notes

**Status:** Running (2026-02-06)
**Target:** `apps/user/authentik`
**Stack:** CNPG (`cnpg-main`), MinIO (S3 media), Traefik ingress
**Created:** 2026-02-02
**Updated:** 2026-02-06

## What Was Broken

Bring-up was blocked by DB bootstrapping failures when role creation depended on a separate CNPG init-roles Job (ordering and minimal-image assumptions caused the role not to exist when Authentik started).

## Fixes Applied (Git)

1. **Make DB provisioning self-contained**
   - File: `apps/user/authentik/templates/db-init.job.yaml`
   - Behaviour: the ArgoCD `PreSync` Job:
     - waits for `cnpg-main-rw.apps.svc.cluster.local:5432`
     - ensures role `authentik` exists and sets/rotates its password from Secret `authentik-postgres-auth`
     - creates/owns database `authentik`

2. **Use DHI postgres userspace image for the init Job**
   - File: `apps/user/authentik/values.yaml`
   - Notes: the DHI image is intentionally minimal; scripts avoid assuming extra utilities.

## Validation (Read-Only)

ArgoCD:

- `argocd app sync secrets-apps`
- `argocd app sync authentik`
- `argocd app wait authentik --health`

Kubernetes:

- `kubectl -n apps get pods -l app.kubernetes.io/name=authentik`
- `kubectl -n apps logs job/authentik-db-init --tail=200`

HTTP:

- `curl -kI https://10.0.30.10/ -H 'Host: auth.m0sh1.cc'` (bypasses local DNS)

## Notes / Follow-Ups

- If `auth.m0sh1.cc` times out from your workstation but the `curl`-by-IP test above works, the problem is DNS resolution on the client side (not the cluster). In that case, fix your resolver path for `m0sh1.cc` so `auth.m0sh1.cc` returns the Traefik LB IP (`10.0.30.10`).
