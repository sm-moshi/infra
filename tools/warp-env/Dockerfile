# Warp Environment for m0sh1.cc/infra
# Pre-installs mise + all toolchain from mise.toml for fast environment startup
#
# Build: docker build --platform linux/amd64 -t warp-env:infra .
# Push:  docker push <registry>/warp-env:infra

FROM harbor.m0sh1.cc/dhi/debian-base:trixie-debian13

LABEL maintainer="sm-moshi"
LABEL description="Warp development environment for m0sh1.cc/infra repository"

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    libatomic1 \
    openssh-client \
    pipx \
    python3 \
    python3-pip \
    unzip \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install mise (tool version manager)
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:${PATH}"

# Reduce parallelism to avoid GitHub rate limiting
ENV MISE_JOBS=2

# Optional: pass GitHub token to avoid rate limits
# Build with: docker build --build-arg GITHUB_TOKEN=ghp_xxx ...
ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=${GITHUB_TOKEN}

# Pre-install tools in batches to reduce rate limit impact
# Batch 1: Core runtimes (large downloads, less API calls)
RUN mise use --global \
    node@25.6.0 \
    python@3.14.3 \
    go@1.25.7

# Batch 2: IaC and Kubernetes core tools
RUN mise use --global \
    terraform@1.14.4 \
    helm@4.1.0 \
    kubectl@1.35.0 \
    kustomize@5.8.0

# Batch 3: Python tools via pipx
RUN mise use --global \
    uv@0.10.0 \
    ansible@13.3.0 \
    ansible-core@2.20.2 \
    yamllint@1.38.0

# Batch 4: Kubernetes utilities
RUN mise use --global \
    kubeconform@0.7.0 \
    kube-linter@0.8.1 \
    kubeseal@0.34.0 \
    trivy@0.69.1

# Batch 5: Shell/CLI tools
RUN mise use --global \
    docker-cli@29.2.1 \
    shellcheck@0.11.0 \
    eza@0.23.4 \
    fd@10.3.0 \
    rg@15.1.0 \
    yq@4.52.2

# Batch 6: Remaining tools
RUN mise use --global \
    git-cliff@2.12.0 \
    prek@0.3.2 \
    helm-diff@3.15.0 || true

# Activate mise in shell
RUN echo 'eval "$(mise activate zsh)"' >> ~/.zshrc

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/zsh"]
