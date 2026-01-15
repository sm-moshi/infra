#!/usr/bin/env bash
set -euo pipefail

# PURPOSE:
#   Wipe / partition / attach a new SLOG + L2ARC device for the "timemachine" pool.
#   Target disk: /dev/disk/by-id/ata-INTENSO_AA000000000000004028 (currently /dev/sdd).
#   Layout (128 GB):
#     - part1: 16G  -> SLOG (mirrors existing SLOG)
#     - part2: rest -> L2ARC
#
# WARNINGS:
#   - DESTRUCTIVE: zaps the partition table on the target disk.
#   - Run on pve-01 only. Double-check the by-id path before proceeding.
#   - SLOG handling: attaches the new SLOG as a mirror to the existing one.
#     It does NOT detach the old SLOG; you can detach manually after resilver if desired.

DISK="/dev/disk/by-id/ata-INTENSO_AA000000000000004028"
# Existing SLOG device to mirror (from the current Micron partitioning):
OLD_LOG="/dev/disk/by-id/ata-MTFDHBA256TCK-1AS1AABHA_UHPVN01J7D02Y5-part1"

read -r -p "This will ERASE all data on $DISK and modify pool 'timemachine'. Continue? [yes/NO] " ans
[[ $ans == "yes" ]] || {
    echo "Aborted."
    exit 1
}

echo "Wiping partition table on $DISK ..."
sgdisk -Z "$DISK"

echo "Creating SLOG (16G, BF08) and L2ARC (remainder, BF00) partitions ..."
sgdisk -n1:2048:+16G -t1:BF08 "$DISK" # SLOG
sgdisk -n2:0:0 -t2:BF00 "$DISK"       # L2ARC

echo "Reloading partition table ..."
partprobe "$DISK"

SLOG_PART="${DISK}-part1"
L2ARC_PART="${DISK}-part2"

# Let udev settle so -partN paths appear
udevadm settle || true
sleep 1

# Final confirmation before touching the pool
read -r -p "Proceed to attach SLOG and add L2ARC to pool 'timemachine'? [yes/NO] " ans2
[[ $ans2 == "yes" ]] || {
    echo "Aborted before pool modification."
    exit 1
}

echo "Attaching new SLOG as mirror to existing log device..."
zpool attach timemachine "$OLD_LOG" "$SLOG_PART"

echo "Adding L2ARC device..."
zpool add timemachine cache "$L2ARC_PART"

echo
echo "Current zpool status (timemachine):"
zpool status -v timemachine

echo
echo "Done. If you want to retire $OLD_LOG after resilver completes, run:"
echo "  zpool detach timemachine $OLD_LOG"
