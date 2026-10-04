#!/usr/bin/env bash
set -euo pipefail

# Matches SML's current Linux CI: new WoW64 Wine with the oleaut32 typelib fix.
# Wine's source and patch are public. No licensed engine/toolchain cache is uploaded.
wine_source="$RUNNER_TEMP/cartograph-wine-source"
wine_patch="$RUNNER_TEMP/cartograph-wine-typelib.patch"
wget -q -O "$wine_patch" https://gitlab.winehq.org/wine/wine/-/merge_requests/9640.patch
git clone --depth 1 --branch wine-11.0 https://gitlab.winehq.org/wine/wine.git "$wine_source"
git -C "$wine_source" -c user.name='Cartograph CI' -c user.email='ci@example.com' am "$wine_patch"
mkdir -p "$wine_source/build"
cd "$wine_source/build"
../configure --enable-archs=x86_64,i386 --without-tests
make -j"$(nproc)"
sudo make install

mkdir -p "$WINEPREFIX"
WINEDLLOVERRIDES='mscoree,mshtml=' xvfb-run -a wineboot -u
wineserver -w
wine --version
