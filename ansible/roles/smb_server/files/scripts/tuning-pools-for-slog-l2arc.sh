#!/usr/bin/env bash
set -euo pipefail

# Safe ZFS tuning for timemachine + datengrab on pve-01.
# - Prompts before applying changes.
# - Skips missing pools/datasets.
# - Prints properties before/after for visibility.

HOST_REQ="pve-01"

POOLS=(timemachine datengrab)
DATASETS_TIMEMACHINE=("timemachine" "timemachine/tm-smb")
DATASETS_DATENGRAB=("datengrab" "datengrab/archive" "datengrab/media")

apply_props() {
  local ds="$1"
  shift
  if ! zfs list "$ds" >/dev/null 2>&1; then
    echo "Skipping missing dataset $ds"
    return
  fi
  for kv in "$@"; do
    local k v
    k="${kv%%=*}"
    v="${kv#*=}"
    echo "  zfs set $k=$v $ds"
    zfs set "$k=$v" "$ds"
  done
}

print_props() {
  echo "Current properties:"
  zfs get -H -o name,property,value sync,logbias,primarycache,recordsize,compression,atime,xattr,acltype \
    timemachine timemachine/tm-smb \
    datengrab datengrab/archive datengrab/media 2>/dev/null || true
  echo
}

echo "Host check: expecting $HOST_REQ (current: $(hostname -s))"
if [[ "$(hostname -s)" != "$HOST_REQ" ]]; then
  read -r -p "Not on $HOST_REQ. Continue anyway? [yes/NO] " h
  [[ $h == "yes" ]] || {
    echo "Aborted."
    exit 1
  }
fi

print_props
read -r -p "Apply tuning to timemachine/datengrab? [yes/NO] " ans
[[ $ans == "yes" ]] || {
  echo "Aborted."
  exit 0
}

echo "Tuning timemachine pool + tm-smb..."
apply_props "timemachine" \
  "sync=standard" \
  "logbias=latency" \
  "primarycache=metadata" \
  "recordsize=128K" \
  "atime=off" \
  "compression=zstd" \
  "xattr=sa" \
  "acltype=posix"

apply_props "timemachine/tm-smb" \
  "sync=standard" \
  "logbias=latency" \
  "primarycache=all" \
  "recordsize=1M"

echo "Tuning datengrab pool + datasets..."
apply_props "datengrab" \
  "sync=standard" \
  "logbias=throughput" \
  "primarycache=all" \
  "atime=off" \
  "compression=zstd" \
  "xattr=sa" \
  "acltype=posix"

apply_props "datengrab/archive" \
  "sync=standard" \
  "logbias=throughput" \
  "primarycache=metadata" \
  "recordsize=1M"

apply_props "datengrab/media" \
  "sync=standard" \
  "logbias=throughput" \
  "primarycache=all" \
  "recordsize=256K"

echo
print_props
echo "Tuning complete."
