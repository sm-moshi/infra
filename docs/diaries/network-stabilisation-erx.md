# Network Stabilisation: EdgeRouter X Placement

**Status:** Planning
**Date:** 2026-03-03
**Purpose:** Diagnose intermittent network instability and evaluate EdgeRouter X placement options

> **See also:** [docs/network-architecture.md](../network-architecture.md) for the comprehensive network architecture.

---

## Problem Statement

The m0sh1.cc homelab suffers from intermittent instability:

- Speeds suddenly dropping to ~20 kbit/s
- Internet connection dying for minutes at a time
- Flaky DNS resolution
- Applications failing due to dropped connectivity

**Available hardware:** Ubiquiti EdgeRouter X (ER-X, 5x Gbit RJ45, Port 1 PoE-in, Port 5 PoE-out)
**ISP:** Telekom FTTH, 275 Mbit/s down / 60 Mbit/s up, PPPoE (FWSJ01 concentrator)
**Constraint:** Speedport Smart 4 Plus has built-in fibre ONT — cannot be bypassed without a separate SFP ONT

---

## Root Cause Analysis

### Source 1: Speedport System Log (`Speedport_Smart_4 Plus_2026-03-03_SystemMessages.txt`)

#### Finding 1: OPNsense WAN Link Flapping (LS001 on LAN3) — MOST LIKELY ROOT CAUSE

LAN3 = pve-01 NIC1 (OPNsense WAN, vtnet0, 10.0.0.100). This link is repeatedly going up/down:

```text
2026-02-25  06:27  LAN3 (OPNsense WAN) flap -> DHCP re-lease at 06:28
2026-02-25  10:40  LAN3 (OPNsense WAN) flap
2026-02-25  22:07  LAN3 (OPNsense WAN) flap
2026-02-25  22:08  LAN3 (OPNsense WAN) flap (1 min later!)
2026-02-25  22:18  LAN3 (OPNsense WAN) flap (10 min later)
2026-01-22  06:44  LAN3 (OPNsense WAN) flap
2026-01-22  08:59  LAN3 (OPNsense WAN) flap
2026-01-22  11:33  LAN3 (OPNsense WAN) flap
2026-01-22  21:35  LAN3 (OPNsense WAN) flap
```

**This directly explains all symptoms.** Every time the OPNsense WAN link drops:

1. OPNsense loses its WAN gateway (10.0.0.1)
2. ALL internet-bound traffic from all VLANs stops
3. Unbound DNS queries to Cloudflare DoT (1.1.1.1:853) fail — DNS goes flaky
4. Applications across the cluster lose internet — speed effectively drops to 0/20 kbit
5. OPNsense re-acquires DHCP lease when link returns (confirmed: `opn-WAN bc:24:11:3d:33:2a 10.0.0.100`)

#### Finding 2: DNS Rebind Protection Blocking Lab Traffic (DRP003)

The Speedport was **actively filtering DNS responses** for `*.m0sh1.cc` domains because they resolve to internal IPs (10.0.30.10, 10.0.10.11, etc.). The Speedport treats this as a "DNS rebind attack":

```text
(DRP003) harbor.m0sh1.cc — filtered as DNS rebind
(DRP003) basic-memory.m0sh1.cc — filtered
(DRP003) headlamp.m0sh1.cc — filtered
(DRP003) pve01.m0sh1.cc — filtered
(DRP003) scanopy.m0sh1.cc — filtered
(DRP003) livesync.m0sh1.cc — filtered
(DRP003) renovate.m0sh1.cc — filtered
(DRP003) netbox.m0sh1.cc — filtered
```

**Status:** Disabled on 2026-02-27 (`DRP002`), but **re-enables after each Speedport reboot**. Affects any device using Speedport DNS (WiFi clients getting DHCP from Speedport with DNS=10.0.0.1). Lab traffic via OPNsense Unbound is NOT affected.

#### Finding 3: Frequent User-Triggered Reboots (B102)

