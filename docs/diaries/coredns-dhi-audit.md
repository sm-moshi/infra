# CoreDNS DHI Migration — Deep Audit & GO/NO-GO Recommendation

**Date**: 2026-02-09
**Author**: AI Agent (Claude)
**Status**: CONDITIONAL GO
**Related**: `docs/diaries/archived/coredns-disaster-recovery.md`

---

## Executive Summary

**Verdict: CONDITIONAL GO — image swap only, via kubectl, with strict pre/post validation.**

The DHI CoreDNS image (`dhi.io/coredns:1.14.1-debian13`) is compatible with our
Corefile and plugin requirements. All 12 plugins we use are present. No CRDs are
involved. No breaking changes exist across the 3 minor version gap (1.11 → 1.14).

However, this is CoreDNS — the single point of failure for all cluster DNS. A
failed migration means no DNS, no ArgoCD, no GitOps recovery. The migration MUST
be performed manually via `kubectl` with immediate rollback capability.

**This migration MUST NOT touch the wrapper chart or ArgoCD.**

---

## Architecture Context

Two separate CoreDNS layers exist:

| Layer | Status | Notes |
|---|---|---|
| k3s built-in CoreDNS | **ACTIVE** — running DNS now | Image: `rancher/mirrored-coredns-coredns:1.11.1` |
| Wrapper chart (`apps/cluster/coredns/`) | **DISABLED** — do not re-enable | Caused 6-hour outage (2026-01-29) |

The migration targets the **k3s-managed deployment only** — a container image
swap from `rancher/mirrored-coredns-coredns:1.11.1` to
`dhi.io/coredns:1.14.1-debian13`.

---

## Phase Summary (1–6)

### Phase 1: Local Config Audit

- Wrapper chart: `coredns` v1.45.2 dependency, disabled
- Live Corefile: `cluster/environments/lab/coredns-configmap.yaml`
- 12 plugins configured: errors, health, ready, hosts, kubernetes, prometheus,
  template, forward, cache, loop, reload, loadbalance

### Phase 2: Live Cluster State

- Deployment: `coredns` in `kube-system`, 1 replica, running on `horse03`
- Image: `rancher/mirrored-coredns-coredns:1.11.1`
- Service: `kube-dns` at `10.43.0.10` (UDP + TCP port 53)
- No `imagePullSecrets` configured (needs addition for `dhi.io`)
- DHI pull secret `kubernetes-dhi` exists in `kube-system`
- Logs show intermittent upstream forwarder timeouts to `10.0.30.1` (pre-existing)

### Phase 3: DHI Image Inspection

- Tag: `1.14.1-debian13`
- Digest: `sha256:4100a2300acef71879ca7504deeeb1c2000e62f932ad3342cde47548bca64ffd`
- User: `nonroot` (compatible with current `nonroot:nonroot`)
- Entrypoint: `["coredns"]` — binary at `/usr/local/bin/coredns`, symlinked to `/coredns`
- Base: Debian 13 runtime (no shell, no package manager)
- Current entrypoint: `["/coredns"]` — args `["-conf", "/etc/coredns/Corefile"]`
  append to entrypoint, compatible with both paths

### Phase 4: Plugin Compatibility

- **All 12 plugins present in v1.14.1** — full match
- v1.14.1 adds new plugins (quic, grpc_server, multisocket, nomad, etc.) but
  removes none

### Phase 5: CRD Analysis

- CoreDNS uses no CRDs in either version
- No CRD migration required

### Phase 6: Version Gap Analysis (1.11.1 → 1.14.1)

- **v1.12.0**: New `multisocket` plugin. No breaking changes. LOW RISK.
- **v1.13.0**: `forward` plugin gains `failover` option (opt-in only, default
  behavior unchanged). Bug fixes for loop detection, reload deadlock. LOW-MEDIUM.
- **v1.14.0**: `kubernetes` plugin adds API rate limiting (sensible defaults,
  not breaking). Security regex length limits. LOW RISK.
- **v1.14.1**: Go CVE fixes, proxy plugin performance improvement. MINIMAL RISK.
- **Overall: LOW RISK** — all changes are additive or bug fixes.

