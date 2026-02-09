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
argparse h/help 't/tag=' 'p/platform=' 'n/name=' 'project=' 'registry=' -- $argv
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

# --- Build and Push ---
docker buildx build \
    --platform $PLATFORM \
    --push \
    --provenance=true \
    --sbom=false \
    -t $IMAGE_REF \
    -t $IMAGE_LATEST \
    . || begin
    echo "❌ Build failed"
    exit 1
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

# --- Generate and Attach SBOM (Harbor-compatible) ---
echo "📋 Generating SBOM..."
set SBOM_FILE (mktemp)
syft registry:$IMAGE_DIGEST --platform $SCAN_PLATFORM -o spdx-json > $SBOM_FILE || begin
    echo "❌ SBOM generation failed"
    rm -f $SBOM_FILE
    exit 1
end

cosign attach sbom --sbom $SBOM_FILE $IMAGE_DIGEST || begin
    echo "❌ SBOM attach failed"
    rm -f $SBOM_FILE
    exit 1
end
rm -f $SBOM_FILE

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
