# Stage 1: Install dependencies and cache modules
FROM harbor.m0sh1.cc/hub/denoland/deno:alpine-2.6.8 AS builder

WORKDIR /app
ENV DENO_DIR=/deno-dir

# Copy all source (submodule needed for import resolution)
COPY . .
RUN deno install --allow-import && deno cache --allow-import main.ts

# Stage 2: Alpine runtime
FROM harbor.m0sh1.cc/hub/denoland/deno:alpine-2.6.8

WORKDIR /app
ENV DENO_DIR=/deno-dir

COPY --from=builder /deno-dir /deno-dir
COPY --from=builder /app .

RUN mkdir -p /app/dat /app/data && chown -R 1000:1000 /app

VOLUME /app/dat
VOLUME /app/data

USER 1000:1000

CMD ["deno", "task", "run"]