Seven reboots in ~2 weeks — restarting the Speedport to fix stability issues:

```text
2026-02-25  21:19  Reboot triggered
2026-02-25  21:49  Reboot triggered (30 min later — first didn't help?)
2026-02-26  12:15  Reboot triggered
2026-02-26  13:26  Reboot triggered (71 min later)
2026-02-27  15:40  Reboot triggered
2026-02-18  01:24  Reboot triggered
2026-01-21  21:57  Reboot triggered
```

Each reboot causes: full PPPoE re-establishment (~20 sec), new public IP, VoIP re-registration, and **re-enables DNS rebind protection**.

#### Other Observations

- **PPPoE Zwangstrennung** (forced daily reconnect): One R009 event on 2026-02-25 09:06 — normal Telekom behaviour, 8-second reconnect
- **SYN FLOOD detections**: External port scans from AWS IPs (13.59.x, 18.219.x, 172.235.x) — handled by Speedport firewall, not stability-related
- **OPNsense traffic prioritisation**: `PDL001: Priorisierung fuer opn-WAN BC:24:11:3D:33:2A aktiviert` — OPNsense gets priority on Speedport
- **No fibre/PPPoE drops logged** during normal operation — connection itself appears stable between reboots

### Source 2: pve-01 dmesg

#### Finding 4: MAC Address Reflection on vmbr0 (Bridge Loop Indicator)

pve-01 dmesg reveals the bridge is receiving packets with **its own MAC address** as the source, coming from the physical NIC:

```text
vmbr0: received packet on nic1 with own address as source address (addr:a0:ce:c8:19:e8:e8, vlan:1)
vmbrWAN: received packet on nic2 with own address as source address (addr:68:da:73:a0:85:f7, vlan:0)
```

These messages appear in bursts (40+ messages in a ~2-minute window around T+101931s / ~28h after boot). This means the TP-Link SG108 switch (or another device) is **reflecting frames back** with the bridge's own MAC address. Possible causes:

- The switch is mirroring/reflecting frames (unlikely without explicit config)
- A VM using the bridge MAC is sending frames that loop back through the switch
- Cilium L2 announcements using the bridge MAC, bounced by the switch

This is a **Layer 2 loop indicator** and could contribute to or cause the link flapping seen in the Speedport logs.

#### Finding 5: pve-01 NIC Hardware

```text
e1000e 0000:00:1f.6 eth0 -> nic0: Built-in Intel PRO/1000 (PCI Express)
r8152 2-1.1:1.0 eth0 -> nic1: Realtek USB NIC (vmbr0, LAN trunk)
cdc_ncm 2-8.1:2.0 eth0 -> nic2: USB CDC NCM NIC (vmbrWAN, Speedport)
```

**Both NICs carrying critical traffic are USB-attached.** USB NICs are inherently less reliable than PCIe NICs — they share USB bus bandwidth, can have driver instability under load, and USB hot-plug events can cause link drops.

The WAN NIC (nic2/cdc_ncm) being USB is a plausible explanation for the link flapping: USB bus contention, power management, or CDC NCM driver issues could cause momentary link drops that the Speedport registers as LAN3 flaps.

#### Finding 6: ICMPv6 Neighbour Advertisement Conflicts

```text
ICMPv6: NA: bc:24:11:ff:4c:e1 advertised our address fd00:1:30::11 on vmbr0.30!
ICMPv6: NA: bc:24:11:84:ca:de advertised our address fd00:1:30::11 on vmbr0.30!
```

Multiple K8s nodes are advertising pve-01's VLAN 30 IP (`fd00:1:30::11`) via Cilium L2 announcements. This is the known bridge hairpin issue (pve-01 has an IP on `vmbr0.30` that conflicts with Cilium L2 announcements). Not directly stability-related but wastes NDP processing.

#### No NIC errors found

