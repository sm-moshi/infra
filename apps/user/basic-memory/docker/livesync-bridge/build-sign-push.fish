#!/usr/bin/env fish

# =============================================================================
# Container Build, Sign, Scan & Attest Pipeline
# =============================================================================
#
# Usage:
#   ./build-sign-push.fish [OPTIONS]
#
# Options:
#   -t, --tag TAG           Image tag (default: timestamp YYYYMMDD-HHMMSS)
#   -p, --platform PLATFORM Target platform (default: linux/amd64)
#   -n, --name IMAGE_NAME   Image name (default: livesync-bridge)
#   --project PROJECT       Harbor project (default: apps)
#   --registry REGISTRY     Registry URL (default: harbor.m0sh1.cc)
#   --push                  Push to registry (default: off)
#   --latest                Also tag/push :latest (default: off)
#   --no-sbom               Skip SBOM generation/attestation
#   -h, --help              Show this help
#
# Environment variables (override defaults, CLI args override env vars):
#   TAG, PLATFORM, IMAGE_NAME, PROJECT, REGISTRY
#
# Examples:
#   ./build-sign-push.fish --tag v1.0.5 --platform linux/arm64,linux/amd64
#   TAG=v1.0.5 ./build-sign-push.fish
#   ./build-sign-push.fish -t v1.0.5 -p linux/arm64

# --- Parse Arguments ---
argparse h/help push latest no-sbom 't/tag=' 'p/platform=' 'n/name=' 'project=' 'registry=' -- $argv
or begin
    echo "Usage: ./build-sign-push.fish [-t TAG] [-p PLATFORM] [-n NAME] [--project PROJECT] [--registry REGISTRY]"
    exit 1
end

if set -q _flag_help
    echo "Container Build, Sign, Scan & Attest Pipeline"
    echo ""
    echo "Usage: ./build-sign-push.fish [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --tag TAG           Image tag (default: timestamp)"
    echo "  -p, --platform PLATFORM Target platform (default: linux/amd64)"
    echo "  -n, --name IMAGE_NAME   Image name (default: livesync-bridge)"
    echo "  --project PROJECT       Harbor project (default: apps)"
    echo "  --registry REGISTRY     Registry URL (default: harbor.m0sh1.cc)"
    echo "  --push                  Push to registry (default: off)"
    echo "  --latest                Also tag/push :latest (default: off)"
    echo "  --no-sbom               Skip SBOM generation/attestation"
    echo "  -h, --help              Show this help"
    exit 0
end

# --- Configuration (CLI > ENV > Default) ---
if set -q _flag_registry; and test -n "$_flag_registry"
    set REGISTRY $_flag_registry
else if set -q REGISTRY; and test -n "$REGISTRY"
    set REGISTRY $REGISTRY
else
    set REGISTRY harbor.m0sh1.cc
end

if set -q _flag_project; and test -n "$_flag_project"
    set PROJECT $_flag_project
else if set -q PROJECT; and test -n "$PROJECT"
    set PROJECT $PROJECT
else
    set PROJECT apps
end

if set -q _flag_name; and test -n "$_flag_name"
    set IMAGE_NAME $_flag_name
else if set -q IMAGE_NAME; and test -n "$IMAGE_NAME"
    set IMAGE_NAME $IMAGE_NAME
else
    set IMAGE_NAME livesync-bridge
end

if set -q _flag_tag; and test -n "$_flag_tag"
    set TAG $_flag_tag
else if set -q TAG; and test -n "$TAG"
    set TAG $TAG
else
    set TAG (date +%Y%m%d-%H%M%S)
end

if set -q _flag_platform; and test -n "$_flag_platform"
    set PLATFORM $_flag_platform
else if set -q PLATFORM; and test -n "$PLATFORM"
    set PLATFORM $PLATFORM
else
    set PLATFORM linux/amd64
end
set SCAN_PLATFORM (string split , $PLATFORM)[1]
set COSIGN_KEY k8s://apps/harbor-cosign

# Derived variables
set IMAGE_REF "$REGISTRY/$PROJECT/$IMAGE_NAME:$TAG"
set IMAGE_LATEST "$REGISTRY/$PROJECT/$IMAGE_NAME:latest"