---

## Phase 7: GO/NO-GO Recommendation

### Verdict: CONDITIONAL GO

Proceed with the image swap under the following conditions:

1. Perform during a **low-traffic maintenance window**
2. Have **SSH access to all nodes** ready before starting
3. Execute via **kubectl only** — no Helm, no ArgoCD, no wrapper chart
4. Complete all pre-migration validation before touching the deployment
5. Operator must be ready to **rollback within 30 seconds** if DNS breaks

### Risk Matrix

| Risk | Severity | Mitigation |
|---|---|---|
| DNS outage during swap | CRITICAL | Rollback command pre-staged, <30s recovery |
| k3s overrides image on restart | MEDIUM | Document as known drift; acceptable for hardened image |
| `imagePullSecrets` missing | HIGH | Add patch before image swap |
| Upstream forwarder timeouts confused with migration issue | LOW | Baseline logs captured before migration |
| `template IN AAAA` plugin behavioral change | LOW | Plugin present and unchanged across versions |
| Port 53 binding as nonroot | LOW | Current image also runs as nonroot; k8s NET_BIND_SERVICE capability handles this |

### Why NOT "NO-GO"

- All 12 plugins confirmed present
- No breaking changes in 3 minor versions
- Entrypoint is compatible (symlink covers `/coredns` path)
- DHI pull secret already in namespace
- The image swap is atomic and instantly reversible
- Version 1.11.1 is 2.5 years old with known CVEs

### Why "CONDITIONAL" (not unconditional GO)

- CoreDNS is single point of failure — no DNS means no recovery via GitOps
- k3s may override the image change on k3s upgrade/restart
- This is a manual `kubectl` mutation, not GitOps-tracked (necessary exception)
- Base image change (distroless → Debian 13) is non-trivial

---

## Migration Procedure

### Pre-Migration Checklist

```bash
# 1. Verify CoreDNS is healthy
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Expected: 1/1 Running

# 2. Verify DNS works (baseline)
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local
# Expected: returns 10.43.0.1

kubectl run dns-test2 --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup google.com
# Expected: returns public IP

# 3. Capture baseline logs (save to local file for comparison)
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100

# 4. Verify DHI pull secret exists
kubectl get secret kubernetes-dhi -n kube-system
# Expected: kubernetes.io/dockerconfigjson

# 5. Verify DHI image is pullable (from a test pod)
kubectl run dhi-test --rm -it --restart=Never -n kube-system \
  --image=dhi.io/coredns:1.14.1-debian13 \
  --overrides='{"spec":{"imagePullSecrets":[{"name":"kubernetes-dhi"}]}}' \
  -- /coredns -version
# Expected: prints CoreDNS version 1.14.1, pod completes

# 6. Confirm SSH access to nodes
ssh horse01 'echo ok'
ssh horse02 'echo ok'
ssh horse03 'echo ok'

# 7. Record current image for rollback
kubectl get deployment coredns -n kube-system \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: rancher/mirrored-coredns-coredns:1.11.1
```

### Stage the Rollback Command

**Before doing anything else**, paste this into a separate terminal and keep it ready:

```bash
# ROLLBACK COMMAND — execute immediately if DNS breaks
kubectl set image deployment/coredns \
  -n kube-system \
  coredns=rancher/mirrored-coredns-coredns:1.11.1 && \
kubectl rollout status deployment/coredns -n kube-system --timeout=60s
```

### Migration Steps

```bash
# Step 1: Add imagePullSecrets to the deployment
kubectl patch deployment coredns -n kube-system --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/imagePullSecrets",
    "value": [{"name": "kubernetes-dhi"}]
  }
]'

# Wait for rollout (this alone should NOT restart the pod since the
# image hasn't changed, but imagePullSecrets is in the pod template
# so it WILL trigger a new rollout)
kubectl rollout status deployment/coredns -n kube-system --timeout=120s

# Step 1b: Verify DNS still works after imagePullSecrets patch
kubectl run dns-check --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local
# If this FAILS → rollback immediately (remove imagePullSecrets patch)

# Step 2: Swap the image (pin to digest)
kubectl set image deployment/coredns \
  -n kube-system \
  coredns=dhi.io/coredns:1.14.1-debian13@sha256:4100a2300acef71879ca7504deeeb1c2000e62f932ad3342cde47548bca64ffd

# Step 3: Watch rollout
kubectl rollout status deployment/coredns -n kube-system --timeout=120s
```

