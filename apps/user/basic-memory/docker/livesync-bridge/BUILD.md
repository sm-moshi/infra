# livesync-bridge - Custom DHI Build

Patched fork of [vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) for
CouchDB ↔ filesystem bidirectional sync (Obsidian LiveSync ↔ Basic Memory).

## Patches Applied

1. **Removed `trystero` import** from `deno.jsonc` — P2P/Nostr replication not needed;
   the bgWorker is already mocked in the import map.
2. **Custom Dockerfile** using DHI hardened Deno images with `--allow-import` flag
   (required by Deno 2.6.8's stricter import policy).

## Build

```bash
docker build --platform linux/amd64 -t harbor.m0sh1.cc/apps/livesync-bridge:0.1.0 .
docker push harbor.m0sh1.cc/apps/livesync-bridge:0.1.0
```

## Base Images

- Builder: `harbor.m0sh1.cc/dhi/deno:2.6.8-dev` (root, Debian 13)
- Runtime: `harbor.m0sh1.cc/dhi/deno:2.6.8` (non-root, Debian 13)

## Upstream

Cloned with `git clone --recurse-submodules https://github.com/vrtmrz/livesync-bridge.git`.
The `lib/` directory is the `livesync-commonlib` submodule.
