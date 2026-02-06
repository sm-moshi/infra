# Building trivy-operator DHI Image

This directory contains a custom Dockerfile to build a trivy-operator compatible image based on Docker Hardened Images (DHI).

## Why Custom Image?

The official DHI `trivy` images are designed for direct CLI usage and lack utilities required by trivy-operator's multi-container scan job pattern:

- **Missing utilities**: `bzip2`, `tar`, `gzip` (needed by scan job init containers)
- **Shell requirement**: trivy-operator init containers expect `/bin/sh` (DHI provides busybox but no `/bin/sh` symlink)

This custom build:

- Uses DHI `build:2.4.3-source` (dev variant with apt-get) for build stage
- Installs `libxml2` (fixes `gettext` dependency issues in the DHI build image) plus required utilities
- Downloads the `trivy` release tarball (no apt repo / gnupg needed)
- Copies artifacts to DHI `debian-base:trixie-debian13` runtime image (minimal, non-root)
- Maintains DHI security hardening (non-root user, minimal packages, updated dependencies)

## Build Instructions

```bash
# Set version variables
TRIVY_VERSION=0.69.0
IMAGE_TAG=0.69.0-debian13-trivy-operator

# Build from infra root
cd /Users/smeya/git/m0sh1.cc/infra/apps/user/trivy-operator

# Build multi-stage image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg TRIVY_VERSION=${TRIVY_VERSION} \
  -t harbor.m0sh1.cc/apps/trivy-operator:${IMAGE_TAG} \
  -f Dockerfile \
  --push \
  .

# Test image locally (after pulling)
docker pull harbor.m0sh1.cc/apps/trivy-operator:${IMAGE_TAG}
docker run --rm harbor.m0sh1.cc/apps/trivy-operator:${IMAGE_TAG} version
docker run --rm harbor.m0sh1.cc/apps/trivy-operator:${IMAGE_TAG} image --help

# Verify required utilities present
docker run --rm harbor.m0sh1.cc/apps/trivy-operator:${IMAGE_TAG} /bin/sh -c "bzip2 --version"
docker run --rm harbor.m0sh1.cc/apps/trivy-operator:${IMAGE_TAG} /bin/sh -c "tar --version"

# Push to Harbor
# (buildx --push above already pushes a multi-arch manifest)
```

## Update values.yaml

After building and pushing:

```yaml
trivy:
  image:
    registry: harbor.m0sh1.cc
    repository: apps/trivy-operator
    tag: "0.69.0-debian13-trivy-operator"  # Use this tag
    imagePullSecret: null
```

## Maintenance

When updating trivy version:

1. Update `TRIVY_VERSION` in Dockerfile `ARG` line
2. Rebuild with new version
3. Update `tag` in values.yaml
4. Test scan jobs before deploying cluster-wide

## References

- DHI Migration Guide: <https://hub.docker.com/hardened-images/catalog/dhi/build/guides>
- trivy-operator values: <https://github.com/aquasecurity/trivy-operator/blob/main/deploy/helm/values.yaml>
- DHI Build Image: `harbor.m0sh1.cc/dhi/build:2.4.3-source`
- DHI Runtime Image: `harbor.m0sh1.cc/dhi/debian-base:trixie-debian13`