echo "📦 Building: $IMAGE_REF"
echo "   Platform: $PLATFORM"
echo "   Scan: $SCAN_PLATFORM"

# --- Build (push is opt-in) ---
set DO_PUSH false
if set -q _flag_push
    set DO_PUSH true
end

set DO_LATEST false
if set -q _flag_latest
    set DO_LATEST true
end

if test "$DO_PUSH" = true
    set TAG_ARGS -t $IMAGE_REF
    if test "$DO_LATEST" = true
        set TAG_ARGS $TAG_ARGS -t $IMAGE_LATEST
    end

    docker buildx build \
        --platform $PLATFORM \
        --push \
        --provenance=true \
        --sbom=false \
        $TAG_ARGS \
        . || begin
        echo "❌ Build failed"
        exit 1
    end
else
    echo "🧪 Build-only mode (no push)."
    if string match -q "*,*" "$PLATFORM"
        echo "   Multi-platform build without push needs OCI output; skipping sign/scan/attest."
        set OCI_OUT (mktemp -t (string replace "/" "_" $IMAGE_NAME)".oci.XXXXXX").tar
        docker buildx build \
            --platform $PLATFORM \
            --provenance=true \
            --sbom=false \
            --output type=oci,dest=$OCI_OUT \
            -t $IMAGE_REF \
            . || begin
            echo "❌ Build failed"
            exit 1
        end
        echo "✅ Built OCI archive: $OCI_OUT"
        echo "   To publish + sign + attest, re-run with --push."
        exit 0
    else
        docker buildx build \
            --platform $PLATFORM \
            --provenance=true \
            --sbom=false \
            --load \
            -t $IMAGE_REF \
            . || begin
            echo "❌ Build failed"
            exit 1
        end
        echo "✅ Built locally: $IMAGE_REF"
        echo "   To publish + sign + attest, re-run with --push."
        exit 0
    end
end

# --- Get Digest ---
echo "🔍 Fetching digest..."
set DIGEST (docker buildx imagetools inspect $IMAGE_REF --format '{{json .Manifest.Digest}}' | tr -d '"')

if test -z "$DIGEST"
    echo "❌ Failed to get digest"
    exit 1
end

set IMAGE_DIGEST "$REGISTRY/$PROJECT/$IMAGE_NAME@$DIGEST"
echo "   Digest: $DIGEST"

# --- Sign Image ---
echo "🔏 Signing image..."
cosign sign --key $COSIGN_KEY $IMAGE_DIGEST || begin
    echo "❌ Signing failed"
    exit 1
end

# --- Generate and Attest SBOM (optional) ---
if not set -q _flag_no_sbom
    echo "📋 Generating SBOM..."
    set SBOM_FILE (mktemp)
    syft registry:$IMAGE_DIGEST --platform $SCAN_PLATFORM -o spdx-json > $SBOM_FILE || begin
        echo "❌ SBOM generation failed"
        rm -f $SBOM_FILE
        exit 1
    end

    # Prefer attestations over "attach sbom" (deprecated) and less likely to confuse registries/scanners.
    cosign attest \
        --key $COSIGN_KEY \
        --type spdxjson \
        --predicate $SBOM_FILE \
        $IMAGE_DIGEST || begin
        echo "❌ SBOM attestation failed"
        rm -f $SBOM_FILE
        exit 1
    end

    rm -f $SBOM_FILE
else
    echo "📋 SBOM: skipped (--no-sbom)"
end

# --- Vulnerability Scan and Attest ---
echo "🔬 Scanning for vulnerabilities..."
trivy image --platform $SCAN_PLATFORM --format cosign-vuln $IMAGE_DIGEST | cosign attest \
    --key $COSIGN_KEY \
    --type vuln \
    --predicate - \
    $IMAGE_DIGEST || begin
    echo "❌ Vuln attestation failed"
    exit 1
end

# --- Verify ---
echo "✅ Verifying signatures and attestations..."
cosign tree $IMAGE_DIGEST

echo ""
echo "════════════════════════════════════════════"
echo "✅ Complete!"
echo "   Image:  $IMAGE_REF"
echo "   Digest: $IMAGE_DIGEST"
echo "════════════════════════════════════════════"
