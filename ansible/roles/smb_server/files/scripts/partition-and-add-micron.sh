#!/usr/bin/env bash
set -euo pipefail

# PURPOSE:
#   Partition the Micron NVMe/HDD used for timemachine/datengrab and attach SLOG + L2ARC
#   devices to both pools in one run. This replaces the old partition-micron, add-slog,
#   and add-l2arc scripts.
#
# DEFAULT TARGET:
#   DISK=/dev/disk/by-id/ata-MTFDHBA256TCK-1AS1AABHA_UHPVN01J7D02Y5 (currently /dev/sdb)
#   Layout (256 GB class):
#     - part1: 16G  -> timemachine SLOG (BF08)
#     - part2: 16G  -> datengrab SLOG (BF08)
#     - part3: 100G -> timemachine L2ARC (BF00)
#     - part4: 100G -> datengrab L2ARC (BF00)
#
# WARNINGS:
#   - DESTRUCTIVE: wipes partition table on $DISK.
#   - Run on pve-01 only. Double-check the by-id path.
#   - If pools already have these devices, you may need to detach/remove before re-adding.

DISK="/dev/disk/by-id/ata-MTFDHBA256TCK-1AS1AABHA_UHPVN01J7D02Y5"

read -r -p "This will ERASE all data on $DISK and modify pools timemachine and datengrab. Continue? [yes/NO] " ans
[[ $ans == "yes" ]] || {
  echo "Aborted."
  exit 1
}

echo "Using disk: $DISK"
sgdisk -p "$DISK" || true

echo "Zapping existing partition table..."
sgdisk -Z "$DISK"

echo "Creating partitions..."
sgdisk -n1:2048:+16G -t1:BF08 "$DISK" # timemachine SLOG
sgdisk -n2:0:+16G -t2:BF08 "$DISK"    # datengrab SLOG
sgdisk -n3:0:+100G -t3:BF00 "$DISK"   # timemachine L2ARC
sgdisk -n4:0:+100G -t4:BF00 "$DISK"   # datengrab L2ARC
sgdisk -p "$DISK"

echo "Reloading partition table..."
partprobe "$DISK" || true
udevadm settle || true
sleep 1

SLOG_TM="${DISK}-part1"
SLOG_DG="${DISK}-part2"
L2ARC_TM="${DISK}-part3"
L2ARC_DG="${DISK}-part4"

add_log_or_mirror() {
  local pool="$1"
  local newdev="$2"
  if ! zpool status "$pool" >/dev/null 2>&1; then
    echo "Pool $pool not found; skipping log add."
    return
  fi

  # Find first existing log leaf device (non-mirror label) under 'logs'
  local existing_log=""
  existing_log=$(zpool status -v "$pool" | awk '
    /logs/ {inlogs=1; next}
    inlogs && NF==0 {inlogs=0; next}
    inlogs {
      gsub(/^[[:space:]]+/, "", $1);
      if ($1 ~ /^mirror/) {next}
      if ($1 ~ /^logs/) {next}
      print $1; exit
    }
  ')

  if [[ -n $existing_log ]]; then
    echo "Attaching $newdev as mirror to existing log $existing_log on $pool ..."
    zpool attach "$pool" "$existing_log" "$newdev"
  else
    echo "Adding log $newdev to $pool ..."
    zpool add "$pool" log "$newdev"
  fi
}

add_cache() {
  local pool="$1"
  local newdev="$2"
  if ! zpool status "$pool" >/dev/null 2>&1; then
    echo "Pool $pool not found; skipping cache add."
    return
  fi
  echo "Adding cache $newdev to $pool ..."
  zpool add "$pool" cache "$newdev"
}

read -r -p "Proceed to attach/mirror SLOG and add L2ARC to pools now? [yes/NO] " ans2
[[ $ans2 == "yes" ]] || {
  echo "Aborted before pool modification."
  exit 1
}

add_log_or_mirror timemachine "$SLOG_TM"
add_log_or_mirror datengrab "$SLOG_DG"

add_cache timemachine "$L2ARC_TM"
add_cache datengrab "$L2ARC_DG"

echo
echo "Status: timemachine"
zpool status -v timemachine
echo
echo "Status: datengrab"
zpool status -v datengrab
