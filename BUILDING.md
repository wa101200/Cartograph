# Build and CI

## Local builds: Docker only

```bash
./scripts/build-local.sh --check
./scripts/build-local.sh
```

All local Wine/compiler/Unreal processes run inside the dependency container. There is no native fallback, and the container-side script rejects direct host execution. The host needs Docker and the toolchain files, not Wine or compiler packages. See [LOCAL_BUILD.md](LOCAL_BUILD.md).

## CI: Linux/Wine only

The organization repository now has one build workflow: **Build Cartograph (Linux Wine)**. The native Windows workflow and its Windows-runner provisioning script have been removed. Existing repository history, the personal fork, and external runner resources are not deleted.

The workflow runs on push, published release, or manual dispatch. A small `blacksmith-4vcpu-ubuntu-2404` job publishes the shared dependency image to GHCR only when the Docker inputs change. The build job uses `blacksmith-32vcpu-ubuntu-2404` by default and calls the same `scripts/build-local.sh` entrypoint used locally. It builds a **Windows Steam client package** for Satisfactory/Proton. Override `CARTOGRAPH_LINUX_RUNNER` only with an available compatible Linux x64 runner label.

CI and local builds use `docker/Dockerfile`: Ubuntu 24.04 and prebuilt stock Wine 11.0. CI no longer installs APT packages or compiles Wine on the runner. `scripts/docker-image-ref.sh` computes a content-addressed GHCR tag from the Dockerfile and Docker context filter; CI resolves that tag to a digest before starting any build container. Image publishing requires `packages: write` on the image job's `GITHUB_TOKEN`; builds require only `packages: read`. Package access must permit this repository's Actions token.

Required repository secrets:

- `CSS_ENGINE_TOKEN`: read access to `satisfactorymodding/UnrealEngine`.
- `WWISE_EMAIL` and `WWISE_PASSWORD`: Audiokinetic credentials.

`CSS_ENGINE_RELEASE` pins the engine release; the default is `5.6.1-css-83`. Never store credentials in Dockerfiles, source files, or cache snapshots.

## Aggressive persistent caching

Two Blacksmith sticky disks persist:

1. **Toolchains:** extracted CSS engine, engine build outputs, MSVC and Windows SDK plus downloads, Wwise SDK/cache, NuGet packages, filesystem derived-data cache, container HOME, temporary downloads, and the Wine prefix.
2. **Branch-specific build tree:** generated headers, compiler intermediates, plugin binaries, integrated Wwise plugins, cooked data, staging outputs, and packaged ZIPs.

Stable `/tmp/cg-cache` and `/tmp/cg` paths prevent cached MSVC and Unreal paths becoming invalid. Source synchronization uses content checksums without resetting timestamps. Installation markers skip completed setup; incomplete compiles resume using their existing outputs. Both disks use `commit: on-change`.

| Container path / mount | Persistent contents |
| --- | --- |
| `/tmp/cg` (read/write build disk) | Project, `Binaries`, all `Intermediate` trees, `Saved/Cooked`, staging, packaged ZIPs, Wwise plugins |
| `/tmp/cg-cache` (read/write toolchain disk) | Engine (including its generated files), MSVC/SDK, downloaded installers, Wwise CLI |
| `/tmp/cg-cache/docker-home` | Unreal configuration, engine registration, logs, and `ddc/` filesystem cache |
| `/tmp/cg-cache/cache` | `XDG_CACHE_HOME`: Wwise downloads and general runtime caches |
| `/tmp/cg-cache/nuget` | .NET package cache (`NUGET_PACKAGES`) |
| `/tmp/cg-cache/tmp` | Temporary toolchain downloads and extraction files (`TMPDIR`) |
| `/tmp/cg-cache/docker-wine-prefix` | Persistent Wine registry and initialization state |
| Runner checkout (read-only) | Current Git metadata referenced by the cached project's temporary `.git` link |

The subdirectories above are all covered by the toolchain bind mount; no nested anonymous volumes hide them. Provisioning and compilation use the same paths and non-root UID. Build containers do **not** receive registry login files or the Docker socket. The Wine prefix is stopped cleanly after each container exits.

Blacksmith automatically caches pulled Docker images for free, including digest-pinned GHCR images. Image builds use `useblacksmith/setup-docker-builder` and its persistent build-layer cache; there is no per-run image rebuild or APT restore.

Toolchain keys include the pinned engine release, Docker inputs, setup scripts, and architecture. Output keys also include the branch/ref and ABI/configuration inputs. Increment the `v2` cache-key schema in the workflow to force a reset, or delete specific snapshots through Blacksmith's dashboard. Cache reuse and speed improvements require cold and subsequent warm runs of this updated workflow.

**Sticky disks are paid storage**, currently documented at $0.50/GB/month, with automatic eviction after seven days of inactivity. Large toolchain/output caches can occupy tens of GB. Manage them at <https://app.blacksmith.sh>.

This workflow intentionally has **no pull-request trigger**. Keep toolchain snapshots restricted to trusted organization runs; do not expose the cached engine/SDKs through public artifacts or images. Enable Blacksmith sticky-disk branch protection to constrain which branches can publish snapshots (default-branch runs only).

## Output

Download `Cartograph-Windows-Wine-<run>` from a successful run's Artifacts section. It contains `Cartograph-Windows.zip` and the merged package. Artifacts are retained for 90 days; release-triggered runs create Actions artifacts, not release attachments.
