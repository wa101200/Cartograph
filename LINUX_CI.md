# Linux/Wine CI

See [BUILDING.md](BUILDING.md) for setup and cache details. This is the only CI build workflow; native Windows CI has been removed.

The workflow defaults to Blacksmith Ubuntu 24.04 x64 with **32 vCPU / 128 GB RAM / 1.5 TB disk** for compilation. A smaller image job publishes the shared `docker/Dockerfile` to GHCR only when its inputs change. Toolchain setup runs inside that image, followed by the same `scripts/build-local.sh` used locally: stock Wine 11.0, MSVC 17.8, Windows SDK 10.0.22621, Linux CSS engine, Wwise integration, native Linux editor compilation, and Windows cross-compilation via Wine. The former source-built patched Wine and runner APT setup have been removed.

The uncached predecessor successfully produced a mod package in approximately 20 minutes. The new workflow aggressively persists toolchains, Wine prefix, container HOME, .NET/Wwise caches, temporary downloads and compiler/cooker outputs with two Blacksmith sticky disks. Docker layers are cached for image publishing; pulled images are automatically cached by Blacksmith. SDK downloads occur only on a cold/incomplete cache; later runs reuse installed tools and incremental outputs.

CI now follows the locally verified low-disk build options: no UBA, no debug information, Steam-only packaging, and the filesystem derived-data-cache fallback. It produces a Windows Steam mod, not a native Linux game-client mod. The updated cache workflow still needs a cold/warm run to validate its persistence and measured timing.
