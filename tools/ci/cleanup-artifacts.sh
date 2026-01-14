#!/usr/bin/env bash
set -euo pipefail

# cleanup-artifacts.sh
# Finds and optionally removes .DS_Store, *.lock, and *.tgz files
# Usage: ./cleanup-artifacts.sh [--dry-run]

DRY_RUN=false
if [[ ${1:-} == "--dry-run" ]]; then
    DRY_RUN=true
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Scanning repository: $REPO_ROOT"
echo ""

# Find files to clean up
DS_STORE_FILES=$(find "$REPO_ROOT" -name ".DS_Store" 2>/dev/null || true)
LOCK_FILES=$(find "$REPO_ROOT" -name "*.lock" 2>/dev/null || true)
TGZ_FILES=$(find "$REPO_ROOT" -name "*.tgz" 2>/dev/null || true)

# Combine all findings
ALL_FILES=$(printf "%s\n" "$DS_STORE_FILES" "$LOCK_FILES" "$TGZ_FILES" 2>/dev/null | grep -v '^$' | sort -u)

if [[ -z $ALL_FILES ]]; then
    echo "✓ No cleanup files found (.DS_Store, *.lock, *.tgz)"
    exit 0
fi

# Count and display
TOTAL=$(echo "$ALL_FILES" | wc -l)
echo "Found $TOTAL file(s) to clean up:"
echo ""
echo "$ALL_FILES" | while read -r file; do
    rel=${file#"$REPO_ROOT"/}
    echo "  • $rel"
done
echo ""

if [[ $DRY_RUN == true ]]; then
    echo "🔍 Dry-run mode: no files were deleted"
    exit 0
fi

# Prompt for confirmation
read -p "Delete these files? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "$ALL_FILES" | while read -r file; do
        rm -f "$file"
        rel=${file#"$REPO_ROOT"/}
        echo "  ✓ Deleted: $rel"
    done
    echo ""
    echo "✓ Cleanup complete!"
else
    echo "Cleanup cancelled."
fi
