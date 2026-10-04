# Docker-based local build

Local builds run exclusively inside Docker. The host needs Docker and the CSS engine files, not Wine, MSVC or a Wwise installation.

```bash
./scripts/build-local.sh --check
./scripts/build-local.sh
JOBS=4 ./scripts/build-local.sh  # Optional CPU limit; default is all threads
```

The Windows Steam package is written to:

```text
Saved/ArchivedPlugins/Cartograph/Cartograph-Windows.zip
```

The script never installs a mod or launches the game. The inner script rejects direct host execution.

## Shared toolchain image

`scripts/docker-image-ref.sh` selects a content-addressed image in **`ghcr.io/wa101200/cartograph-toolchain`**, shared with CI. The launcher pulls it on first use and reuses it thereafter. Authenticate Docker to GHCR with a token authorized to read the private package (`read:packages`); registry credentials are never mounted into build containers.

The image includes:

- Digest-pinned `scottyhardy/docker-wine`: Ubuntu 24.04 amd64, Wine 11.0, graphics/audio/headless dependencies.
- MSVC **17.8 / 14.38**, Windows SDK **10.0.22621**, patched `msvc-wine` wrappers, and PDBCopy at `/opt/cartograph/msvc`.
- Wwise CLI **0.2.4**, ready-to-copy UE **5.6** plugin integration **2023.1.14.3555**, and Wwise SDK **2023.1.14.8770** (Windows vc160/vc170 + Linux).
- Linux build tools, Python, GitHub CLI, msitools, rsync, .NET/Unreal runtime dependencies.

**Keep this image private.** It contains SDK binaries, but no CSS engine, project source, compiled project outputs, registry login files or Audiokinetic credentials.

Set `CARTOGRAPH_DOCKER_IMAGE=ghcr.io/wa101200/cartograph-toolchain@sha256:...` to pin CI's exact image digest. If pulling the default image fails, the launcher can build the same Dockerfile locally, provided `WWISE_EMAIL` and `WWISE_PASSWORD` are set. These use **BuildKit secret mounts**, not build arguments. `--rebuild-image` explicitly rebuilds the default image locally. Normal builds with a prebuilt image need no Wwise credentials.

## Persistent mounts

The default build root is `~/.local/share/cartograph-build`:

| Host path | Persistent contents |
| --- | --- |
| Repository | Plugin integration, `Binaries`, `Intermediate`, `Saved/Cooked`, staging and packaged ZIPs |
| `ue/` | CSS Unreal Engine **5.6.1-CSS**, including engine-side generated files |
| `docker-home/` | Container-only HOME, Unreal configuration/logs, engine registration |
| `docker-home/ddc/` | Filesystem derived-data cache |
| `docker-wine-prefix/` | Wine registry/initialization state, separate from host `.wine` |
| `nuget/` | .NET package cache |
| `cache/` | General runtime caches |
| `tmp/` | Persistent temporary downloads/extraction files |

All host directories are bind-mounted at the same absolute paths, preserving compiler/cache references. MSVC and immutable Wwise templates stay inside the image: **no bind mounts hide `/opt/cartograph`**.

Missing `Plugins/Wwise` and `Plugins/WwiseNiagara` are copied once from the image, with no network or authentication. Subsequent builds preserve their timestamps and generated outputs. Existing integrations are left untouched; incomplete existing directories are reported rather than overwritten.

Overrides:

- `CARTOGRAPH_BUILD_ROOT`, `UE_CSS_ROOT`: engine/cache locations.
- `UE_WINE_MSVC`: optional **host** toolchain override instead of image MSVC.
- `CARTOGRAPH_WINEPREFIX`, `CARTOGRAPH_CACHE_HOME`, `CARTOGRAPH_TMPDIR`, `NUGET_PACKAGES`: persistent state/cache directories.
- Custom host directories outside the build root are explicitly mounted, without duplicate mounts.

## Build settings and isolation

- Runs as your UID/GID, **not root**; no privileged mode or GPU access is needed.
- No game directory, whole host HOME or Docker socket is mounted.
- UBA and debug information are disabled, with Steam-only Windows packaging.
- UBT configuration is written only if its contents change, preserving unrelated settings.
- Cooking uses `InstalledNoZenLocalFallback` and a persistent filesystem cache, avoiding Zen auto-launch failures in containers.
- Shared memory is 2 GiB; all host CPUs are allowed unless `JOBS` is set.

The dependency-only predecessor image completed a local build/cook/package successfully. The new SDK-inclusive image needs its own build and end-to-end validation.
