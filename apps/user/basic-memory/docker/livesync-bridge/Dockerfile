# Stage 1: Install dependencies and cache modules
#
# Policy: prefer glibc-based images for networked apps (Service DNS, CouchDB client).
FROM harbor.m0sh1.cc/dhi/deno:2.6.9-dev AS builder

WORKDIR /app
ENV DENO_DIR=/deno-dir

# Copy all source (submodule needed for import resolution)
COPY . .
# Note: --allow-import required by Deno 2.6.8+ for stricter import policy
RUN mkdir -p /app/data \
  && deno install --allow-import \
  && deno cache --allow-import main.ts

# Stage 2: Runtime
FROM harbor.m0sh1.cc/dhi/deno:2.6.9

WORKDIR /app
ENV DENO_DIR=/deno-dir

COPY --from=builder --chown=deno:deno /deno-dir /deno-dir
COPY --from=builder --chown=deno:deno /app /app

# Ensure volume directories exist with correct permissions for non-root user
RUN mkdir -p /app/dat /app/data && \
  chown -R deno:deno /app/dat /app/data

VOLUME /app/dat
VOLUME /app/data

USER deno:deno

# Health check for Kubernetes liveness probes
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD deno eval "import { serve } from 'std/http/server.ts'; console.log('OK')" || exit 1

# Use exec form to ensure proper signal handling in Kubernetes
ENTRYPOINT ["deno", "task", "run"]