No `error`, `reset`, or `timeout` messages from the e1000e, r8152, or cdc_ncm drivers. The NICs themselves appear healthy — the issue is more likely at the USB bus or cable/port level.

### Root Cause Assessment

| Candidate | Likelihood | Evidence |
|-----------|-----------|----------|
| **OPNsense WAN link flapping** | **HIGHEST** | 9+ link drops on Speedport LAN3 = OPNsense WAN NIC |
| **USB WAN NIC (cdc_ncm) instability** | **HIGH** | USB NIC for WAN is inherently fragile; link drops correlate |
| **Cable fault (Speedport LAN3 -> pve-01)** | **HIGH** | LAN3 flaps but LAN2 is stable — same switch, different cable |
| DNS rebind filtering (Speedport) | **HIGH** for WiFi DNS | 30+ DRP003 entries blocking `*.m0sh1.cc` |
| MAC address reflection (L2 loop) | **POSSIBLE** | Bursts of "own address as source" on vmbr0 |
| OPNsense VM contention | **POSSIBLE** | Could cause USB NIC driver resets under load |
| Bufferbloat on Speedport | **POSSIBLE** | Would compound the WAN link issues |
| Speedport LAN3 port hardware fault | **POSSIBLE** | Can test by moving to LAN4 |

---

## Current Physical Topology

```text
                    Internet (Telekom FTTH, 275/60 Mbit/s, PPPoE)
                        |
                        v
              +----------------------+
              |  Speedport Smart     |
              |  4 Plus (built-in    |
              |  fibre ONT)          |
              |  10.0.0.1            |
              |                      |
              |  WiFi (WLAN-373657)  |
              |  native VLAN         |
              |                      |
              |  LAN2     LAN3      |
              +--+----------+-------+
                 |          |
                 |          |  <-- FLAPPING! (9+ link drops)
                 |          |
        +--------+          +----------+
        |                              |
        v                              v
  +--------------+             +----------+
  |  TP-Link     |             |  pve-01  |
  |  SG108 Switch|             |  nic0    |
  |  10.0.0.2    |             | (e1000e  |
  |              |             |  PCIe)   |
  |  P1 <- Speedport LAN2     | vmbrWAN  |
  |  P2 <- pve-01 nic1        | 10.0.0.  |
  |       (r8152 USB)          |  100     |
  |       vmbr0 (LAN trunk)   |          |
  |  P3 -> pve-02  |          |  nic1    |
  |  P4 -> pve-03  |          | (r8152   |
  |  P5 -> Mac dock|----------| USB)     |
  |  ...           |          | vmbr0    |
  +----------------+          | 10.0.10. |
        |                     |  11      |
  802.1Q trunk                +----------+
  VLANs 10, 20, 30

  nic2 (cdc_ncm, USB) — unused (was WAN, replaced 2026-03-03)
```

---

## EdgeRouter X Placement Options

### Option A: ERX as WAN Stabiliser (Between Speedport and OPNsense) — RECOMMENDED

**Concept:** ERX sits between the Speedport and OPNsense, providing hardware-offloaded NAT, SQM/QoS, and connection monitoring. OPNsense's WAN moves from Speedport to ERX.

