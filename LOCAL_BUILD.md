# Docker-based local build

`scripts/build-local.sh` runs the build **inside Docker**. The host needs Docker and the licensed toolchain files; Wine, Python, msitools, GitHub CLI, and other Linux build dependencies come from the container. The procedure compiles the Linux editor and packages the **Windows Steam mod**. It does not install it or launch the game.

Docker is mandatory: there is no native fallback. The inner script checks both the launcher's container marker and `/.dockerenv` and refuses direct host execution. The complete Docker build/cook/package path was successfully tested with this image and mounted toolchain.

## Run

On the machine whose toolchain was set up in this session:

```bash
./scripts/build-local.sh --check  # Dependencies/toolchain smoke test
./scripts/build-local.sh          # Build/package using all host CPU threads
```

The launcher selects the same content-addressed GHCR dependency image as CI, using `scripts/docker-image-ref.sh`. On first use it pulls that image; if it is unpublished or inaccessible, it builds the same Dockerfile locally. Later runs reuse it. Use `--rebuild-image` to rebuild the dependency layer locally before building the mod. `CARTOGRAPH_DOCKER_IMAGE=ghcr.io/wa101200/cartograph-build@sha256:...` can pin the exact digest reported by CI.

If the GHCR package is private, first authenticate Docker to `ghcr.io` with a GitHub token authorized to read the package. Registry authentication stays on the host and is not mounted into build containers.

To limit parallel compilation:

```bash
JOBS=4 ./scripts/build-local.sh
```

Output remains on the host:

```text
Saved/ArchivedPlugins/Cartograph/Cartograph-Windows.zip
```

## Base-image research

The Dockerfile extends **[scottyhardy/docker-wine](https://github.com/scottyhardy/docker-wine)**, verified as Linux amd64, Ubuntu 24.04, and prebuilt Wine 11.0. It already provides most Wine, graphics/audio, Python, Git, and headless-display dependencies. The image is pinned to digest `sha256:5a2b4179c125cc28c1ffcfeea6f3e3f678fd5caddcc8b601258fd1b6e755c995`; the Dockerfile adds build-essential, msitools, gh, dos2unix, and Unreal/.NET runtime dependencies. Its desktop-service entrypoint is bypassed.

Other candidates were investigated:

- `ghcr.io/mstorsjo/wine:latest`: the published manifest was **ARM64-only**, incompatible with this x64 toolchain.
- [mstorsjo/msvc-wine's Dockerfile](https://github.com/mstorsjo/msvc-wine/blob/master/Dockerfile): a useful reference, but upstream explicitly does not publish the resulting MSVC images because the installed tools are not redistributable.
- Epic's standard Unreal images: contain the wrong engine for Satisfactory. The custom **5.6.1-CSS** engine must be supplied separately, and downloading a second full engine wastes substantial space.

## Toolchain mounts and licensing

The public dependency image contains **no CSS Unreal Engine, MSVC SDK, Wwise SDK, or credentials**. These remain in host directories and are bind-mounted at runtime. Do not publish images that include these licensed dependencies.

Default host locations under `~/.local/share/cartograph-build`:

| Path | Contents |
| --- | --- |
| `ue/` | Registered CSS Unreal Engine 5.6.1-CSS Linux editor |
| `msvc/` | MSVC 17.8 / 14.38 + Windows SDK 10.0.22621, with `ue-patches` msvc-wine wrappers |
| `wwise-cli` | Optional Wwise integration CLI |
| `cache/` | Optional downloaded Wwise SDK |
| `nuget/` | .NET package cache |
| `tmp/` | Persistent temporary downloads and extraction files |
| `docker-home/` | Container-only HOME/configuration |
| `docker-home/ddc/` | Writable filesystem derived-data cache; avoids launching Zen in Docker |
| `docker-wine-prefix/` | Container-only Wine prefix |

The project must contain Wwise SDK/plugin integration **2023.1.14.8770 / 2023.1.14.3555** in `Plugins/Wwise` and `Plugins/WwiseNiagara`. Missing integration can use the existing SDK cache and `wwise-cli`. Engine registration is performed in the container if needed for that integration.

Override `CARTOGRAPH_BUILD_ROOT`, `UE_CSS_ROOT`, and `UE_WINE_MSVC` for different toolchain locations. `CARTOGRAPH_WINEPREFIX` selects another dedicated container prefix. `CARTOGRAPH_CACHE_HOME`, `CARTOGRAPH_TMPDIR`, and `NUGET_PACKAGES` select alternate persistent cache directories. All custom directories outside the build root are explicitly bind-mounted at the same absolute paths. An existing compatible image can be selected with `CARTOGRAPH_DOCKER_IMAGE`; it must provide the same build/runtime commands.

## Isolation and credentials

- The container runs under your host UID/GID, **not root**, so generated files remain yours and Unreal accepts the user.
- Project and toolchain paths are mounted at the same absolute paths to preserve MSVC wrapper paths and incremental-build caches.
- Only project/toolchain directories are mounted: **not the game, host home directory, or Docker socket**.
- The dedicated Wine prefix avoids changing the host `.wine` or the earlier native-build prefix.
- `GH_TOKEN`, `WWISE_EMAIL`, and `WWISE_PASSWORD` are forwarded only if supplied in the invoking shell. They are never embedded in the image or script. Your host GitHub login configuration is not mounted.
- Docker shared memory is set to 2 GiB. Compilation allows all host CPUs unless `JOBS` is set.

The container-side script updates project-local `Saved/UnrealBuildTool/BuildConfiguration.xml`: no UBA, no debug information, and the selected parallel-action count, preserving unrelated options. This lowers disk usage. Packaging is Steam-only, not Epic Games Store or dedicated-server packaging. No GPU or privileged container access is required for this headless build procedure.

Cooking uses `-ddc=InstalledNoZenLocalFallback` with `UE-LocalDataCachePath` pointing to the persistent container cache directory. This bypasses Zen auto-launch, which failed in the first container cook attempt, while retaining a writable filesystem cache.
