#!/usr/bin/env bash
set -euo pipefail

# ezfs - frontend wrapper for eZFS helper tools
#
# Subcommands:
#
#   ezfs zvol map [POOL_PREFIX]
#
#   ezfs report space vm [POOL_PREFIX]
#   ezfs report health pool [POOL...]
#   ezfs report usb [--dmesg]
#
#   ezfs snapshot vm <ID> [--keep N] [--prefix STR] [--note STRING]
#   ezfs snapshot all [--keep N] [--prefix STR] [--note STRING] [--running-only]
#
# Backends (must be in PATH, normally installed in /usr/local/sbin):
#   ezfs-zvol-map
#   ezfs-vm-space-report
#   ezfs-pool-report
#   ezfs-usb-report
#   ezfs-snapshot-vm
#   ezfs-snapshot-all
#

usage() {
    cat >&2 <<EOF
Usage:
  ezfs zvol map [POOL_PREFIX]

  ezfs report space vm [POOL_PREFIX]
  ezfs report health pool [POOL...]
  ezfs report usb [--dmesg]

  ezfs snapshot vm <ID> [--keep N] [--prefix STR] [--note STRING]
  ezfs snapshot all [--keep N] [--prefix STR] [--note STRING] [--running-only]
EOF
    exit 1
}

main() {
    [[ $# -lt 1 ]] && usage

    local cmd="$1"
    shift || true

    case "$cmd" in
    zvol)
        [[ $# -lt 1 ]] && usage
        case "$1" in
        map)
            shift || true
            exec ezfs-zvol-map "$@"
            ;;
        *)
            echo "Unknown 'zvol' subcommand: $1" >&2
            usage
            ;;
        esac
        ;;

    report)
        [[ $# -lt 1 ]] && usage
        local report_type="$1"
        shift || true
        case "$report_type" in
        space)
            [[ $# -lt 1 ]] && usage
            case "$1" in
            vm)
                shift || true
                exec ezfs-vm-space-report "$@"
                ;;
            *)
                echo "Unknown 'report space' target: $1" >&2
                usage
                ;;
            esac
            ;;
        health)
            [[ $# -lt 1 ]] && usage
            case "$1" in
            pool)
                shift || true
                exec ezfs-pool-report "$@"
                ;;
            *)
                echo "Unknown 'report health' target: $1" >&2
                usage
                ;;
            esac
            ;;
        usb)
            # allow: ezfs report usb [--dmesg]
            exec ezfs-usb-report "$@"
            ;;
        *)
            echo "Unknown 'report' type: $report_type" >&2
            usage
            ;;
        esac
        ;;

    snapshot)
        [[ $# -lt 1 ]] && usage
        local snap_target="$1"
        shift || true
        case "$snap_target" in
        vm)
            exec ezfs-snapshot-vm "$@"
            ;;
        all)
            exec ezfs-snapshot-all "$@"
            ;;
        *)
            echo "Unknown 'snapshot' target: $snap_target" >&2
            usage
            ;;
        esac
        ;;

    *)
        echo "Unknown command: $cmd" >&2
        usage
        ;;
    esac
}

main "$@"