```text
                Internet (Telekom FTTH, PPPoE)
                    |
                    v
          +----------------------+
          |  Speedport Smart     |
          |  4 Plus              |
          |  10.0.0.1            |
          |  WiFi (native)       |
          |  DMZ -> 10.0.0.50   |
          |                      |
          |  LAN2     LAN3      |
          +--+----------+-------+
             |          |
             |          +-- now goes to ERX instead of pve-01
             |
             |          +-----------------+
             |          |  EdgeRouter X   |
             |          |                 |
             |          |  eth0 (WAN)     |
             |          |  10.0.0.50/24   |
             |          |  GW: 10.0.0.1   |
             |          |                 |
             |          |  SQM: cake      | <-- 200 Mbit/s cap
             |          |  HW offload: ON | <-- (OFF if SQM on)
             |          |                 |
             |          |  eth1 (transit) |
             |          |  172.16.0.1/30  |
             |          +--------+--------+
             |                   |
             v                   v
    +--------------+       +----------+
    |  TP-Link     |       |  pve-01  |
    |  SG108 Switch|       |  nic2    |
    |              |       | (OPNsense|
    |  P1 <- Speedport LAN2  WAN)    |
    |  P2 <- pve-01 nic1  | 172.16.  |
    |  P3-5 -> pve-02/03/ |  0.2/30  |
    |          Mac  |      | GW:      |
    +--------------+       | 172.16.  |
          |                |  0.1     |
    802.1Q trunk           |          |
    VLANs 10,20,30         |  nic1    |
          |                | 10.0.10. |
          +----------------+  11      |
                           +----------+
                   OPNsense LAN (trunk)
                   ALL unchanged
```

**Changes required:**

- Speedport: Set DMZ host to 10.0.0.50
- ERX eth0: Static 10.0.0.50/24, gateway 10.0.0.1
- ERX eth1: 172.16.0.1/30 (transit to OPNsense)
- OPNsense WAN: Change from 10.0.0.100 -> 172.16.0.2/30, gateway 172.16.0.1
- OPNsense: Everything else unchanged (VLANs, Unbound, Suricata, CrowdSec, Tailscale)

**SQM trade-off at 275 Mbit/s:**

- SQM ON: Fixes bufferbloat but caps throughput at ~200 Mbit/s (ERX hardware limit with SQM)
- SQM OFF + HW offload ON: Full 275 Mbit/s but no bufferbloat fix
- Recommendation: Start with SQM ON at 200/55 Mbit/s. If bufferbloat isn't the issue, switch to HW offload.

**Pros:**

- Minimal disruption — OPNsense VLAN/firewall/DNS stays identical
- Isolates Speedport from OPNsense — ERX detects/logs link issues on its own stable cable
- Hardware connection watchdog auto-restarts WAN if link stalls
- SQM for bufferbloat (likely cause of "20 kbit/s" drops under load)
- Easy rollback — revert OPNsense WAN to 10.0.0.100, unplug ERX

**Cons:**

- Triple NAT (ERX -> Speedport -> Internet) — DMZ mitigates this for inbound
- SQM limits throughput to ~200 Mbit/s (lose ~75 Mbit/s)
- Extra hop (negligible latency)

### Option B: ERX Replaces OPNsense Entirely

**Concept:** ERX becomes the primary router, firewall, and VLAN gateway. OPNsense VM is decommissioned.

```text
                Internet (Telekom FTTH, PPPoE)
                    |
                    v
          +----------------------+
          |  Speedport Smart     |
          |  4 Plus              |
          |  10.0.0.1            |
          |  DMZ -> 10.0.0.50   |
          |  LAN3                |
          +----------+-----------+
                     |
                     v
          +----------------------+
          |  EdgeRouter X        |
          |                      |
          |  eth0 (WAN)          |
          |  10.0.0.50/24        |
          |  HW NAT offload     |
          |  ~940 Mbit/s         |
          |                      |
          |  eth1 (trunk)        | <-- 802.1Q to switch
          |  eth1       10.0.0.10| <-- native (home LAN GW)
          |  eth1.10   10.0.10.1 | <-- VLAN 10 (infra)
          |  eth1.20   10.0.20.1 | <-- VLAN 20 (k8s)
          |  eth1.30   10.0.30.1 | <-- VLAN 30 (LB)
          |                      |
          |  eth2-4 (spare)      |
          +----------+-----------+
                     |
                     | 802.1Q trunk (all VLANs)
                     v
          +----------------------+
          |  TP-Link SG108 Switch|
          |                      |
          |  P1 <- ERX eth1     |
          |  P2 -> pve-01       |
          |  P3 -> pve-02       |
          |  P4 -> pve-03       |
          |  P5 -> Mac dock     |
          +----------------------+
```

