# Scanopy Daemon ClusterIP Pinning Exception

**Date:** 2026-02-16
**Status:** Active
**AGENTS.md §4.1 Exception:** ClusterIP pinning required

## Problem

The Scanopy daemon binary (statically compiled musl/Rust) embeds
[hickory-resolver](https://github.com/hickory-dns/hickory-dns) for DNS
resolution. This resolver sends paired A + AAAA queries and treats an AAAA
NXDOMAIN response as a fatal DNS error, even when the A query succeeds.

In our cluster, CoreDNS returns NXDOMAIN for AAAA queries on Service names
because no IPv6 addresses exist. This causes hickory-resolver to fail the
entire resolution — the daemon binary never issues a TCP `connect()` call.

**Evidence (strace):** DNS A query for `scanopy-scanopy.apps.svc.cluster.local`
returns the ClusterIP successfully (rcode 0), but the paired AAAA query returns
NXDOMAIN (rcode 3). hickory-resolver aborts, and no `connect()` syscall is
ever made.

This affects both internal Service DNS and external domain names.

## Workaround

Pin `SCANOPY_SERVER_URL` to the Scanopy Service ClusterIP (`10.43.41.175:60072`)
directly, bypassing DNS resolution entirely.

```yaml
# apps/user/scanopy/values.yaml
daemon:
  inCluster:
    serverUrl: "http://10.43.41.175:60072"
```

## Risks

- If the Scanopy Service is recreated, the ClusterIP may change. The
  `values.yaml` must be updated to match.
- The ClusterIP is stable across pod restarts and redeployments as long as the
  Service object itself is not deleted.

## Alternatives Considered

1. **Service DNS (preferred):** Cannot work due to hickory-resolver AAAA bug.
2. **hostAliases:** Does not help — hickory-resolver bypasses `/etc/hosts` and
   sends DNS queries directly via UDP sockets.
3. **External HTTPS URL:** Same hickory-resolver failure with additional TLS
   complexity.
4. **glibc-based image:** Not available — upstream ships musl-only binaries.
5. **Upstream fix:** Filed as a potential hickory-resolver issue, but no
   timeline for resolution.

## Resolution Path

Remove this workaround when either:

- Upstream Scanopy switches to a resolver that handles AAAA NXDOMAIN gracefully
- hickory-resolver fixes dual-stack DNS behavior
- CoreDNS is configured to return NODATA instead of NXDOMAIN for AAAA queries
