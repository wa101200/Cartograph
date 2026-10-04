#!/usr/bin/env bash
set -euo pipefail
cache_root="${CI_CACHE_ROOT:-$RUNNER_TEMP/cartograph-cache}"
mkdir -p "$cache_root/downloads"
wine_patch="$cache_root/downloads/wine_typelib.patch"
wget --timeout=30 --tries=3 -O "$wine_patch" \
  https://gitlab.winehq.org/wine/wine/-/merge_requests/9640.patch
patch_hash=$(sha256sum "$wine_patch" | cut -d' ' -f1)
wine_source="$cache_root/wine-source-11.0-$patch_hash"
wine_install="$cache_root/wine-install-11.0-$patch_hash"
if [ ! -f "$wine_install/.installed" ]; then
  if [ ! -d "$wine_source/.git" ]; then
    git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=60 clone --depth 1 \
      --branch wine-11.0 https://gitlab.winehq.org/wine/wine.git "$wine_source"
  fi
  if [ ! -f "$wine_source/.patch-applied" ]; then
    git -C "$wine_source" -c user.name='Cartograph CI' -c user.email='ci@example.com' am "$wine_patch"
    touch "$wine_source/.patch-applied"
  fi
  mkdir -p "$wine_source/build"
  cd "$wine_source/build"
  ../configure --prefix="$wine_install" --enable-archs=x86_64,i386 --without-tests
  make -j"$(nproc)"
  make install
  "$wine_install/bin/wine" --version
  touch "$wine_install/.installed"
else
  echo 'Reusing cached patched Wine 11.0.'
fi
export PATH="$wine_install/bin:$PATH"
echo "$wine_install/bin" >> "$GITHUB_PATH"
mkdir -p "$WINEPREFIX"
WINEDLLOVERRIDES='mscoree,mshtml=' timeout 120 xvfb-run -a wineboot -u
timeout 120 wineserver -w
wine --version