**Pros:**

- Eliminates virtualised router — dedicated hardware, always-on
- HW NAT handles full 275 Mbit/s easily (up to ~940 Mbit/s)
- Frees pve-01 resources (OPNsense uses 4 GB RAM, 8 vCPU)
- Simpler architecture

**Cons:**

- **Loses:** Suricata IDS, CrowdSec, Unbound DoT, DNSSEC, firewall GUI, Hubble integration, syslog->Loki, Tailscale subnet router, all monitoring
- ERX has ~256 MB RAM, basic dnsmasq (no DoT/DNSSEC), CLI-only firewall
- **Massive reconfiguration** — every VLAN, DHCP, DNS override, firewall rule recreated
- Entire observability pipeline must be redesigned

**Best for:** Nuclear option if OPNsense VM itself is the root cause. **Highest risk, highest effort.**

### Option C: ERX as WAN Gateway + OPNsense as Internal Firewall (Split Duties)

**Concept:** ERX handles WAN (NAT, SQM, connection stability). OPNsense handles internal only (VLANs, firewall, IDS, DNS, Tailscale).

```text
                Internet (Telekom FTTH, PPPoE)
                    |
                    v
          +----------------------+
          |  Speedport Smart     |
          |  4 Plus              |
          |  10.0.0.1            |
          |  DMZ -> 10.0.0.50   |
          |  LAN3                |
          +----------+-----------+
                     |
                     v
          +----------------------+
          |  EdgeRouter X        |
          |                      |
          |  eth0 (WAN)          |
          |  10.0.0.50/24        |
          |  NAT + SQM           |
          |                      |
          |  eth1 (to switch)    | <-- native VLAN LAN
          |  10.0.0.1/24         |   WiFi clients use this as GW
          |                      |
          |  eth2 (to OPNsense)  | <-- transit link
          |  172.16.0.1/30       |
          |                      |
          |  Static routes:      |
          |  10.0.10.0/24 -> .2  |
          |  10.0.20.0/24 -> .2  |
          |  10.0.30.0/24 -> .2  |
          +---+----------+-------+
              |          |
              v          v
       +----------+  +--------------+
       |  pve-01  |  |  TP-Link     |
       |  nic2    |  |  SG108 Switch|
       | (OPNsense|  |              |
       |  uplink) |  |  P1 <- ERX eth1
       | 172.16.  |  |  P2 <- pve-01 nic1 (OPNsense trunk)
       |  0.2/30  |  |  P3-5 -> pve-02/03/Mac
       | GW:      |  +--------------+
       | 172.16.  |------+
       |  0.1     |  OPNsense LAN (trunk)
       |          |
       |  nic1    |  VLAN gateways (unchanged):
       | (trunk)  |  10.0.10.1 (VLAN 10)
       | 10.0.10.1|  10.0.20.1 (VLAN 20)
       | 10.0.20.1|  10.0.30.1 (VLAN 30)
       | 10.0.30.1|
       +----------+

Traffic flows:
  K8s pod -> OPNsense (VLAN route) -> ERX (NAT) -> Speedport -> Internet
  WiFi    -> ERX (direct NAT) -> Speedport -> Internet
  WiFi    -> OPNsense (if accessing VLANs) -> internal route
```

**Pros:**

- SQM on dedicated hardware for bufferbloat
- OPNsense no longer does WAN NAT — frees CPU for IDS/DNS
- Keeps ALL OPNsense features (Suricata, CrowdSec, Unbound DoT, Tailscale, syslog)
- Clear separation: ERX = WAN stability, OPNsense = security + internal routing

**Cons:**

- Most complex config of the three
- Two routing hops for VLAN->internet (pod -> OPNsense -> ERX -> Speedport)
- WiFi clients lose OPNsense firewall/IDS for direct internet (only ERX basic firewall)
- ERX needs static routes for all internal subnets
- Potential asymmetric routing if not careful
- SQM still caps at ~200 Mbit/s

