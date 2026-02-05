# CoreDNS Disaster Recovery Guide

## Incident Overview

**Date**: 2026-01-29
**Duration**: ~6 hours
**Root Cause**: CoreDNS wrapper chart incompatible with k3s, kube-dns Service missing UDP port
**Impact**: Complete cluster DNS failure, ArgoCD unable to sync applications

## Symptoms

- All DNS queries timing out (both internal and external)
- Pods showing `dial tcp: lookup <service> on 10.43.0.10:53: i/o timeout`
- CoreDNS pods Running but not responding to queries
- Proxmox CSI provisioning failing with "no such host" errors
- ArgoCD applications stuck in "Unknown" sync status

## Root Causes

### Primary Cause: kube-dns Service Missing UDP Port

The kube-dns Service was created with **TCP protocol only**:

```yaml
ports:
- name: dns-tcp
  port: 53
  protocol: TCP  # WRONG - DNS queries use UDP!
  targetPort: 53
```

**Why this broke DNS**: DNS clients default to UDP for queries. TCP is only used for zone transfers and responses >512 bytes. Without the UDP port exposed, no queries could reach CoreDNS.

### Secondary Cause: CoreDNS Wrapper Chart Incompatibility

The `apps/cluster/coredns` wrapper chart attempted to manage CoreDNS but k3s already deploys CoreDNS with **immutable selectors**:

```yaml
# k3s CoreDNS Deployment (immutable)
spec:
  selector:
    matchLabels:
      k8s-app: kube-dns  # IMMUTABLE - cannot be changed
```

Helm chart tried to modify this, causing:

- ArgoCD sync failures
- kube-dns Service endpoint mapping destruction
- ConfigMap conflicts between wrapper chart and k3s

## The Fix

### 1. Fix kube-dns Service - Add UDP Port

**CRITICAL**: The Service must expose both UDP and TCP:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
spec:
  clusterIP: 10.43.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP  # REQUIRED for DNS queries
    targetPort: 53
  - name: dns-tcp
    port: 53
    protocol: TCP  # REQUIRED for zone transfers
    targetPort: 53
  selector:
    k8s-app: kube-dns
```

**Apply fix**:

```bash
kubectl delete service kube-dns -n kube-system
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
spec:
  clusterIP: 10.43.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
    targetPort: 53
  - name: dns-tcp
    port: 53
    protocol: TCP
    targetPort: 53
  selector:
    k8s-app: kube-dns
EOF
```

### 2. Disable CoreDNS Wrapper Chart Permanently

**Move to disabled directory**:

```bash
git mv argocd/apps/cluster/coredns.yaml argocd/disabled/cluster/coredns.yaml
git commit -m "fix(coredns): Disable wrapper chart permanently - incompatible with k3s"
```

### 3. Integrate with OPNsense Unbound DNS

k3s CoreDNS should forward to OPNsense VLAN30 Unbound (not WAN):

```bash
kubectl edit configmap coredns -n kube-system
```

**Add/modify forward block**:

```corefile
.:53 {
    errors
    health {
        lameduck 5s
    }
    ready

    # Static Proxmox hosts (required for Proxmox CSI)
    hosts {
        10.0.30.11 pve01.m0sh1.cc pve01
        10.0.10.11 pve01-vlan10.m0sh1.cc
        10.0.30.12 pve02.m0sh1.cc pve02
        10.0.10.12 pve02-vlan10.m0sh1.cc
        10.0.30.13 pve03.m0sh1.cc pve03
        10.0.10.13 pve03-vlan10.m0sh1.cc
        fallthrough
    }

    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
    }

    prometheus :9153

    # Forward to OPNsense VLAN30 Unbound (NOT WAN 10.0.0.10!)
    forward . 10.0.30.1 {
        except cluster.local in-addr.arpa ip6.arpa
    }

    cache 30
    loop
    reload
    loadbalance
}
```

### 4. Remove ArgoCD Tracking Annotations

Prevent wrapper chart from re-syncing CoreDNS:

```bash
kubectl annotate configmap coredns -n kube-system \
  argocd.argoproj.io/tracking-id- \
  --overwrite
```

### 5. Delete Wrapper Chart Artifacts

```bash
# Delete duplicate configmap created by wrapper chart
kubectl delete configmap coredns-custom -n kube-system --ignore-not-found
```

## Validation

### Test DNS Resolution

```bash
# Deploy test pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash

# Inside pod:
# Test internal DNS
dig argocd-redis.argocd.svc.cluster.local @10.43.0.10
nslookup argocd-redis.argocd.svc

# Test external DNS
dig google.com @10.43.0.10
nslookup google.com

# Test UDP vs TCP
dig argocd-redis.argocd.svc.cluster.local @10.43.0.10  # UDP (default)
dig +tcp argocd-redis.argocd.svc.cluster.local @10.43.0.10  # TCP
```

**Expected results**:

- Internal: Returns ClusterIP (e.g., 10.43.99.9)
- External: Returns public IP (e.g., 172.217.16.78)
- Both UDP and TCP work

### Verify kube-dns Service

```bash
kubectl get service kube-dns -n kube-system -o yaml
```

**Required**:

- ClusterIP: `10.43.0.10`
- Ports: UDP port 53 + TCP port 53
- Endpoints: CoreDNS pod IPs

### Check CoreDNS Health

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Should NOT see**:

- "plugin/loop: Loop detected"
- "no such host" errors
- Connection timeouts

## Prevention

### 1. Never Use CoreDNS Wrapper Chart with k3s

k3s manages CoreDNS natively. Do NOT attempt to:

- Deploy Helm charts that modify CoreDNS
- Change CoreDNS Deployment selectors
- Replace k3s CoreDNS with custom deployments

### 2. Always Expose UDP Port for DNS Services

```yaml
# WRONG - TCP only
ports:
- name: dns-tcp
  port: 53
  protocol: TCP

# CORRECT - Both UDP and TCP
ports:
- name: dns
  port: 53
  protocol: UDP  # Primary (queries)
- name: dns-tcp
  port: 53
  protocol: TCP  # Secondary (zone transfers)
```

### 3. Use Correct OPNsense DNS Forwarder

Kubernetes on VLAN30 must use VLAN30 Unbound:

- ✅ **Correct**: `10.0.30.1` (VLAN30 Unbound interface)
- ❌ **Wrong**: `10.0.0.10` (WAN, would create DNS loop)

### 4. Pin Proxmox Hosts in CoreDNS

Static host entries prevent bootstrap chicken-and-egg issues:

```corefile
hosts {
    10.0.30.11 pve01.m0sh1.cc pve01
    10.0.30.12 pve02.m0sh1.cc pve02
    10.0.30.13 pve03.m0sh1.cc pve03
    fallthrough
}
```

## Related Issues Fixed

- ✅ ArgoCD applications showing "Unknown" → Synced after DNS fix
- ✅ Proxmox CSI provisioning "no such host" → Resolved after static hosts added
- ✅ kube-dns Service endpoint mapping destroyed → Recreated with UDP+TCP
- ✅ CoreDNS wrapper chart tracking → Removed annotations, chart disabled

## References

- Commit: `10954ce7` - Disable wrapper chart, patch CoreDNS with static hosts
- Commit: `888a639` - Remove duplicate infra-root manifest
- Commit: `6b5459c` - Refactor to bootstrap-root + apps-root architecture
- Issue: kube-dns Service missing UDP port (manual recreation required)
- DNS Flow: Pod → kube-dns (10.43.0.10 UDP+TCP) → CoreDNS pod → OPNsense Unbound (10.0.30.1) → Internet
