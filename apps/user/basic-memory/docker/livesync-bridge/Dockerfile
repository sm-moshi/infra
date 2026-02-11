# Stage 1: Install dependencies and cache modules
#
# Policy: prefer glibc-based images for networked apps (Service DNS, CouchDB client).
FROM harbor.m0sh1.cc/dhi/deno:2.6.9-dev@sha256:aad50c98d7bd7f4320c41e34efab96e52af2be2368d69c9b301f29dd2b2f0504 AS builder

WORKDIR /app
ENV DENO_DIR=/deno-dir

# Copy all source (submodule needed for import resolution)
COPY . .
RUN mkdir -p /app/data \
  && deno install --allow-import \
  && deno cache --allow-import main.ts

# Stage 2: Runtime
FROM harbor.m0sh1.cc/dhi/deno:2.6.9@sha256:a0ef2972b8d92a874aa94b23cad7abd5c2b576df129f1e7a41a648efcc16dd2a

WORKDIR /app
ENV DENO_DIR=/deno-dir

COPY --from=builder --chown=1000:1000 /deno-dir /deno-dir
COPY --from=builder --chown=1000:1000 /app /app

VOLUME /app/dat
VOLUME /app/data

USER 1000:1000

CMD ["deno", "task", "run"]
