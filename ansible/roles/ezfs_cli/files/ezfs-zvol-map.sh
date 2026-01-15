#!/usr/bin/env bash
set -euo pipefail

# Usage: ezfs-zvol-map [POOL_PREFIX]
# If POOL_PREFIX is given (e.g. "vmstore"), only zvols under that pool are shown.

POOL_FILTER="${1:-}"

if [[ -n "$POOL_FILTER" ]]; then
    ZVOLS=$(zfs list -H -o name -t volume | awk -v p="$POOL_FILTER" '$0 ~ "^"p"/"')
else
    ZVOLS=$(zfs list -H -o name -t volume)
fi

printf "%-8s  %-40s  %-3s  %-5s  %s\n" "DEV" "ZVOL" "T" "ID" "NAME"
printf "%-8s  %-40s  %-3s  %-5s  %s\n" "--------" "----------------------------------------" "---" "-----" "------------------------------"

while read -r vol; do
    [[ -z "$vol" ]] && continue

    dev_path=$(readlink -f "/dev/zvol/$vol" 2>/dev/null || true)
    [[ -z "$dev_path" ]] && continue

    dev=$(basename "$dev_path")
    id=$(echo "$vol" | sed -n 's/.*\(vm-\|subvol-\)\([0-9]\+\)-.*/\2/p')
    type="-"
    name="-"

    if [[ -n "${id:-}" ]]; then
        if qm config "$id" &>/dev/null; then
            type="VM"
            name=$(qm config "$id" 2>/dev/null | awk -F: '/^name:/ {gsub(/^ +/, "", $2); print $2}')
            [[ -z "$name" ]] && name="-"
        elif pct config "$id" &>/dev/null; then
            type="CT"
            name=$(pct config "$id" 2>/dev/null | awk -F: '/^hostname:/ {gsub(/^ +/, "", $2); print $2}')
            [[ -z "$name" ]] && name="-"
        fi
    fi

    printf "%-8s  %-40s  %-3s  %-5s  %s\n" "$dev" "$vol" "$type" "${id:-"-"}" "$name"
done <<<"$ZVOLS"
