#!/usr/bin/env bash
set -euo pipefail
cache_root="${CI_CACHE_ROOT:-$RUNNER_TEMP/cartograph-cache}"
mkdir -p "$cache_root/downloads/msvc"
scripts="$cache_root/msvc-wine"
destination="$cache_root/msvc"
debug_tools="$cache_root/downloads/X64.Debuggers.And.Tools-x64_en-us.msi"
if [ ! -d "$scripts/.git" ]; then git clone https://github.com/mircearoata/msvc-wine.git "$scripts"; fi
git -C "$scripts" checkout 61b7cbc8cb9413fec8f0016ef433a90e06c37f54
if [ ! -f "$destination/.installed" ]; then
  "$scripts/vsdownload.py" --accept-license --dest "$destination" \
    --cache "$cache_root/downloads/msvc" --channel release.ltsc.17.8 \
    --msvc-version 17.8 --sdk-version 10.0.22621 \
    Microsoft.Net.4.8.SDK Microsoft.VisualStudio.MinShell
  if [ ! -f "$debug_tools" ]; then
    wget --timeout=30 --tries=3 -O "$debug_tools.part" \
      https://github.com/kbandla/installers/releases/latest/download/X64.Debuggers.And.Tools-x64_en-us.msi
    mv "$debug_tools.part" "$debug_tools"
  fi
  msiextract -C "$destination" "$debug_tools" > /dev/null
  "$scripts/install.sh" "$destination"
fi
if [ ! -f "$destination/bin/x64/pdbcopy" ]; then
  cat > "$destination/bin/x64/pdbcopy" <<'EOF'
#!/usr/bin/env bash
set -e
. "$(dirname "$0")/msvcenv.sh"
"$(dirname "$0")/wine-msvc.sh" "$SDKBASE/Debuggers/x64/pdbcopy.exe" "$@"
EOF
  ln -sf ./pdbcopy "$destination/bin/x64/pdbcopy.exe"
  chmod +x "$destination/bin/x64/pdbcopy"
fi
echo "UE_WINE_MSVC=$(realpath "$destination")" >> "$GITHUB_ENV"
timeout 120 "$destination/bin/x64/cl" /? > /dev/null
if [ ! -f "$destination/.installed" ]; then touch "$destination/.installed"; fi
