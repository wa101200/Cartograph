# Native Linux/Wine builds

Both local builds and CI now run **without Docker**. See [LOCAL_BUILD.md](LOCAL_BUILD.md) for local prerequisites and usage.

```bash
./scripts/build-local.sh --check
./scripts/build-local.sh
```

## CI

**Build Cartograph (Linux Wine)** is the only build workflow. It runs on push, published release, or manual dispatch, using `blacksmith-32vcpu-ubuntu-2404` by default (32 vCPU, 128 GB RAM, 1.5 TB disk). Windows CI remains removed. The personal fork is unchanged.

The workflow installs Linux dependencies directly on the runner, restores/builds patched Wine 11, restores/installs MSVC 17.8 and Windows SDK 10.0.22621, downloads/registers the pinned CSS engine, integrates Wwise, and calls the native `scripts/build-local.sh` entrypoint.

Required secrets remain:

- `CSS_ENGINE_TOKEN`: read access to `satisfactorymodding/UnrealEngine`.
- `WWISE_EMAIL`, `WWISE_PASSWORD`: Audiokinetic credentials.

`CSS_ENGINE_RELEASE` defaults to **5.6.1-css-83**. `CARTOGRAPH_LINUX_RUNNER` may override the runner with an actually available Linux x64 label. Docker Hub credentials and image-publishing steps have been removed.

## Caching and stall prevention

Two Blacksmith sticky disks persist installed toolchains/downloads/runtime caches and branch-specific compiler/cooker outputs. APT downloads use Actions cache. Paths remain stable (`/tmp/cg-cache`, `/tmp/cg`), and source synchronization preserves unchanged timestamps. Cache keys include dependency/setup inputs, pinned engine release, branch/ref and ABI inputs.

Sticky disks are paid storage; manage snapshots at <https://app.blacksmith.sh>. Inactive old experiment snapshots are subject to Blacksmith's eviction policy.

The graphical engine registration that stalled is **not restored**: `scripts/register-engine.py` performs headless `Install.ini` registration. Setup steps have bounded timeouts. Compilation/packaging has a 10-minute no-output watchdog and 60-minute maximum duration. Wine processes in the isolated CI prefix are stopped on completion or failure.

## Output

The build compiles a Linux editor and packages the **Windows Steam client mod** for Satisfactory/Proton. Download `Cartograph-Windows-Wine-<run>` from a successful run. ZIP artifacts are retained for 90 days; release-triggered runs do not automatically attach them to releases. No build installs a mod or launches the game.

The native predecessor CI succeeded; the restored workflow has passed static validation, while the local host toolchain passed its smoke test. A fresh full CI run has not been started as part of cleanup.
