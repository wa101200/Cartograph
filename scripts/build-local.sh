#!/usr/bin/env bash
# Host launcher: OS dependencies and Wine run exclusively inside Docker.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/build-local.sh [--check | --rebuild-image | --help]

Default: build/package the Windows Steam mod inside Docker.
--check: verify container dependencies and mounted toolchains, without building.
--rebuild-image: rebuild the local dependency image, then build/package the mod.

Optional environment variables:
  JOBS                    Parallel compiler actions (default: all host CPUs).
  CARTOGRAPH_BUILD_ROOT   Toolchain root (default: ~/.local/share/cartograph-build).
  UE_CSS_ROOT             CSS engine folder (default: BUILD_ROOT/ue).
  UE_WINE_MSVC            MSVC folder (default: BUILD_ROOT/msvc).
  CARTOGRAPH_DOCKER_IMAGE Existing compatible image (default: cartograph-build:local).
  CARTOGRAPH_WINEPREFIX   Dedicated Docker Wine prefix (default: BUILD_ROOT/docker-wine-prefix).

No game installation, Docker socket, or host home directory is mounted.
EOF
}

mode=build
case "${1:-}" in
  '') ;;
  --check) mode=check ;;
  --rebuild-image) mode=rebuild ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then usage >&2; exit 1; fi

command -v docker >/dev/null || { echo 'Docker is required.' >&2; exit 1; }
docker info >/dev/null || { echo 'Cannot access the Docker daemon.' >&2; exit 1; }
if [ "$(id -u)" -eq 0 ]; then
  echo 'Run as a non-root user with Docker access; Unreal refuses root builds.' >&2
  exit 1
fi
case "$(docker info --format '{{.Architecture}}')" in
  x86_64|amd64) ;;
  *) echo 'The CSS/MSVC toolchain requires a Linux amd64 Docker daemon.' >&2; exit 1 ;;
esac

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="${CARTOGRAPH_BUILD_ROOT:-$HOME/.local/share/cartograph-build}"
engine_root="${UE_CSS_ROOT:-$build_root/ue}"
msvc_root="${UE_WINE_MSVC:-$build_root/msvc}"
image="${CARTOGRAPH_DOCKER_IMAGE:-cartograph-build:local}"
jobs="${JOBS:-$(nproc)}"
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then echo 'JOBS must be a positive integer.' >&2; exit 1; fi

# Canonical paths are mounted unchanged so MSVC wrappers and cached build paths
# continue to resolve, including SDK paths emitted by msvc-wine's installer.
for path in "$build_root" "$engine_root" "$msvc_root"; do
  if [ ! -d "$path" ]; then echo "Missing toolchain directory: $path. See LOCAL_BUILD.md." >&2; exit 1; fi
done
build_root="$(realpath "$build_root")"
engine_root="$(realpath "$engine_root")"
msvc_root="$(realpath "$msvc_root")"
container_home="$build_root/docker-home"
wine_prefix="${CARTOGRAPH_WINEPREFIX:-$build_root/docker-wine-prefix}"
mkdir -p "$container_home" "$container_home/ddc" "$wine_prefix"
wine_prefix="$(realpath "$wine_prefix")"

if [ "$mode" = rebuild ] || ! docker image inspect "$image" >/dev/null 2>&1; then
  if [ -n "${CARTOGRAPH_DOCKER_IMAGE:-}" ]; then
    docker pull "$image"
  else
    # The context contains only the Dockerfile, not licensed SDKs or credentials.
    docker build --platform linux/amd64 --tag "$image" "$project_root/docker"
  fi
fi

args=(run --rm --init --platform linux/amd64
  --user "$(id -u):$(id -g)" --shm-size 2g
  --workdir "$project_root"
  --mount "type=bind,src=$project_root,dst=$project_root"
  --mount "type=bind,src=$build_root,dst=$build_root"
  --env "HOME=$container_home"
  --env "UE-LocalDataCachePath=$container_home/ddc"
  --env "CARTOGRAPH_BUILD_ROOT=$build_root"
  --env CARTOGRAPH_IN_DOCKER=1
  --env "UE_CSS_ROOT=$engine_root" --env "UE_WINE_MSVC=$msvc_root"
  --env "WINEPREFIX=$wine_prefix" --env WINEARCH=win64 --env WINEDEBUG=-all
  --env "JOBS=$jobs")

# Mount custom paths only when they are outside the already-mounted build root.
for path in "$engine_root" "$msvc_root" "$wine_prefix"; do
  case "$path" in
    "$build_root"|"$build_root"/*) ;;
    *) args+=(--mount "type=bind,src=$path,dst=$path") ;;
  esac
done
# Optional secrets are runtime environment only, never Docker build arguments.
for name in GH_TOKEN WWISE_EMAIL WWISE_PASSWORD; do
  if [ -n "${!name:-}" ]; then args+=(--env "$name"); fi
done

args+=(--entrypoint /bin/bash "$image" "$project_root/scripts/build-local-inner.sh")
if [ "$mode" = check ]; then args+=(--check); fi
exec docker "${args[@]}"