**Best for:** Keeping full OPNsense features while offloading WAN to hardware. **Medium complexity.**

---

## Recommendation

### Step 0 — Free diagnostics before deploying anything

1. **Swap the Speedport LAN3 -> pve-01 cable.** The OPNsense WAN link is confirmed flapping 9+ times. A bad cable is the simplest explanation and costs nothing to fix.
2. **Try Speedport LAN4 instead of LAN3** — rules out a faulty Speedport port.
3. **Check `dmesg` on pve-01** for NIC/bridge errors: `dmesg | grep -i 'error\|link\|eth\|virtio\|vmbr'`
4. **Investigate USB WAN NIC** — the cdc_ncm USB NIC for WAN is inherently less stable than PCIe. Consider whether the unused e1000e PCIe NIC (nic0) can replace it.
5. **Investigate MAC reflection** — the "own address as source" messages on vmbr0 suggest the switch is bouncing frames. Check STP/loop protection settings on the TP-Link SG108.
6. **Permanently disable DNS rebind protection** on Speedport (it re-enables on every reboot!). Or better: ensure no device uses Speedport DNS — set WiFi DHCP to hand out OPNsense (10.0.0.10) as DNS.
7. **Run a bufferbloat test** at `waveform.com/tools/bufferbloat` from a wired device — if grade is C/D/F, SQM will help enormously.

### Step 1 — Deploy Option A (ERX as WAN Stabiliser)

Even if the cable swap fixes the flapping, the ERX provides lasting stability improvements:

1. **Lowest risk** — OPNsense VLAN/DNS/firewall config stays identical
2. **Isolates Speedport from OPNsense** — if LAN3/cable flaps again, it only affects the ERX->pve-01 transit link, and the ERX can detect and log it
3. **SQM for bufferbloat** — likely root cause of "20 kbit" speed drops under load
4. **Easy rollback** — revert OPNsense WAN to 10.0.0.100, unplug ERX
5. **Stepping stone** — can evolve to Option C later if more separation is needed

### If Option A doesn't fix it

The root cause is likely OPNsense VM contention on pve-01 or Proxmox USB NIC driver issues -> escalate to Option C (split duties) to reduce OPNsense load, or Option B (replace OPNsense) if the VM itself is unreliable.

### Key insight from logs

The ERX is most valuable as an **isolation layer** between the Speedport and pve-01. Currently, any issue on the Speedport LAN3 port or the cable directly kills ALL internet for every VLAN. With the ERX in between, the ERX maintains its own stable link to the Speedport, and the transit link to OPNsense is on a completely different cable and port.

---

## Pre-Deployment Diagnostics Checklist

- [ ] Cable test: Swap the Speedport LAN3 -> pve-01 NIC1 cable
- [ ] Port test: Move pve-01 from Speedport LAN3 to LAN4
- [x] pve-01 NIC: Check `dmesg` for driver errors (done — see Finding 4 & 5 above)
- [ ] OPNsense load: `top -P` in FreeBSD shell during drops
- [ ] Unbound stats: OPNsense -> Services -> Unbound -> Statistics — query latency?
- [x] Bufferbloat test: Grade B — NOT the primary cause (see below)
- [ ] DNS rebind: Confirm DNS rebind protection is OFF on Speedport
- [x] USB NIC investigation: nic0 (e1000e) self-test PASSED, swapping to PCIe (see below)
- [ ] MAC reflection: Check TP-Link SG108 loop protection / STP settings

---

## Bufferbloat Test Results (2026-03-03)

Tested from wired Mac via `waveform.com/tools/bufferbloat`:

