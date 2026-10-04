# Build and CI

## Local builds: Docker only

```bash
./scripts/build-local.sh --check
./scripts/build-local.sh
```

All local Wine/compiler/Unreal processes run inside the dependency container. There is no native fallback, and the container-side script rejects direct host execution. The host needs Docker and the toolchain files, not Wine or compiler packages. See [LOCAL_BUILD.md](LOCAL_BUILD.md).

## CI: Linux/Wine only

The organization repository now has one build workflow: **Build Cartograph (Linux Wine)**. The native Windows workflow and its Windows-runner provisioning script have been removed. Existing repository history, the personal fork, and external runner resources are not deleted.

The workflow runs on push, published release, or manual dispatch using `blacksmith-32vcpu-ubuntu-2404` by default. It builds a **Windows Steam client package** for Satisfactory/Proton. Override `CARTOGRAPH_LINUX_RUNNER` only with an available compatible Linux x64 runner label.

Required repository secrets:

- `CSS_ENGINE_TOKEN`: read access to `satisfactorymodding/UnrealEngine`.
- `WWISE_EMAIL` and `WWISE_PASSWORD`: Audiokinetic credentials.

`CSS_ENGINE_RELEASE` pins the engine release; the default is `5.6.1-css-83`. Never store credentials in Dockerfiles, source files, or cache snapshots.

## Aggressive persistent caching

Two Blacksmith sticky disks persist:

1. **Toolchains:** extracted CSS engine, engine build outputs, compiled/patched Wine, MSVC and Windows SDK plus downloads, Wwise SDK/cache, NuGet packages, and filesystem derived-data cache.
2. **Branch-specific build tree:** generated headers, compiler intermediates, plugin binaries, integrated Wwise plugins, cooked data, staging outputs, and packaged ZIPs.

APT downloads are additionally cached with `actions/cache`. Stable `/tmp/cg-cache` and `/tmp/cg` paths prevent cached MSVC and Unreal paths becoming invalid. Source synchronization uses content checksums so unchanged files keep their timestamps. Installation markers skip completed setup; incomplete compiles resume using their existing outputs. Both disks use `commit: on-change`.

Toolchain keys include the pinned engine release, dependency list, setup scripts, OS and architecture. Output keys also include the branch/ref and ABI/configuration inputs. Increment the `v1` cache-key schema in the workflow to force a reset, or delete specific snapshots through Blacksmith's dashboard. Cache reuse and speed improvements still need validation on the first cold and subsequent warm runs of this updated workflow.

**Sticky disks are paid storage**, currently documented at $0.50/GB/month, with automatic eviction after seven days of inactivity. Large toolchain/output caches can occupy tens of GB. Manage them at <https://app.blacksmith.sh>.

This workflow intentionally has **no pull-request trigger**. Keep toolchain snapshots restricted to trusted organization runs; do not expose the cached engine/SDKs through public artifacts or images. Enable Blacksmith sticky-disk branch protection to constrain which branches can publish snapshots (default-branch runs only).

## Output

Download `Cartograph-Windows-Wine-<run>` from a successful run's Artifacts section. It contains `Cartograph-Windows.zip` and the merged package. Artifacts are retained for 90 days; release-triggered runs create Actions artifacts, not release attachments.
