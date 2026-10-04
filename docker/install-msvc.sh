#!/usr/bin/env bash
# Image-build only: install the pinned cross-compiler once, not on every runner.
set -euo pipefail
scripts=/tmp/msvc-wine
destination=/opt/cartograph/msvc
cache=/var/cache/cartograph-msvc
mkdir -p "$cache" "$destination"
git clone https://github.com/mircearoata/msvc-wine.git "$scripts"
git -C "$scripts" checkout 61b7cbc8cb9413fec8f0016ef433a90e06c37f54
"$scripts/vsdownload.py" --accept-license --dest "$destination" --cache "$cache" \
  --channel release.ltsc.17.8 --msvc-version 17.8 --sdk-version 10.0.22621 \
  Microsoft.Net.4.8.SDK Microsoft.VisualStudio.MinShell
debug_tools="$cache/X64.Debuggers.And.Tools-x64_en-us.msi"
if [ ! -f "$debug_tools" ]; then
  wget --timeout=30 --tries=3 -O "$debug_tools.part" \
    https://github.com/kbandla/installers/releases/latest/download/X64.Debuggers.And.Tools-x64_en-us.msi
  mv "$debug_tools.part" "$debug_tools"
fi
msiextract -C "$destination" "$debug_tools" > /dev/null
"$scripts/install.sh" "$destination"
cat > "$destination/bin/x64/pdbcopy" <<'EOF'
#!/usr/bin/env bash
set -e
. "$(dirname "$0")/msvcenv.sh"
"$(dirname "$0")/wine-msvc.sh" "$SDKBASE/Debuggers/x64/pdbcopy.exe" "$@"
EOF
chmod +x "$destination/bin/x64/pdbcopy"
ln -s ./pdbcopy "$destination/bin/x64/pdbcopy.exe"
# Remove only the temporary public installer checkout; cache mounts aren't layers.
python3 - "$scripts" <<'PY'
import shutil, sys
shutil.rmtree(sys.argv[1])
PY