| Metric | Value | Assessment |
|--------|-------|------------|
| Grade | **B** | Moderate — not the root cause |
| Unloaded latency | 24 ms | Normal for double-NAT |
| Download bloat | **+0 ms** | Excellent — zero bufferbloat on download |
| Upload bloat | +32 ms | Mild — noticeable for gaming, not catastrophic |
| Download speed | 257.1 Mbps | ~93% of 275 Mbps line rate |
| Upload speed | 56.9 Mbps | ~95% of 60 Mbps line rate |

**Conclusion:** Bufferbloat is NOT causing the "20 kbit/s" drops. A +32 ms upload
penalty is annoying for real-time apps but cannot explain speeds dropping to zero or
connections dying for minutes. Speeds are near line rate when the link is up. This
strongly reinforces the WAN link flapping as the primary cause. SQM on the ERX would
reduce the priority of that feature — HW offload (full speed) is preferable to SQM.

---

## pve-01 NIC Diagnostics (2026-03-03)

### e1000e Self-Test (nic0 — Intel I219-LM)

| Test | Result |
|------|--------|
| Register test | **PASS** |
| EEPROM test | **PASS** |
| Interrupt test | **PASS** |
| Loopback test | **PASS** |
| Link test | FAIL (no cable — expected) |

**Hardware is healthy.** All internal tests pass; link test fails only because
nothing is plugged in.

### EEE (Energy Efficient Ethernet) — the original problem

The e1000e was previously abandoned due to link flapping. Analysis shows **EEE was
the likely cause**, and the mitigation was broken:

- `/etc/modprobe.d/e1000e.conf` has `EEE=0` but the driver logs `unknown parameter
  'EEE' ignored` — the module parameter does not exist in current driver versions
- `ethtool --show-eee` shows the NIC still **advertises EEE** on 100baseT/1000baseT
- The Ansible `proxmox-network-ethtool.service` runs `ethtool --set-eee nic0 eee off`
  which DOES work, but runs `After=network.target` — after the bridge is already up

**Fix applied:** Added `pre-up ethtool --set-eee nic0 eee off || true` to the
vmbrWAN bridge stanza. This disables EEE **before** link negotiation, eliminating the
boot race. The systemd service provides belt-and-suspenders coverage.

### USB NIC Error Counters

| Metric | nic0 (e1000e, unused) | nic1 (r8152, LAN) | nic2 (cdc_ncm, WAN) |
|--------|----------------------|-------------------|---------------------|
| Carrier changes | 1 (probe only) | 4 | 4 |
| rx_missed | 0 | **26,376** | n/a |
| tx_errors | 0 | 2 | n/a |
| tx_reason_timeout | n/a | n/a | **6,673,023** |
| tx_reason_ntb_full | n/a | n/a | 314,516 |

**nic2 (WAN)** has **6.7 million transmit timeouts** — the CDC NCM USB driver is
failing to send packets on time. This directly causes the intermittent drops.

### Decision: Swap vmbrWAN from USB to PCIe

Changed `ansible/inventory/host_vars/pve01.yaml`:

- `vmbrWAN` bridge-ports: `nic2` (cdc_ncm USB) -> `nic0` (e1000e PCIe)
- Added `pre-up: ethtool --set-eee nic0 eee off || true`
- Existing ethtool systemd service already targets nic0

**Physical action required:** Move the Ethernet cable from pve-01's USB NIC
(68:da:73:a0:85:f7) to the built-in RJ45 port (7c:57:58:26:69:1b), then run
the Ansible role and reboot.

---

## pve-01 NIC Inventory

| Kernel Name | Renamed To | Driver | Bus | Bridge | Role |
|-------------|-----------|--------|-----|--------|------|
| eth0 (first) | nic0 | e1000e | PCIe (00:1f.6) | vmbrWAN | **WAN** (Speedport LAN3, 10.0.0.100) |
| eth0 (second) | nic1 | r8152 | USB (2-1.1:1.0) | vmbr0 | LAN trunk (VLANs 10/20/30 + native) |
| eth0 (third) | nic2 | cdc_ncm | USB (2-8.1:2.0) | — | **Unused** (was WAN) |
