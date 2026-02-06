# NetBox Implementation Plan

**Status:** Planning
**Target:** apps/user/netbox
**Dependencies:** CNPG (cnpg-main), Valkey (shared), MinIO tenant (internal HTTPS), Traefik ingress
**Created:** 2026-02-02
**Updated:** 2026-02-06

## Summary

Deploy NetBox (IPAM/DCIM) via wrapper chart + ArgoCD, aligned to GitOps constraints:

- Wrapper chart: `apps/user/netbox` (upstream NetBox chart `7.4.5`, NetBox app `v4.5.2`).
- PostgreSQL via shared CNPG cluster (`cnpg-main-rw.apps.svc.cluster.local`).
- Valkey via shared cluster service `valkey.apps.svc.cluster.local` (auth currently disabled).
- No imperative DB creation steps; DB provisioning is an ArgoCD-applied, idempotent PreSync Job.
- The DB init Job runs on the rootless DHI Postgres Debian 13 userspace image (pinned by digest via `dbInit.image`) and avoids `grep/sed` (checks use `psql -Atc` output).
- The DB init Job is self-contained: it ensures the `netbox` role exists and sets its password from SealedSecret `netbox-postgres-auth` (avoids cross-Argo-app ordering assumptions).
- Media uploads stored in MinIO S3 using internal HTTPS endpoint + k3s CA trust (`minio-ca`).
- Secrets live in `apps/user/secrets-apps/` as SealedSecrets.
- Authentication is local-first; Authentik SSO is a later phase.

Recommended sequencing: deploy Authentik first, then deploy NetBox once Authentik is stable.

## Cluster Reality (Assumptions)

- Namespace for app workloads: `apps`.
- CNPG RW endpoint: `cnpg-main-rw.apps.svc.cluster.local:5432`.
- Valkey service: `valkey.apps.svc.cluster.local:6379` with `auth.enabled=false`.
- MinIO internal endpoint: `https://minio.minio-tenant.svc.cluster.local` (issuer: k3s server CA).
- TLS for ingress uses reflected secret `wildcard-m0sh1-cc` in namespace `apps`.

If any of these differ, update the wrapper values and this plan.

## Repo Artifacts (What This Plan Adds)

- Wrapper chart: `apps/user/netbox/`
  - `Chart.yaml` depends on upstream NetBox chart `7.4.5` from GHCR OCI.
  - `values.yaml` configures external DB/Valkey, Traefik ingress, and mounts `minio-ca`. It also defines `dbInit.image` / `dbInit.imagePullPolicy` for the PreSync Job.
  - `templates/db-init.job.yaml` is an ArgoCD PreSync Job that creates the `netbox` DB idempotently using the configured `dbInit.image`.
- ArgoCD app manifest (manual sync by default): `argocd/apps/user/netbox.yaml`

## Phase 1: Secrets (MUST happen before enabling CNPG role)

All secrets for NetBox must be committed as SealedSecrets under `apps/user/secrets-apps/`.
Add the new SealedSecret manifests to `apps/user/secrets-apps/kustomization.yaml` so ArgoCD applies them.

### 1.1 SealedSecret: Postgres Role Password (`netbox-postgres-auth`)

CNPG's init-roles job expects the Secret named `netbox-postgres-auth` with key `password`.

- Namespace: `apps`
- Secret name: `netbox-postgres-auth`
- Key: `password`

### 1.2 SealedSecret: NetBox Secret Key (`netbox-existing`)

The NetBox chart supports `existingSecret` and expects key `secret_key`.

- Namespace: `apps`
- Secret name: `netbox-existing`
- Key: `secret_key` (50+ random characters)

### 1.3 SealedSecret: NetBox Superuser (`netbox-superuser`)

The NetBox chart expects the following keys:

- Namespace: `apps`
- Secret name: `netbox-superuser`
- Keys:
  - `username`
  - `email`
  - `password`
  - `api_token`

### 1.4 SealedSecret: Extra Config (`netbox-extra-config`)

We avoid relying on AWS env auto-detection. Instead we configure storage explicitly.

The wrapper chart mounts a Secret as `/run/config/extra/0/storages.yaml`.
Create a Secret named `netbox-extra-config` with a key `storages.yaml` containing YAML like:

```yaml
STORAGES:
  default:
    backend: storages.backends.s3.S3Storage
    options:
      bucket_name: netbox-media
      access_key: <minio access key>
      secret_key: <minio secret key>
      endpoint_url: https://minio.minio-tenant.svc.cluster.local
```

Notes:

- Keep staticfiles local (default). Only media uploads go to S3 by setting `default` storage.
- TLS trust is handled by the wrapper chart mounting `minio-ca` and setting `AWS_CA_BUNDLE` + `REQUESTS_CA_BUNDLE`.

### 1.5 Bucket + MinIO Credentials

Create bucket `netbox-media` in MinIO and generate an access key/secret with least-privilege to that bucket.

## Phase 2: CNPG Role (Enable only after secrets exist)

After `netbox-postgres-auth` SealedSecret is committed and synced by ArgoCD (`secrets-apps`), enable the role.

File: `apps/cluster/cloudnative-pg/values.yaml`

- Set `cnpg.roles[].name=netbox` to `enabled: true`.

Then ArgoCD will run the CNPG init-roles job and create/rotate the role password.

Note: This is recommended for consistency, but NetBox does not rely on it for correctness anymore (see Phase 3).

## Phase 3: Deploy NetBox Wrapper

### 3.1 DB provisioning (GitOps)

The wrapper chart includes `apps/user/netbox/templates/db-init.job.yaml`:

- Runs as ArgoCD `PreSync` hook.
- Runs on `dbInit.image` (default: rootless DHI Postgres Debian 13 pinned by digest).
- Waits for CNPG RW endpoint readiness.
- Ensures role `netbox` exists and sets its password from `netbox-postgres-auth/password`.
- Creates DB `netbox` if missing and ensures the DB owner is `netbox`.

### 3.2 Valkey

The wrapper disables the bundled Valkey chart and uses the shared in-cluster service.
Because `apps/cluster/valkey/values.yaml` currently has `auth.enabled: false`, the wrapper does not set any Redis password.

If Valkey auth is enabled later, update wrapper values to use `tasksDatabase.existingSecretName` and `cachingDatabase.existingSecretName`.

### 3.3 ArgoCD Application

Manifest: `argocd/apps/user/netbox.yaml`

By default, this Application is not `automated` until secrets are in Git and synced.
After the first successful sync and validation, you may enable:

- `syncPolicy.automated.prune=true`
- `syncPolicy.automated.selfHeal=true`

## Phase 4: Validation

Repo checks (no cluster mutation):

- `mise run helm-lint`
- `mise run k8s-lint`
- `mise run sensitive-files`
- `mise run path-drift`

Read-only cluster checks (after syncing in ArgoCD):

- NetBox ingress:
  - `kubectl get ingress -n apps netbox -o wide`
- DB init job completion:
  - `kubectl get jobs -n apps netbox-db-init`
  - `kubectl logs -n apps job/netbox-db-init --tail=100`

## Rollback

- Disable the ArgoCD Application (or remove it from `argocd/apps/user`).
- Revert the CNPG role enablement for `netbox`.
- Remove `apps/user/netbox/` wrapper chart.
