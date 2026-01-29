#!/bin/sh

# Package installation wizard for OPNsense/FreeBSD
# Usage: pkg_wizard.sh <package_name> [--upstream]
# Searches FreeBSD upstream repos for packages not in OPNsense repos

# Parse arguments
PACKAGE_NAME=""
USE_UPSTREAM=1  # Default to upstream search

while [ $# -gt 0 ]; do
    case "$1" in
        --local)
            USE_UPSTREAM=0
        ;;
        --upstream)
            USE_UPSTREAM=1
        ;;
        *)
            PACKAGE_NAME="$1"
        ;;
    esac
    shift
done

if [ -z "$PACKAGE_NAME" ]; then
    printf "Usage: %s <package_name> [--upstream|--local]\n" "$0"
    printf "  --upstream: Search FreeBSD upstream repos (default)\n"
    printf "  --local: Search configured OPNsense repos only\n"
    exit 1
fi

# Function to search in configured repos (OPNsense)
search_configured_repos() {
    printf "Searching configured repositories for: %s\n" "$PACKAGE_NAME"
    if pkg search -q "^${PACKAGE_NAME}-" >/dev/null 2>&1; then
        printf "\n\033[32mFound in configured repositories!\033[0m\n"
        pkg search -f "$PACKAGE_NAME" | head -20

        printf "\nInstall with: pkg install %s\n" "$PACKAGE_NAME"
        return 0
    fi
    return 1
}

# Function to search FreeBSD upstream repos
search_upstream_repos() {
    # Critical packages that should NEVER be installed from upstream
    CRITICAL_PACKAGES="pkg ca_root_nss opnsense opnsense-update"

    for critical_pkg in $CRITICAL_PACKAGES; do
        if [ "$PACKAGE_NAME" = "$critical_pkg" ]; then
            printf "\n\033[31mERROR: '%s' is a critical system package!\033[0m\n" "$PACKAGE_NAME"
            printf "Installing this from FreeBSD upstream could break OPNsense.\n"
            printf "Only install critical packages from OPNsense repositories.\n"
            return 1
        fi
    done

    printf "Searching FreeBSD upstream repositories...\n"

    # Determine FreeBSD version and architecture
    FBSD_VERSION=$(freebsd-version -u 2>/dev/null | cut -d- -f1 | cut -d. -f1)
    if [ -z "$FBSD_VERSION" ]; then
        printf "Error: Unable to determine FreeBSD version\n" >&2
        return 1
    fi

    ARCH=$(uname -m)
    # Export ABI for use in repository config (${ABI} expansion)
    export ABI="FreeBSD:${FBSD_VERSION}:${ARCH}"

    # Create temporary repo configuration
    TMP_CONF="/tmp/pkg_wizard_freebsd_$$.conf"
    trap 'rm -f "$TMP_CONF"' EXIT INT TERM

    # Try quarterly first, then latest
    for REPO_TYPE in quarterly latest; do
        printf "\nChecking FreeBSD %s repository...\n" "$REPO_TYPE"

        # Create temporary repository config using pkg+ protocol with SRV mirror resolution
        cat > "$TMP_CONF" << EOF
FreeBSD-Upstream-${REPO_TYPE}: {
    url: "pkg+http://pkg.FreeBSD.org/\${ABI}/${REPO_TYPE}",
    mirror_type: "srv",
    signature_type: "fingerprints",
    fingerprints: "/usr/share/keys/pkg",
    enabled: yes
}
EOF

        # Update the repository catalog
        printf "  Updating catalog..."
        if pkg -o REPOS_DIR=/tmp update -r "FreeBSD-Upstream-${REPO_TYPE}" >/dev/null 2>&1; then
            printf " OK\n"

            # Search for the package
            printf "  Searching for %s..." "$PACKAGE_NAME"
            PKG_INFO=$(pkg -o REPOS_DIR=/tmp rquery -r "FreeBSD-Upstream-${REPO_TYPE}" "%n %v %c" "^${PACKAGE_NAME}$" 2>/dev/null)

            if [ -n "$PKG_INFO" ]; then
                printf " \033[32mFOUND\033[0m\n"
                printf "\n\033[32mFound in FreeBSD %s repository!\033[0m\n" "$REPO_TYPE"

                # Display package info
                printf "\n%s\n" "$PKG_INFO"

                # Get dependencies
                DEPS=$(pkg -o REPOS_DIR=/tmp rquery -r "FreeBSD-Upstream-${REPO_TYPE}" "%dn-%dv" "^${PACKAGE_NAME}$" 2>/dev/null)
                if [ -n "$DEPS" ]; then
                    DEP_COUNT=$(echo "$DEPS" | wc -l | xargs)
                    printf "\nDependencies (%s):\n" "$DEP_COUNT"
                    echo "$DEPS" | sed 's/^/  - /'
                fi

                printf "\n\033[33mNote: Installing from FreeBSD upstream requires temporarily enabling the repository.\033[0m\n"
                printf "\n\033[32mTo install:\033[0m\n"
                printf "  1. Create /usr/local/etc/pkg/repos/FreeBSD-Upstream.conf with:\n"
                printf "     FreeBSD-Upstream: {\n"
                printf "       url: \"pkg+http://pkg.FreeBSD.org/\${ABI}/%s\",\n" "$REPO_TYPE"
                printf "       mirror_type: \"srv\",\n"
                printf "       signature_type: \"fingerprints\",\n"
                printf "       fingerprints: \"/usr/share/keys/pkg\",\n"
                printf "       enabled: yes,\n"
                printf "       priority: 100\n"
                printf "     }\n"
                printf "  2. Run: pkg install -r FreeBSD-Upstream %s\n" "$PACKAGE_NAME"
                printf "  3. Disable repo by setting enabled: no (RECOMMENDED)\n"
                printf "\n\033[33mWARNING: Always use -r FreeBSD-Upstream to prevent upgrading OPNsense packages!\033[0m\n"

                printf "\nCreate repo config and install now? (y/n) "
                read -r answer
                if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
                    # Create persistent repo config
                    REPO_DIR="/usr/local/etc/pkg/repos"
                    REPO_FILE="${REPO_DIR}/FreeBSD-Upstream.conf"

                    mkdir -p "$REPO_DIR"

                    cat > "$REPO_FILE" << EOF
# FreeBSD Upstream Repository
# WARNING: Lower priority (100) than OPNsense (0) to prevent
# accidentally upgrading OPNsense packages to upstream versions.
# This repo should ONLY be used for explicit installations.
FreeBSD-Upstream: {
    url: "pkg+http://pkg.FreeBSD.org/\${ABI}/${REPO_TYPE}",
    mirror_type: "srv",
    signature_type: "fingerprints",
    fingerprints: "/usr/share/keys/pkg",
    enabled: yes,
    priority: 100
}
EOF

                    printf "\nCreated %s\n" "$REPO_FILE"
                    printf "Installing %s from FreeBSD-Upstream only...\n" "$PACKAGE_NAME"

                    # Use -r flag to install ONLY from FreeBSD-Upstream repo
                    # This prevents upgrading existing packages from other repos
                    if pkg install -y -r FreeBSD-Upstream "$PACKAGE_NAME"; then
                        printf "\n\033[32m✓ Successfully installed %s\033[0m\n" "$PACKAGE_NAME"

                        printf "\nDisable FreeBSD upstream repo now? (recommended, y/n) "
                        read -r disable_answer
                        if [ "$disable_answer" = "y" ] || [ "$disable_answer" = "Y" ]; then
                            sed -i '' 's/enabled: yes/enabled: no/' "$REPO_FILE"
                            printf "Disabled FreeBSD-Upstream repository (re-enable by editing %s)\n" "$REPO_FILE"
                        fi
                    else
                        printf "\n\033[31m✗ Installation failed\033[0m\n" >&2
                        return 1
                    fi
                fi

                return 0
            else
                printf " NOT FOUND\n"
            fi
        else
            printf " FAILED (check network or repository URL)\n"
        fi
    done

    return 1
}

