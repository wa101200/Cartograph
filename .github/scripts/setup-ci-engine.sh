#!/usr/bin/env bash
set -euo pipefail
: "${CI_CACHE_ROOT:?}"
: "${UE_CSS_ROOT:?}"
: "${ENGINE_RELEASE:?Pin the CSS engine release for reproducible caching}"
mkdir -p "$UE_CSS_ROOT" "$CI_CACHE_ROOT/downloads/engine"
cd "$UE_CSS_ROOT"
if [ ! -f .cartograph-installed ] || [ "$(cat .cartograph-installed)" != "$ENGINE_RELEASE" ]; then
  gh release download "$ENGINE_RELEASE" --repo satisfactorymodding/UnrealEngine \
    --pattern 'UnrealEngine-CSS-Editor-Linux.tar.zst.*' \
    --dir "$CI_CACHE_ROOT/downloads/engine" --clobber
  cat "$CI_CACHE_ROOT"/downloads/engine/UnrealEngine-CSS-Editor-Linux.tar.zst.* | zstd -d | tar -xf -
  # Delete only the downloaded archive parts, after complete extraction.
  find "$CI_CACHE_ROOT/downloads/engine" -maxdepth 1 -type f \
    -name 'UnrealEngine-CSS-Editor-Linux.tar.zst.*' -delete
else
  echo "Reusing cached CSS engine $ENGINE_RELEASE."
fi
python3 - <<'PY'
import json
with open('Engine/Build/Build.version') as f:
    version = json.load(f)
assert [version[k] for k in ('MajorVersion', 'MinorVersion', 'PatchVersion')] == [5, 6, 1], 'Wrong engine version'
PY
xvfb-run -a ./Engine/Binaries/Linux/UnrealVersionSelector -register -unattended
printf '%s\n' "$ENGINE_RELEASE" > .cartograph-installed
