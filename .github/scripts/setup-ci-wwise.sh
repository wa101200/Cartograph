#!/usr/bin/env bash
set -euo pipefail
: "${CI_CACHE_ROOT:?}"
: "${PROJECT_ROOT:?}"
cli="$CI_CACHE_ROOT/wwise-cli"
if [ ! -x "$cli" ]; then
  gh release download v0.2.4 --repo mircearoata/wwise-cli \
    --pattern wwise-cli_linux_amd64 --output "$cli" --clobber
  chmod +x "$cli"
fi
# Authentication is held in memory by wwise-cli. Cache only downloaded SDKs and
# integration files; never save shell environments or authentication config.
export XDG_CACHE_HOME="$CI_CACHE_ROOT/wwise-cache"
if [ ! -f "$CI_CACHE_ROOT/.wwise-sdk-installed" ]; then
  "$cli" download --sdk-version '2023.1.14.8770' --filter Packages=SDK \
    --filter DeploymentPlatforms=Windows_vc160 --filter DeploymentPlatforms=Windows_vc170 \
    --filter DeploymentPlatforms=Linux --filter DeploymentPlatforms= > /dev/null
  touch "$CI_CACHE_ROOT/.wwise-sdk-installed"
else
  echo 'Reusing cached Wwise SDK 2023.1.14.8770.'
fi
if [ ! -f "$PROJECT_ROOT/Plugins/Wwise/Wwise.uplugin" ] || \
   [ ! -f "$PROJECT_ROOT/Plugins/WwiseNiagara/WwiseNiagara.uplugin" ]; then
  "$cli" integrate-ue --integration-version '2023.1.14.3555' \
    --project "$PROJECT_ROOT/FactoryGame.uproject" > /dev/null
else
  echo 'Reusing cached Wwise project integration.'
fi
test -f "$PROJECT_ROOT/Plugins/Wwise/Wwise.uplugin"
test -f "$PROJECT_ROOT/Plugins/WwiseNiagara/WwiseNiagara.uplugin"
