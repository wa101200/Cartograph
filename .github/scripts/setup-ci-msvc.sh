#!/usr/bin/env bash
set -euo pipefail

msvc_scripts="$RUNNER_TEMP/cartograph-msvc-wine"
msvc_dir="$RUNNER_TEMP/cartograph-msvc"
debug_tools="$RUNNER_TEMP/X64.Debuggers.And.Tools-x64_en-us.msi"
git clone https://github.com/mircearoata/msvc-wine.git "$msvc_scripts"
git -C "$msvc_scripts" checkout 61b7cbc8cb9413fec8f0016ef433a90e06c37f54

"$msvc_scripts/vsdownload.py" --accept-license --dest "$msvc_dir" \
  --channel release.ltsc.17.8 --msvc-version 17.8 --sdk-version 10.0.22621 \
  Microsoft.Net.4.8.SDK Microsoft.VisualStudio.MinShell
wget -q -O "$debug_tools" \
  https://github.com/kbandla/installers/releases/latest/download/X64.Debuggers.And.Tools-x64_en-us.msi
msiextract -C "$msvc_dir" "$debug_tools" > /dev/null
"$msvc_scripts/install.sh" "$msvc_dir"

# PDBCopy wrapper from SML's Linux CI.
cat > "$msvc_dir/bin/x64/pdbcopy" <<'EOF'
#!/usr/bin/env bash
# Copyright (c) 2025 Mircea Roata
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
set -e
. "$(dirname "$0")/msvcenv.sh"
SDKDEBUGBINDIR="$SDKBASE/Debuggers/x64"
"$(dirname "$0")/wine-msvc.sh" "$SDKDEBUGBINDIR/pdbcopy.exe" "$@"
EOF
ln -sf ./pdbcopy "$msvc_dir/bin/x64/pdbcopy.exe"
chmod +x "$msvc_dir/bin/x64/pdbcopy" "$msvc_dir/bin/x64/pdbcopy.exe"
echo "UE_WINE_MSVC=$(realpath "$msvc_dir")" >> "$GITHUB_ENV"
