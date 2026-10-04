# Build and CI

## Local builds: Docker only

```bash
./scripts/build-local.sh --check
./scripts/build-local.sh
```

See [LOCAL_BUILD.md](LOCAL_BUILD.md). The host needs Docker and the CSS engine, not Wine/MSVC/Wwise installations. Native builds are rejected by the inner script.

## CI: same Docker image and entrypoint

**Build Cartograph (Linux Wine)** is the only build workflow. Windows CI and its provisioning script were removed; the personal fork and external runner resources were not deleted.

The workflow runs on push, published release and manual dispatch:

1. A small `blacksmith-4vcpu-ubuntu-2404` image job publishes the shared toolchain image **only when image inputs change**.
2. The build job defaults to `blacksmith-32vcpu-ubuntu-2404` (32 vCPU, 128 GB RAM, 1.5 TB disk), restores sticky disks, and provisions the CSS engine in Docker.
3. It calls the same `scripts/build-local.sh` used locally to compile the Linux editor and package the **Windows Steam mod** for Satisfactory/Proton.

Override `CARTOGRAPH_LINUX_RUNNER` only with an available compatible Linux x64 runner label.

## Image contents and publication

**`ghcr.io/wa101200/cartograph-toolchain`** includes Ubuntu 24.04, stock Wine 11.0, MSVC 17.8, Windows SDK 10.0.22621, PDBCopy, Wwise CLI, and ready-to-copy Wwise plugin/SDK templates for UE 5.6. CI no longer runs APT installation, Wine compilation, MSVC installation, or Wwise downloads/integration on each runner.

`scripts/docker-image-ref.sh` hashes the Dockerfile, context filter and SDK installer scripts to select a content-addressed tag. CI resolves the published tag to a digest before starting build containers.

**Keep the package private.** The workflow refuses to publish SDK layers into an existing public package. The image job needs `packages: write`; the build job needs only `packages: read`. Package access must permit this repository's Actions token. There is no pull-request trigger.

MSVC and Wwise use independent image-build stages, so changing one does not rebuild the other. MSVC downloads also use a persistent BuildKit cache mount. Wwise uses metadata-only UE 5.6 registration to prepare the integration: no full engine is needed for this step. Only finished compiler files and Wwise templates are copied to the final image, not temporary registration files, downloader caches or credentials.

Required secrets:

- `CSS_ENGINE_TOKEN`: read access to `satisfactorymodding/UnrealEngine`, used during engine setup.
- `WWISE_EMAIL`, `WWISE_PASSWORD`: used **only when building a new image**, through BuildKit secret mounts.

`CSS_ENGINE_RELEASE` pins the CSS engine release (default `5.6.1-css-83`). Never put credentials in source, Docker build arguments or cache snapshots.

## Aggressive persistent caching

Two Blacksmith sticky disks use `commit: on-change`:

| Mount / path | Cached contents |
| --- | --- |
| `/tmp/cg` (read/write project disk) | Source, Wwise plugins, generated headers, all compiler intermediates, binaries, cooked data, staging and packaged ZIPs |
| `/tmp/cg-cache` (read/write engine/cache disk) | CSS engine and its generated files, runtime state and the directories below |
| `/tmp/cg-cache/docker-home` | Unreal configuration/logs and engine registration |
| `/tmp/cg-cache/docker-home/ddc` | Writable filesystem derived-data cache |
| `/tmp/cg-cache/docker-wine-prefix` | Persistent Wine registry/initialization state |
| `/tmp/cg-cache/nuget` | .NET package cache (`NUGET_PACKAGES`) |
| `/tmp/cg-cache/cache` | General runtime caches (`XDG_CACHE_HOME`) |
| `/tmp/cg-cache/tmp` | Temporary downloads and extraction files (`TMPDIR`) |
| Runner checkout (read-only) | Git metadata referenced by the cached project's temporary `.git` link |
| `/opt/cartograph/msvc` (image, **not** a bind mount) | Installed compiler/Windows SDK/PDBCopy |
| `/opt/cartograph/wwise-plugins` (image, **not** a bind mount) | Immutable SDK/plugin templates, copied into the project once |

All state subdirectories are covered by the two main mounts. Stable absolute paths preserve compiler references; checksum-based source synchronization without timestamp updates keeps unchanged inputs warm. The shared build script owns UBT configuration and changes it only when necessary. Wine processes are stopped cleanly when containers exit. Build containers do not receive registry credentials or the Docker socket.

Blacksmith caches pulled Docker images automatically at no storage charge. Image publishing uses its persistent Docker-layer cache. Sticky disks and Docker **build-layer** caches are paid storage, currently documented at $0.50/GB/month, with inactivity eviction. Manage them at <https://app.blacksmith.sh>.

Toolchain keys include the pinned engine release, Docker inputs and engine setup script. Output keys also include branch/ref and ABI/configuration inputs. Increment the `v2` schema in the workflow or remove selected snapshots through Blacksmith to reset caches. Keep snapshots restricted to trusted organization runs; enable sticky-disk branch protection for default-branch publication.

## Output and validation

Download `Cartograph-Windows-Wine-<run>` from a successful run's Artifacts section. ZIP artifacts are retained for 90 days; release-triggered runs do not automatically attach them to the release.

The dependency-only image completed a local Docker build/package successfully. Cold/warm runs of the combined image still need validation before claiming measured speed improvements.

The SDK-inclusive image was built and published successfully, and a local full build using image-contained MSVC passed. The first CI attempt was cancelled after graphical engine registration stalled. Engine registration now writes the project association directly to `Install.ini` without launching `UnrealVersionSelector`/`zenity`. Provisioning has a 20-minute timeout. Full combined-image CI packaging remains unverified until a new run completes.
