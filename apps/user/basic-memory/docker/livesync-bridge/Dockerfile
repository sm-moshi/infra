# Stage 1: Install dependencies and cache modules
#
# Policy: prefer glibc-based images for networked apps (Service DNS, CouchDB client).
FROM harbor.m0sh1.cc/dhi/deno:2.6.8-dev@sha256:21521da32fee45751911c2a08ff22a83ca497905bac03db723360fa44f72d588 AS builder

WORKDIR /app
ENV DENO_DIR=/deno-dir

# Copy all source (submodule needed for import resolution)
COPY . .
RUN mkdir -p /app/data \
  && deno install --allow-import \
  && deno cache --allow-import main.ts

# Stage 2: Runtime
FROM harbor.m0sh1.cc/dhi/deno:2.6.8@sha256:0956d5adc3dcecbbc70506978997cf175b2efb8016c3e4439bef332c555b6a8b

WORKDIR /app
ENV DENO_DIR=/deno-dir

COPY --from=builder --chown=1000:1000 /deno-dir /deno-dir
COPY --from=builder --chown=1000:1000 /app /app

VOLUME /app/dat
VOLUME /app/data

USER 1000:1000

CMD ["deno", "task", "run"]
