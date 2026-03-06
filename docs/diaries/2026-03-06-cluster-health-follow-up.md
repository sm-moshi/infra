# Cluster Health Follow-Up — 2026-03-06

## Summary

Read-only inspection of the live `default` cluster on March 6, 2026 showed a transient recovery event rather than a sustained outage:

- all nodes were `Ready` by the end of the check
- ArgoCD `Application` resources in `argocd` were `Synced` and `Healthy`
- earlier warnings showed a recent `NodeNotReady` cascade and transient Proxmox CSI mount failures
- affected workloads recovered during the inspection window, including `ollama`

The only active node-level warning that remained material was image filesystem pressure on `horse01`.

## Observed Symptoms

- recent `NodeNotReady` events across multiple namespaces and system workloads
- transient `FailedMount` and `VolumeFailedDelete` events involving `csi.proxmox.sinextra.dev`
- temporary workload readiness failures in `apps`, `monitoring`, `crowdsec`, and `argocd`
- `horse01` emitted `FreeDiskSpaceFailed` warnings for the image filesystem

## Repo Follow-Up Implemented

- removed a tracked unsealed Proxmox CSI secret from [`/Users/smeya/git/m0sh1.cc/infra/apps/cluster/proxmox-csi/templates/proxmox-csi-plugin.sealedsecret-unsealed.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/cluster/proxmox-csi/templates/proxmox-csi-plugin.sealedsecret-unsealed.yaml)
- removed the duplicate ArgoCD notifications secret source from [`/Users/smeya/git/m0sh1.cc/infra/apps/cluster/argocd/argocd-notifications-secret.sealedsecret.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/cluster/argocd/argocd-notifications-secret.sealedsecret.yaml)
- standardized Authentik outpost and forward-auth wrapper values in the affected app charts
- collapsed Authentik bootstrap jobs into a single data-driven renderer under [`/Users/smeya/git/m0sh1.cc/infra/apps/user/authentik/templates/bootstrap.integrations.jobs.yaml`](/Users/smeya/git/m0sh1.cc/infra/apps/user/authentik/templates/bootstrap.integrations.jobs.yaml)
- tightened Docker build contexts and verified the NetBox `get-pip.py` bootstrap by checksum
- added a Git guardrail for transient Helm output via `**/tmpcharts-*` in [`/Users/smeya/git/m0sh1.cc/infra/.gitignore`](/Users/smeya/git/m0sh1.cc/infra/.gitignore)

## Remaining Operational Follow-Up

- inspect image and container garbage on `horse01` first; this is the only still-active warning source observed during the check
- keep watching for repeated CSI recovery churn; if it recurs, correlate node reboots, kubelet logs, and Proxmox CSI controller/node restarts
- keep the post-incident health check limited to read-only commands:
  - `kubectl get nodes -o wide`
  - `kubectl get pods -A`
  - `kubectl get events -A --sort-by=.lastTimestamp`
  - `kubectl get applications.argoproj.io -n argocd`