# Main logic
if [ "$USE_UPSTREAM" -eq 0 ]; then
    # Search only configured repos
    if ! search_configured_repos; then
        printf "\n\033[33mPackage not found in configured repositories\033[0m\n"
        printf "Try: %s %s --upstream\n" "$0" "$PACKAGE_NAME"
        exit 1
    fi
else
    # Check if FreeBSD-Upstream repo exists but is disabled
    UPSTREAM_REPO_FILE="/usr/local/etc/pkg/repos/FreeBSD-Upstream.conf"
    if [ -f "$UPSTREAM_REPO_FILE" ]; then
        if grep -q "enabled.*:.*no" "$UPSTREAM_REPO_FILE" 2>/dev/null; then
            printf "\033[33mFreeBSD-Upstream repository exists but is disabled.\033[0m\n"
            printf "Enable it temporarily for faster searches? (y/n) "
            read -r enable_answer
            if [ "$enable_answer" = "y" ] || [ "$enable_answer" = "Y" ]; then
                sed -i '' 's/enabled: no/enabled: yes/' "$UPSTREAM_REPO_FILE"
                printf "Enabled. Updating catalog...\n"
                pkg update -r FreeBSD-Upstream
                printf "\n"
            fi
        fi
    fi

    # Try configured repos first, then upstream
    if ! search_configured_repos 2>/dev/null; then
        printf "\033[33mNot in configured repos, searching upstream...\033[0m\n\n"
        if ! search_upstream_repos; then
            printf "\n\033[31mPackage '%s' not found in FreeBSD repositories\033[0m\n" "$PACKAGE_NAME"
            exit 1
        fi
    fi
fi
