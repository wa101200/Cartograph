# Linux/Wine CI

See [BUILDING.md](BUILDING.md) for setup, image contents and cache mounts. This is the only CI build workflow; Windows CI has been removed.

CI and local builds share `docker/Dockerfile` and `scripts/build-local.sh`. A small image job publishes the private GHCR toolchain image only when its inputs change. It now includes **Wine 11.0, MSVC 17.8, Windows SDK 10.0.22621, PDBCopy, and preintegrated Wwise plugins/SDK**. Per-run Docker provisioning only synchronizes source and downloads/registers the CSS engine if missing.

The main job defaults to Blacksmith Ubuntu 24.04 x64 with **32 vCPU / 128 GB RAM / 1.5 TB disk**. Two sticky disks persist engine files, Wine prefix, container HOME, .NET/general caches, temporary downloads, compiler outputs and cooked data. Docker build layers and pulled images are also cached. Stable paths and preserved source timestamps enable incremental builds.

Build options disable UBA and debug information, use the filesystem derived-data-cache fallback, and package the Windows Steam mod only. This produces a Windows package for Satisfactory/Proton, not a native Linux game-client mod.

The original uncached Linux CI succeeded in approximately 20 minutes. Cold/warm validation of the new SDK-inclusive image is needed to measure its improvement.
