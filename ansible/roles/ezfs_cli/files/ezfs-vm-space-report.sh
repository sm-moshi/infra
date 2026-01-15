#!/usr/bin/env bash
set -euo pipefail

# Usage: ezfs-vm-space-report [POOL_PREFIX]
#
# Summarises ZFS space usage by Proxmox VM / CT.
# It reuses the same logic as zvol-map (vm-/subvol-<ID>-) but aggregates
# "zfs get -Hp used" per ID and prints a sorted table.

POOL_FILTER="${1:-}"

if [[ -n "$POOL_FILTER" ]]; then
    ZVOLS=$(zfs list -H -o name -t volume | awk -v p="$POOL_FILTER" '$0 ~ "^"p"/"')
else
    ZVOLS=$(zfs list -H -o name -t volume)
fi

declare -A USED_BYTES
declare -A TYPE_MAP
declare -A NAME_MAP

while read -r vol; do
    [[ -z "$vol" ]] && continue

    id=$(echo "$vol" | sed -n 's/.*\(vm-\|subvol-\)\([0-9]\+\)-.*/\2/p')
    [[ -z "$id" ]] && continue

    used=$(zfs get -Hp -o value used "$vol" 2>/dev/null || echo 0)
    USED_BYTES["$id"]=$((${USED_BYTES["$id"]:-0} + used))

    if [[ -z "${TYPE_MAP["$id"]:-}" || -z "${NAME_MAP["$id"]:-}" || "${NAME_MAP["$id"]}" = "-" ]]; then
        if qm config "$id" &>/dev/null; then
            TYPE_MAP["$id"]="VM"
            NAME_MAP["$id"]=$(qm config "$id" 2>/dev/null | awk -F: '/^name:/ {gsub(/^ +/, "", $2); print $2}')
        elif pct config "$id" &>/dev/null; then
            TYPE_MAP["$id"]="CT"
            NAME_MAP["$id"]=$(pct config "$id" 2>/dev/null | awk -F: '/^hostname:/ {gsub(/^ +/, "", $2); print $2}')
        else
            TYPE_MAP["$id"]="-"
            NAME_MAP["$id"]="-"
        fi
        [[ -z "${NAME_MAP["$id"]}" ]] && NAME_MAP["$id"]="-"
    fi
done <<<"$ZVOLS"

# Nothing found
if [[ "${#USED_BYTES[@]}" -eq 0 ]]; then
    echo "No VM/CT zvols found."
    exit 0
fi

# Sort IDs by used bytes descending
mapfile -t SORTED_IDS < <(
    for id in "${!USED_BYTES[@]}"; do
        printf "%s %s\n" "${USED_BYTES["$id"]}" "$id"
    done | sort -rn | awk '{print $2}'
)

printf "%-5s  %-3s  %-24s  %-10s\n" "ID" "T" "NAME" "USED"
printf "%-5s  %-3s  %-24s  %-10s\n" "-----" "---" "------------------------" "----------"

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

for id in "${SORTED_IDS[@]}"; do
    used="${USED_BYTES["$id"]}"
    type="${TYPE_MAP["$id"]:-"-"}"
    name="${NAME_MAP["$id"]:-"-"}"
    printf "%-5s  %-3s  %-24s  %-10s\n" "$id" "$type" "$name" "$(human "$used")"
done
