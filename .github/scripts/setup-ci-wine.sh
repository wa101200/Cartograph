#!/usr/bin/env bash
set -euo pipefail

# Install signed precompiled WineHQ packages. No Wine source build or fallback.
# Unlike SML's patched source build, the typelib patch is not guaranteed here;
# command-line MSVC/Unreal compatibility is tested by this experimental workflow.
wine_version='11.19~noble-1'
. /etc/os-release
if [ "$ID" != ubuntu ] || [ "$VERSION_ID" != 24.04 ]; then
  echo 'This Wine package setup requires Ubuntu 24.04.' >&2
  exit 1
fi
sudo dpkg --add-architecture i386
sudo mkdir -p /etc/apt/keyrings
wget -q -O "$RUNNER_TEMP/winehq.key" https://dl.winehq.org/wine-builds/winehq.key
gpg --batch --yes --dearmor -o "$RUNNER_TEMP/winehq-archive.key" "$RUNNER_TEMP/winehq.key"
sudo install -m 644 "$RUNNER_TEMP/winehq-archive.key" /etc/apt/keyrings/winehq-archive.key
wget -q -O "$RUNNER_TEMP/winehq-noble.sources" \
  https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources
sudo install -m 644 "$RUNNER_TEMP/winehq-noble.sources" /etc/apt/sources.list.d/winehq-noble.sources
sudo apt-get update
sudo apt-get install -y --install-recommends \
  "winehq-devel=$wine_version" "wine-devel=$wine_version" \
  "wine-devel-amd64=$wine_version" "wine-devel-i386:i386=$wine_version"
export PATH="/opt/wine-devel/bin:$PATH"
echo '/opt/wine-devel/bin' >> "$GITHUB_PATH"

mkdir -p "$WINEPREFIX"
WINEDLLOVERRIDES='mscoree,mshtml=' xvfb-run -a wineboot -u
wineserver -w
wine --version
