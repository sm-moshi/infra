# Multi-stage Dockerfile for trivy-operator compatible DHI image
ARG DHI_BUILD_IMAGE=harbor.m0sh1.cc/dhi/build:2.4.3-source
ARG DHI_RUNTIME_IMAGE=harbor.m0sh1.cc/dhi/debian-base:trixie-debian13
ARG TRIVY_VERSION=0.69.0

# Build stage: Use dev variant with package manager
FROM ${DHI_BUILD_IMAGE} AS builder

# Install trivy and required utilities for trivy-operator scan jobs
# trivy-operator needs: bzip2, tar, gzip, ca-certificates
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  libxml2 \
  wget \
  ca-certificates \
  busybox \
  bzip2 \
  tar \
  gzip \
  && rm -rf /var/lib/apt/lists/*

# Install trivy binary (download release tarball; avoids apt repo + gnupg/dirmngr dependency issues)
ARG TARGETARCH
ARG TRIVY_VERSION
RUN set -eux; \
  case "${TARGETARCH}" in \
  amd64) trivy_asset_arch="Linux-64bit" ;; \
  arm64) trivy_asset_arch="Linux-ARM64" ;; \
  *) echo "Unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
  esac; \
  trivy_asset="trivy_${TRIVY_VERSION}_${trivy_asset_arch}.tar.gz"; \
  trivy_url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${trivy_asset}"; \
  sums_url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt"; \
  wget -qO "/tmp/${trivy_asset}" "${trivy_url}"; \
  wget -qO /tmp/trivy_checksums.txt "${sums_url}"; \
  /bin/busybox grep "  ${trivy_asset}$" /tmp/trivy_checksums.txt > /tmp/trivy.sha256; \
  cd /tmp; /bin/busybox sha256sum -c /tmp/trivy.sha256; \
  tar -xzf "/tmp/${trivy_asset}" -C /usr/bin trivy; \
  chmod 0755 /usr/bin/trivy; \
  rm -f "/tmp/${trivy_asset}" /tmp/trivy_checksums.txt /tmp/trivy.sha256

# Collect runtime shared library dependencies for copied binaries
RUN set -eux; \
  mkdir -p /tmp/runtime-libs; \
  { \
    ldd /usr/bin/trivy 2>/dev/null || true; \
    ldd /usr/bin/bzip2 /usr/bin/bunzip2 /usr/bin/bzcat /usr/bin/tar /usr/bin/gzip /usr/bin/gunzip /bin/busybox; \
  } \
  | /bin/busybox awk '/=>/ {print $3}' \
  | sort -u \
  | while read -r lib; do \
      [ -n "$lib" ] || continue; \
      dest="$lib"; \
      case "$lib" in \
        /lib64/*) dest="/usr/lib64/${lib#/lib64/}" ;; \
        /lib/*) dest="/usr/lib/${lib#/lib/}" ;; \
      esac; \
      mkdir -p "/tmp/runtime-libs$(dirname "$dest")"; \
      cp -v "$lib" "/tmp/runtime-libs$dest"; \
    done; \
  for loader in \
    /lib64/ld-linux-x86-64.so.2 \
    /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 \
    /lib/ld-linux-aarch64.so.1 \
    /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 \
  ; do \
    [ -e "$loader" ] || continue; \
    dest="$loader"; \
    case "$loader" in \
      /lib64/*) dest="/usr/lib64/${loader#/lib64/}" ;; \
      /lib/*) dest="/usr/lib/${loader#/lib/}" ;; \
    esac; \
    mkdir -p "/tmp/runtime-libs$(dirname "$dest")"; \
    cp -v "$loader" "/tmp/runtime-libs$dest"; \
  done

# Runtime stage: Use non-dev DHI image for minimal attack surface
FROM ${DHI_RUNTIME_IMAGE}

# Copy trivy binary and required utilities from builder
COPY --from=builder /usr/bin/trivy /usr/bin/trivy
COPY --from=builder /usr/bin/bzip2 /usr/bin/bzip2
COPY --from=builder /usr/bin/bunzip2 /usr/bin/bunzip2
COPY --from=builder /usr/bin/bzcat /usr/bin/bzcat
COPY --from=builder /usr/bin/tar /usr/bin/tar
COPY --from=builder /usr/bin/gzip /usr/bin/gzip
COPY --from=builder /usr/bin/gunzip /usr/bin/gunzip

# Copy runtime libraries and CA certificates
COPY --from=builder /tmp/runtime-libs/ /
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
COPY --from=builder /usr/share/ca-certificates /usr/share/ca-certificates

# Ensure /bin/sh exists for init containers (busybox provides sh)
COPY --from=builder /bin/busybox /bin/busybox
RUN /bin/busybox --install -s /bin

# Set up trivy cache directory (writable by nonroot user)
ENV TRIVY_CACHE_DIR=/tmp/trivy/.cache
RUN mkdir -p /tmp/trivy/.cache && \
  chown -R nonroot:nonroot /tmp/trivy

USER nonroot

ENTRYPOINT ["/usr/bin/trivy"]
CMD ["--help"]
