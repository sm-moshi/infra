# Authentik OIDC Review

Date: 2026-03-06

## Scope

This review covers the remaining wrapper charts under `apps/user` that now declare `authentikMode: oidc`.

Reviewed files:

- [`/Users/smeya/git/m0sh1.cc/infra/apps/user/forgejo/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/forgejo/values.yaml)
- [`/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/values.yaml)
- [`/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/values.yaml)
- [`/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml)
- [`/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml)
- [`/Users/smeya/git/m0sh1.cc/infra/apps/user/scanopy/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/scanopy/values.yaml)
- [`/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml)

## Decision

Do not force the remaining OIDC wrappers into `forward-auth`.

Keep native OIDC as the primary pattern for these apps. The right cleanup target is not a runtime auth refactor. The right cleanup target is to document and gradually normalize the wrapper-side OIDC contract shape for secret names, callback URLs, and bootstrap ownership.

As of the follow-up pass on 2026-03-06, the OIDC wrappers now carry explicit top-level `oidcContract` metadata in their `values.yaml` files. That metadata is wrapper-owned documentation and validation input only; it does not replace the upstream chart's native OIDC settings.

## App Review

| App | Recommendation | Reason | Follow-up |
| --- | --- | --- | --- |
| `forgejo` | Keep app-native OIDC | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/forgejo/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/forgejo/values.yaml) uses Forgejo's native `gitea.oauth` integration and group mapping. Replacing it with `forward-auth` would lose application-native identity behavior. | No runtime change recommended. Keep documenting the required secret contract for `forgejo-oidc`. |
| `harbor` | Keep app-native OIDC with explicit exception for bootstrap ownership | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/harbor/values.yaml) configures OIDC through a Harbor bootstrap job, not via generic ingress auth. That behavior is Harbor-specific and should stay Harbor-specific. | Harden the bootstrap path instead of redesigning it. The immediate fix is to allow kube-apiserver egress for `harbor-bootstrap` and prefer a mounted `harbor-oidc` secret over Kubernetes API secret reads. Do not generalize Harbor's bootstrap flow into other wrappers. |
| `headlamp` | Keep app-native OIDC | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/headlamp/values.yaml) uses the chart's native OIDC block and its own callback handling. This is a clean chart-native contract already. | No structural change recommended. |
| `netbox` | Keep app-native OIDC | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml) uses NetBox `remoteAuth` plus mounted OIDC config. This is still native app authentication even though the wrapper translates secrets into NetBox config files. | Candidate for wrapper-level documentation cleanup only: document the expected contents of `netbox-oidc-config` more explicitly. |
| `open-webui` | Keep app-native OIDC, normalize wrapper inputs later | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml) drives OIDC through application env vars and secret refs. This is still native OIDC, but its contract is the least self-describing of the group. | Best candidate for a future wrapper cleanup: add a small wrapper-owned OIDC values block and render the app env vars from that block without changing behavior. |
| `scanopy` | Keep app-native OIDC | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/scanopy/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/scanopy/values.yaml) already has a compact wrapper-level `server.oidc` contract backed by a single secret file. This is a good shape. | No structural change recommended. |
| `vaultwarden` | Keep app-native OIDC, normalize wrapper inputs later | [`/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml) uses app-native SSO vars with a separate secret. This is functionally correct, but the contract is still env-oriented rather than wrapper-oriented. | Secondary candidate for a future wrapper cleanup: document or wrap the expected `extraVarsSecret` keys under a clearer OIDC block. |

## Recommendation Order

If further cleanup is needed, do it in this order:

1. [`/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/open-webui/values.yaml)
2. [`/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/vaultwarden/values.yaml)
3. [`/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/netbox/values.yaml)

Those are the wrappers where the OIDC contract is still expressed mostly as env vars or mounted app config rather than as a wrapper-native schema. The goal should be clearer wrapper contracts, not a migration away from native OIDC.

## Non-Goals

- Do not convert these apps to `forward-auth` just for uniformity.
- Do not try to collapse Harbor bootstrap behavior into a generic shared OIDC template.
- Do not mix OIDC normalization with secret storage changes.
