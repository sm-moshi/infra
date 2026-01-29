#!/bin/sh

# Check for orphaned packages (installed but not in any repository)
# Usage: pkg_available.sh
#
# This script uses pkg rquery to fetch available packages instead of
# manually downloading repository catalogs, which is more reliable
# and works with OPNsense's custom repository structure.

# Get a list of all installed packages
installed_packages=$(pkg info -q 2>/dev/null)
if [ -z "$installed_packages" ]; then
    printf "Error: No packages found or pkg database unavailable\n" >&2
    exit 1
fi

total=$(echo "$installed_packages" | wc -l | xargs)

printf "Checking %s installed packages...\n" "$total"

# Fetch all available package names from all configured repositories once
printf "Fetching repository catalog...\n"
available_packages=$(pkg rquery "%n" 2>/dev/null | sort -u)

if [ -z "$available_packages" ]; then
    printf "Error: Could not fetch repository catalog\n" >&2
    printf "Check repository configuration: pkg -vv\n" >&2
    exit 1
fi

available_count=$(echo "$available_packages" | wc -l | xargs)
printf "Found %s packages in repositories\n\n" "$available_count"

printf "Comparing packages...\n"

# Check each installed package against the available list
orphan_count=0
for pkg in $installed_packages; do
    # Remove the version part from the package name
    pkg_name=$(echo "$pkg" | rev | cut -d'-' -f2- | rev)

    # Check if package name exists in repositories
    if ! echo "$available_packages" | grep -qx "$pkg_name"; then
        printf "\033[33m%s\033[0m not found in any repository\n" "$pkg"
        orphan_count=$((orphan_count + 1))
    fi
done

if [ "$orphan_count" -eq 0 ]; then
    printf "\n\033[32mAll %s packages are available in repositories\033[0m\n" "$total"
else
    printf "\n\033[33mFound %s orphaned package(s)\033[0m\n" "$orphan_count"
fi

exit 0