### Post-Migration Validation

```bash
# 1. Pod is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Expected: 1/1 Running, 0 restarts

# 2. Image is correct
kubectl get deployment coredns -n kube-system \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: dhi.io/coredns:1.14.1-debian13@sha256:4100a2300...

# 3. Internal DNS resolution
kubectl run dns-post1 --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local
kubectl run dns-post2 --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup argocd-server.argocd.svc.cluster.local

# 4. External DNS resolution
kubectl run dns-post3 --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup google.com

# 5. Proxmox static hosts (critical for CSI)
kubectl run dns-post4 --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup pve01.m0sh1.cc

# 6. AAAA template (should return NXDOMAIN for AAAA queries)
kubectl run dns-post5 --rm -it --image=nicolaka/netshoot --restart=Never -- \
  dig AAAA google.com @10.43.0.10
# Expected: status: NXDOMAIN

# 7. Check logs for errors
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
# Should NOT see: plugin/loop errors, crash backoff, permission denied

# 8. Prometheus metrics still exposed
kubectl run dns-post6 --rm -it --image=busybox:1.36 --restart=Never -- \
  wget -qO- http://$(kubectl get pod -n kube-system -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].status.podIP}'):9153/metrics | head -5
```

### Rollback Procedure

If any validation step fails:

```bash
# Immediate rollback — restores original rancher image
kubectl set image deployment/coredns \
  -n kube-system \
  coredns=rancher/mirrored-coredns-coredns:1.11.1

kubectl rollout status deployment/coredns -n kube-system --timeout=60s

# Optionally remove imagePullSecrets if reverting completely
kubectl patch deployment coredns -n kube-system --type=json -p='[
  {"op": "remove", "path": "/spec/template/spec/imagePullSecrets"}
]'
```

If the pod is in CrashLoopBackOff and rollout is stuck:

```bash
# Nuclear option — force rollback via rollout undo
kubectl rollout undo deployment/coredns -n kube-system

# If still stuck, SSH to node and verify kubelet can pull original image
ssh horse03 'sudo crictl pull rancher/mirrored-coredns-coredns:1.11.1'
```

---

## Known Limitations

### k3s Image Override on Restart

k3s manages the CoreDNS deployment. On k3s upgrade or service restart, k3s may
reset the CoreDNS image to its bundled version (`rancher/mirrored-coredns-coredns`).

**Accepted risk**: If k3s overrides the DHI image, CoreDNS will revert to the
rancher image. This is safe (just loses the hardening benefit). The override can
be re-applied after k3s stabilizes.

**Future mitigation**: Investigate k3s `--disable coredns` flag + full GitOps
management. This is a separate project and NOT part of this migration.

### Not GitOps-Tracked

This image swap is a manual `kubectl` mutation — it violates the normal GitOps
flow. This is a **necessary exception** because:

1. The wrapper chart is disabled and must not be re-enabled
2. k3s owns the deployment, not ArgoCD
3. The Corefile ConfigMap IS GitOps-tracked via `cluster/environments/lab/coredns-configmap.yaml`
4. Only the container image is being changed, not the configuration

---

## Appendix: Image Comparison

| Property | Current (rancher) | Target (DHI) |
|---|---|---|
| Image | `rancher/mirrored-coredns-coredns:1.11.1` | `dhi.io/coredns:1.14.1-debian13` |
| CoreDNS version | 1.11.1 (2023-08-15) | 1.14.1 (2026-01-15) |
| Base | distroless/static-debian11 | Debian 13 runtime |
| User | `nonroot:nonroot` | `nonroot` |
| Entrypoint | `["/coredns"]` | `["coredns"]` (symlink at `/coredns`) |
| Layers | 11 | 6 |
| Digest | — | `sha256:4100a2300acef71879ca7504deeeb1c2000e62f932ad3342cde47548bca64ffd` |
