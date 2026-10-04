# Linux/Wine CI

See [BUILDING.md](BUILDING.md) for setup and cache details. This is the only CI build workflow; native Windows CI has been removed.

The workflow defaults to Blacksmith Ubuntu 24.04 x64 with **32 vCPU / 128 GB RAM / 1.5 TB disk**. It follows [SML's Linux CI](https://github.com/satisfactorymodding/SatisfactoryModLoader/blob/master/.github/workflows/build.yml): patched Wine 11, MSVC 17.8, Windows SDK 10.0.22621, Linux CSS engine, Wwise integration, native Linux editor compilation, and Windows cross-compilation via Wine.

The uncached predecessor successfully produced a mod package in approximately 20 minutes. The new workflow aggressively persists toolchains and compiler/cooker outputs with two Blacksmith sticky disks and an APT download cache. Wine source builds and SDK downloads occur only on a cold/incomplete cache; later runs reuse installed tools and incremental outputs.

CI now follows the locally verified low-disk build options: no UBA, no debug information, Steam-only packaging, and the filesystem derived-data-cache fallback. It produces a Windows Steam mod, not a native Linux game-client mod. The updated cache workflow still needs a cold/warm run to validate its persistence and measured timing.
