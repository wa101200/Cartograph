#!/usr/bin/env bash
set -euo pipefail

# SML's source-built Wine avoids WineHQ package-server and i386-repository setup.
wine_source="$RUNNER_TEMP/cartograph-wine-source"
wine_patch="$RUNNER_TEMP/cartograph-wine-typelib.patch"
echo 'Downloading the SML typelib patch...'
wget --timeout=30 --tries=3 -O "$wine_patch" \
  https://gitlab.winehq.org/wine/wine/-/merge_requests/9640.patch
echo 'Checking out Wine 11.0...'
git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=60 clone --depth 1 \
  --branch wine-11.0 https://gitlab.winehq.org/wine/wine.git "$wine_source"
git -C "$wine_source" -c user.name='Cartograph CI' -c user.email='ci@example.com' am "$wine_patch"
mkdir -p "$wine_source/build"
cd "$wine_source/build"
echo "Configuring and compiling Wine with $(nproc) parallel jobs..."
../configure --enable-archs=x86_64,i386 --without-tests
make -j"$(nproc)"
sudo make install

mkdir -p "$WINEPREFIX"
echo 'Initializing the Wine prefix...'
WINEDLLOVERRIDES='mscoree,mshtml=' xvfb-run -a wineboot -u
wineserver -w
wine --version
