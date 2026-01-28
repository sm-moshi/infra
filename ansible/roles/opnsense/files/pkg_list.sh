#!/bin/sh

# Check for installed packages checking script
# Usage: pkg_list.sh [--quiet]

# Parse arguments
QUIET=0
if [ "$1" = "--quiet" ]; then
    QUIET=1
fi

# Get a list of all installed packages
installed_packages=$(pkg info -q 2>/dev/null)
if [ -z "$installed_packages" ]; then
    printf "Error: No packages found or pkg database unavailable\n" >&2
    exit 1
fi

total=$(echo "$installed_packages" | wc -l | xargs)
notfound=0

[ "$QUIET" -eq 0 ] && printf "Checking %s installed packages...\n" "$total"

# Fetch all available package names from repositories once (much faster)
[ "$QUIET" -eq 0 ] && printf "Fetching repository catalog...\n"
available_packages=$(pkg rquery "%n" 2>/dev/null | sort -u)

if [ -z "$available_packages" ]; then
    printf "Warning: Could not fetch repository catalog, falling back to slow method\n" >&2
    # Fallback to individual queries
    count=0
    for pkg in $installed_packages; do
        count=$((count + 1))
        pkg_name=$(echo "$pkg" | rev | cut -d'-' -f2- | rev)
        [ "$QUIET" -eq 0 ] && printf "[%s/%s] Checking %s..." "$count" "$total" "$pkg"
        if ! pkg rquery "%n" "$pkg_name" >/dev/null 2>&1; then
            [ "$QUIET" -eq 0 ] && printf " \033[31mNOT FOUND\033[0m\n"
            printf "\033[33m%s\033[0m not found in repository\n" "$pkg"
            notfound=$((notfound + 1))
        else
            [ "$QUIET" -eq 0 ] && printf " \033[32mOK\033[0m\n"
        fi
    done
else
    # Fast path: compare against pre-fetched list
    [ "$QUIET" -eq 0 ] && printf "Comparing packages...\n"
    for pkg in $installed_packages; do
        pkg_name=$(echo "$pkg" | rev | cut -d'-' -f2- | rev)
        if ! echo "$available_packages" | grep -qx "$pkg_name"; then
            printf "\033[33m%s\033[0m not found in repository\n" "$pkg"
            notfound=$((notfound + 1))
        fi
    done
fi

if [ "$notfound" -eq 0 ]; then
    [ "$QUIET" -eq 0 ] && printf "\n\033[32mAll %s packages are available in repositories\033[0m\n" "$total"
else
    [ "$QUIET" -eq 0 ] && printf "\nSummary: %s checked, %s not found in repositories\n" "$total" "$notfound"
fi

exit 0
