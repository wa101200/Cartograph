#!/usr/bin/env bash
# Build-time preparation uses only UE 5.6 version metadata, not engine binaries.
set -euo pipefail
export WWISE_EMAIL WWISE_PASSWORD
WWISE_EMAIL=$(cat /run/secrets/WWISE_EMAIL)
WWISE_PASSWORD=$(cat /run/secrets/WWISE_PASSWORD)
work=$(mktemp -d)
export HOME="$work/home" XDG_CACHE_HOME="$work/cache"
mkdir -p "$HOME/.config/Epic/UnrealEngine" "$work/engine/Engine/Build" "$work/project"
curl --fail --location --retry 3 \
  https://github.com/mircearoata/wwise-cli/releases/download/v0.2.4/wwise-cli_linux_amd64 \
  --output /usr/local/bin/wwise-cli
chmod +x /usr/local/bin/wwise-cli
wwise-cli download --sdk-version '2023.1.14.8770' --filter Packages=SDK \
  --filter DeploymentPlatforms=Windows_vc160 --filter DeploymentPlatforms=Windows_vc170 \
  --filter DeploymentPlatforms=Linux --filter DeploymentPlatforms= > /dev/null
printf '[Installations]\nUE_5.6=%s\n' "$work/engine" > "$HOME/.config/Epic/UnrealEngine/Install.ini"
printf '{"MajorVersion":5,"MinorVersion":6,"PatchVersion":1}\n' > "$work/engine/Engine/Build/Build.version"
printf '{"EngineAssociation":"5.6"}\n' > "$work/project/Template.uproject"
wwise-cli integrate-ue --integration-version '2023.1.14.3555' \
  --project "$work/project/Template.uproject" > /dev/null
test -f "$work/project/Plugins/Wwise/Wwise.uplugin"
test -f "$work/project/Plugins/WwiseNiagara/WwiseNiagara.uplugin"
mkdir -p /opt/cartograph
mv "$work/project/Plugins" /opt/cartograph/wwise-plugins
chmod -R a+rX /opt/cartograph/wwise-plugins
# Keep only the integrated templates, not a second copy of the downloaded SDK.
python3 - "$work" <<'PY'
import shutil, sys
shutil.rmtree(sys.argv[1])
PY
