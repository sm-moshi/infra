#!/usr/bin/env bash
set -euo pipefail

# Usage: ezfs-pool-report [POOL...]
#
# Prints a compact status/props overview for each ZFS pool:
# - size, alloc, free, health
# - ashift, autotrim, listsnapshots, readonly
# - underlying devices with full /dev path (from zpool status -P)

POOLS=("$@")

if [[ "${#POOLS[@]}" -eq 0 ]]; then
    mapfile -t POOLS < <(zpool list -H -o name 2>/dev/null || true)
fi

if [[ "${#POOLS[@]}" -eq 0 ]]; then
    echo "No pools found."
    exit 0
fi

human() {
    num="$1"
    awk -v b="$num" '
    function human(x) {
      s="BKMGTPEZY";i=1;
      while (x>=1024 && i<length(s)) {x/=1024;i++}
      return sprintf("%.1f%s", x, substr(s,i,1))
    }
    BEGIN {print human(b)}
  '
}

for pool in "${POOLS[@]}"; do
    echo "=== Pool: $pool ==="

    # Basic stats
    read -r _ size alloc free cap health _ <<<"$(zpool list -H -o name,size,alloc,free,cap,health -p "$pool")"

    echo "  Size:    $size  ($([[ "$size" =~ ^[0-9]+$ ]] && human "$size" || echo "$size"))"
    echo "  Alloc:   $alloc ($([[ "$alloc" =~ ^[0-9]+$ ]] && human "$alloc" || echo "$alloc"))"
    echo "  Free:    $free  ($([[ "$free" =~ ^[0-9]+$ ]] && human "$free" || echo "$free"))"
    echo "  Cap:     $cap"
    echo "  Health:  $health"

    # Key properties
    props=(ashift autotrim listsnapshots readonly)
    for p in "${props[@]}"; do
        val=$(zpool get -H -o value "$p" "$pool" 2>/dev/null || echo "-")
        echo "  $p: $(printf '%s' "$val")"
    done

    echo "  Devices:"
    # Dump from zpool status -P, only the leaf vdev lines (paths under /dev or by-id)
    zpool status -P "$pool" 2>/dev/null |
        awk '
      /^\t/ {
        gsub(/^\t+/, "", $1);
        # Heuristics: device lines often start with /dev/ or /dev/disk/by-*
        if ($1 ~ /^\/dev\//) {
          print "    - " $1
        }
      }
    '

    echo ""
done
