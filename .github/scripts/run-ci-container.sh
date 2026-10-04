#!/usr/bin/env bash
# Provision cached toolchains inside the exact image used for local builds.
set -euo pipefail
: "${CARTOGRAPH_DOCKER_IMAGE:?}"
: "${CI_CACHE_ROOT:?}"
: "${PROJECT_ROOT:?}"
: "${GITHUB_WORKSPACE:?}"
home="$CI_CACHE_ROOT/docker-home"
mkdir -p "$home" "$WINEPREFIX" "$CI_CACHE_ROOT/tmp" "$CI_CACHE_ROOT/cache" "$CI_CACHE_ROOT/nuget"
docker run --rm --init --platform linux/amd64 \
  --user "$(id -u):$(id -g)" --shm-size 2g \
  --workdir "$GITHUB_WORKSPACE" \
  --mount "type=bind,src=$GITHUB_WORKSPACE,dst=$GITHUB_WORKSPACE,readonly" \
  --mount "type=bind,src=$CI_CACHE_ROOT,dst=$CI_CACHE_ROOT" \
  --mount "type=bind,src=$PROJECT_ROOT,dst=$PROJECT_ROOT" \
  --mount "type=bind,src=$WINEPREFIX,dst=$WINEPREFIX" \
  --env "HOME=$home" --env CI_CACHE_ROOT --env PROJECT_ROOT \
  --env "TMPDIR=$CI_CACHE_ROOT/tmp" --env "XDG_CACHE_HOME=$CI_CACHE_ROOT/cache" \
  --env "NUGET_PACKAGES=$CI_CACHE_ROOT/nuget" \
  --env GITHUB_WORKSPACE --env UE_CSS_ROOT --env ENGINE_RELEASE \
  --env WINEPREFIX --env WINEARCH --env WINEDEBUG \
  --env GH_TOKEN --env WWISE_EMAIL --env WWISE_PASSWORD \
  --env GITHUB_ENV=/tmp/cartograph-env \
  --entrypoint /bin/bash "$CARTOGRAPH_DOCKER_IMAGE" -euo pipefail -c '
    trap "wineserver -k >/dev/null 2>&1 || true" EXIT
    WINEDLLOVERRIDES="mscoree,mshtml=" timeout 120 xvfb-run -a wineboot -u
    bash .github/scripts/setup-ci-msvc.sh
    bash .github/scripts/prepare-ci-project.sh
    bash .github/scripts/setup-ci-engine.sh
    bash .github/scripts/setup-ci-wwise.sh
  '
