# Authentik Contract

This document defines the supported Authentik integration modes for wrapper charts under `apps/user`.

## Supported Modes

### `forward-auth`

Use this mode when Traefik middleware enforces access before the upstream app sees the request.

Required wrapper contract:

- top-level `outpostIngress.*` values
- top-level `forwardAuth.*` values
- top-level `authentikMode: forward-auth`
- `templates/authentik-outpost.ingress.yaml`
- `templates/authentik-forwardauth.middleware.yaml`

### `oidc`

Use this mode when the upstream application performs its own OpenID Connect flow.

Required wrapper contract:

- app-specific OIDC values, secrets, env vars, or mounted config
- top-level `authentikMode: oidc`
- top-level `oidcContract.*` metadata describing the wrapper-side OIDC contract
- no Traefik Authentik forward-auth middleware contract in the wrapper

Recommended `oidcContract` fields:

- `providerName`
- one of `issuerURL`, `discoveryURL`, or `endpoint` when the wrapper points directly at client credential keys
- either `secretName` + `clientIdKey` + `clientSecretKey`
- or `configSecretName` + `configKey`
- optional `callbackURL`
- optional `groupsClaim`
- optional `adminGroup`

### `public`

Use this mode when the wrapper does not define an Authentik integration.

Required wrapper contract:

- no `outpostIngress` contract
- no `forwardAuth` contract
- top-level `authentikMode: public`
- no wrapper-level Authentik middleware or outpost templates

## Documented Exception

### `renovate`

[`/Users/smeya/git/m0sh1.cc/infra/apps/user/renovate/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/renovate/values.yaml) intentionally keeps an Authentik outpost ingress without a forward-auth middleware. This chart has no wrapper-level user-facing auth surface; the outpost route exists only for the callback/bootstrap flow already modeled in [`/Users/smeya/git/m0sh1.cc/infra/apps/user/authentik/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/authentik/values.yaml).

The guard allows this one exception explicitly. Do not copy this shape into other apps.

## App Inventory

The following inventory covers wrapper-level auth contracts under `apps/user`.

| App | Mode | Source of truth | Notes |
| --- | --- | --- | --- |
| `basic-memory` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/basic-memory/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/basic-memory/values.yaml) | Explicit `authentikMode: public`; no Authentik contract in the wrapper |
| `diode` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/diode/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/diode/values.yaml) | Explicit `authentikMode: public`; no Authentik contract in the wrapper |
| `forgejo` | `oidc` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/forgejo/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/forgejo/values.yaml) | Native OIDC via `gitea.oauth` with explicit `oidcContract` metadata |
| `garage-webui` | `forward-auth` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/garage-webui/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/garage-webui/values.yaml) | Traefik middleware plus Authentik outpost ingress |
| `harbor` | `oidc` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/values.yaml) | OIDC bootstrap contract in wrapper values plus explicit `oidcContract` metadata |
| `headlamp` | `oidc` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/values.yaml) | Native OIDC via Headlamp config with explicit `oidcContract` metadata |
| `netbox` | `oidc` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml) | OIDC config mounted from secret with explicit `oidcContract` metadata |
| `netbox-operator` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox-operator/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox-operator/values.yaml) | Explicit `authentikMode: public`; no Authentik contract in the wrapper |
| `netzbremse` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/netzbremse/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/netzbremse/values.yaml) | Explicit `authentikMode: public`; no Authentik contract in the wrapper |
| `ollama` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/ollama/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/ollama/values.yaml) | Explicit `authentikMode: public`; no Authentik contract in the wrapper |
| `open-webui` | `oidc` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml) | Native OIDC via env vars and secret refs, with explicit `oidcContract` metadata |
| `pgadmin4` | `forward-auth` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/pgadmin4/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/pgadmin4/values.yaml) | Traefik middleware plus Authentik outpost ingress |
| `qdrant` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/qdrant/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/qdrant/values.yaml) | Explicit `authentikMode: public`; no Authentik contract in the wrapper |
| `renovate` | `exception: outpost-only` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/renovate/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/renovate/values.yaml) | Allowed documented exception; no middleware contract |
| `scanopy` | `oidc` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/scanopy/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/scanopy/values.yaml) | Native OIDC config loaded from secret with explicit `oidcContract` metadata |
| `termix` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/termix/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/termix/values.yaml) | Explicit `authentikMode: public`; no wrapper-level Authentik contract today |
| `trivy-operator` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator/values.yaml) | Explicit `authentikMode: public`; no Authentik contract in the wrapper |
| `uptime-kuma` | `forward-auth` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/uptime-kuma/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/uptime-kuma/values.yaml) | Traefik middleware plus Authentik outpost ingress |
| `vaultwarden` | `oidc` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml) | Native OIDC via extra vars and secret, with explicit `oidcContract` metadata |
| `woodpecker` | `public` | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/woodpecker/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/woodpecker/values.yaml) | Explicit `authentikMode: public`; no wrapper-level Authentik contract today |

## Exclusions

[`/Users/smeya/git/m0sh1.cc/infra/apps/user/authentik/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/authentik/values.yaml) and [`/Users/smeya/git/m0sh1.cc/infra/apps/user/cilium-policies/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/cilium-policies/values.yaml) are intentionally excluded from wrapper-mode validation.

- `authentik` is the identity provider and bootstrap owner, not a consumer wrapper
- `cilium-policies` only references Authentik workloads for network policy purposes

## Guard Usage

Validate the contract with:

```bash
tools/ci/infra-guard authentik-contract
```

The guard validates both:

- the observed wrapper configuration shape
- the declared top-level `authentikMode` for wrappers that consume Authentik

For the March 6, 2026 review of the remaining `oidc` wrappers and their recommended follow-up order, see [`/Users/smeya/git/m0sh1.cc/infra/docs/diaries/2026-03-06-authentik-oidc-review.md`](/Users/smeya/git/m0sh1.cc/infra/docs/diaries/2026-03-06-authentik-oidc-review.md).
