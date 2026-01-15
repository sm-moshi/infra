#!/usr/bin/env bash
set -euo pipefail

# Pools to monitor
POOLS=(timemachine datengrab)

ARCSTATS="/proc/spl/kstat/zfs/arcstats"
REFRESH=2
NOISE_THRESHOLD_KB=4 # ignore <4 KB/s

# ANSI colors
C_RESET="$(printf '\033[0m')"
C_GREEN="$(printf '\033[32m')"
C_YELLOW="$(printf '\033[33m')"
C_RED="$(printf '\033[31m')"

# ------------ ARC / L2ARC ------------
print_arc_stats() {
    if [[ ! -r $ARCSTATS ]]; then
        echo "ARC stats not available"
        echo
        return
    fi

    local hits misses total l2_hits l2_misses l2_total
    local arc_size arc_max

    hits=$(awk '$1=="hits"{print $3}' "$ARCSTATS")
    misses=$(awk '$1=="misses"{print $3}' "$ARCSTATS")
    l2_hits=$(awk '$1=="l2_hits"{print $3}' "$ARCSTATS")
    l2_misses=$(awk '$1=="l2_misses"{print $3}' "$ARCSTATS")
    arc_size=$(awk '$1=="size"{print $3}' "$ARCSTATS")
    arc_max=$(awk '$1=="c_max"{print $3}' "$ARCSTATS")

    total=$((hits + misses))
    l2_total=$((l2_hits + l2_misses))

    echo "========== ARC / L2ARC =========="

    if ((total > 0)); then
        printf "ARC hit ratio:     %.2f%% (%d / %d)\n" \
            "$(awk -v h="$hits" -v t="$total" 'BEGIN{print (h*100)/t}')" \
            "$hits" "$total"
    else
        echo "ARC hit ratio:     n/a"
    fi

    if ((l2_total > 0)); then
        printf "L2ARC hit ratio:   %.2f%% (%d / %d)\n" \
            "$(awk -v h="$l2_hits" -v t="$l2_total" 'BEGIN{print (h*100)/t}')" \
            "$l2_hits" "$l2_total"
    else
        echo "L2ARC hit ratio:   n/a"
    fi

    printf "ARC size:          %.1f MiB\n" "$(awk -v v="$arc_size" 'BEGIN{print v/1024/1024}')"
    printf "ARC max:           %.1f MiB\n" "$(awk -v v="$arc_max" 'BEGIN{print v/1024/1024}')"

    echo
}

# ------------ Collect device list ------------
collect_devices() {
    DEVICES=()
    while read -r dev _; do
        [[ $dev =~ ^[a-zA-Z0-9] ]] || continue
        DEVICES+=("$dev")
    done < <(zpool iostat -v "${POOLS[@]}")
}

# ------------ Pool load summary (1s sample) ------------
print_pool_load() {
    local pool="${1:-}" data="${2:-}"
    [[ -z $pool ]] && return

    local line
    line=$(awk -v p="$pool" '$1==p {print; exit}' <<<"$data")
    [[ -z $line ]] && return

    local name alloc free ops_r ops_w bw_r bw_w
    read -r name alloc free ops_r ops_w bw_r bw_w <<<"$line"

    # Default if parsing failed
    ops_r=${ops_r:-0}
    ops_w=${ops_w:-0}
    bw_r=${bw_r:-0}
    bw_w=${bw_w:-0}

    # Convert bytes/s to MB/s (one decimal)
    local r_mb w_mb
    r_mb=$(awk -v b="$bw_r" 'BEGIN{printf "%.1f", (b/1024/1024)}')
    w_mb=$(awk -v b="$bw_w" 'BEGIN{printf "%.1f", (b/1024/1024)}')

    # Color by write bandwidth
    local color="$C_GREEN"
    if ((bw_w > 100 * 1024 * 1024)); then
        color="$C_RED"
    elif ((bw_w > 20 * 1024 * 1024)); then
        color="$C_YELLOW"
    fi

    # Build a simple 20-char bar based on total throughput (r+w)
    local total_kb=$(((bw_r + bw_w) / 1024))
    local bar=""
    local i
    local maxlen=20
    for ((i = 0; i < maxlen; i++)); do
        # Each step ~= 5 MB/s
        if ((total_kb > (i * 5120))); then
            bar+="#"
        else
            bar+="."
        fi
    done

    printf "%-12s ops r/w=%6s/%-6s  bw r/w=%6s/%-6s MB/s  %s%s%s\n" \
        "$pool" "$ops_r" "$ops_w" "$r_mb" "$w_mb" "$color" "$bar" "$C_RESET"
}

# ------------ Main loop ------------
collect_devices

while true; do
    clear
    echo "ZFS dashboard – $(date)"
    echo

    # Single 1s sample (machine-readable) for the pool summary
    POOL_IOSTAT=$(zpool iostat -vyp "${POOLS[@]}" 1 1 2>/dev/null || true)

    print_arc_stats

    echo "========== POOL LOAD =========="
    for p in "${POOLS[@]}"; do
        print_pool_load "$p" "$POOL_IOSTAT"
    done
    echo

    echo "========== DATASET CONFIG =========="
    printf "%-25s %-12s %-10s %-12s %-12s\n" \
        "Dataset" "recordsize" "sync" "logbias" "primarycache"
    echo "--------------------------------------------------------------------------"

    for d in timemachine timemachine/tm-smb datengrab datengrab/archive datengrab/media; do
        printf "%-25s %-12s %-10s %-12s %-12s\n" \
            "$d" \
            "$(zfs get -H -o value recordsize "$d" 2>/dev/null || echo n/a)" \
            "$(zfs get -H -o value sync "$d" 2>/dev/null || echo n/a)" \
            "$(zfs get -H -o value logbias "$d" 2>/dev/null || echo n/a)" \
            "$(zfs get -H -o value primarycache "$d" 2>/dev/null || echo n/a)"
    done

    echo
    echo "========== ZPOOL IOSTAT (SLOG/L2ARC, 1s sample) =========="
    # Human-readable units for readability (separate 1s sample)
    zpool iostat -vy "${POOLS[@]}" 1 1
    echo

    echo "[q] quit, any other key = refresh…"

    if read -rs -t "$REFRESH" -n 1 key; then
        [[ $key == "q" || $key == "Q" ]] && break
    fi
done
