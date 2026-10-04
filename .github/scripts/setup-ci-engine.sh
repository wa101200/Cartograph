#!/usr/bin/env bash
set -euo pipefail
: "${CI_CACHE_ROOT:?}" "${UE_CSS_ROOT:?}" "${ENGINE_RELEASE:?}" "${PROJECT_ROOT:?}"
mkdir -p "$UE_CSS_ROOT" "$CI_CACHE_ROOT/downloads/engine"
cd "$UE_CSS_ROOT"
if [ ! -f .cartograph-installed ] || [ "$(cat .cartograph-installed)" != "$ENGINE_RELEASE" ]; then
  gh release download "$ENGINE_RELEASE" --repo satisfactorymodding/UnrealEngine \
    --pattern 'UnrealEngine-CSS-Editor-Linux.tar.zst.*' \
    --dir "$CI_CACHE_ROOT/downloads/engine" --clobber
  cat "$CI_CACHE_ROOT"/downloads/engine/UnrealEngine-CSS-Editor-Linux.tar.zst.* | zstd -d | tar -xf -
  find "$CI_CACHE_ROOT/downloads/engine" -maxdepth 1 -type f \
    -name 'UnrealEngine-CSS-Editor-Linux.tar.zst.*' -delete
  printf '%s\n' "$ENGINE_RELEASE" > .cartograph-installed
else
  echo "Reusing CSS engine $ENGINE_RELEASE."
fi
python3 "$GITHUB_WORKSPACE/scripts/register-engine.py" "$UE_CSS_ROOT" "$PROJECT_ROOT/FactoryGame.uproject"
