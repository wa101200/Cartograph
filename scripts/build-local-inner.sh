#!/usr/bin/env bash
# Container-side build procedure. Use scripts/build-local.sh on the host.
set -euo pipefail

if [ "${CARTOGRAPH_IN_DOCKER:-}" != 1 ] || [ ! -f /.dockerenv ]; then
  echo 'Local builds must run through Docker. Use scripts/build-local.sh.' >&2
  exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$project_root/FactoryGame.uproject"
export CARTOGRAPH_BUILD_ROOT="${CARTOGRAPH_BUILD_ROOT:-$HOME/.local/share/cartograph-build}"
export UE_CSS_ROOT="${UE_CSS_ROOT:-$CARTOGRAPH_BUILD_ROOT/ue}"
export UE_WINE_MSVC="${UE_WINE_MSVC:-$CARTOGRAPH_BUILD_ROOT/msvc}"
export WINEPREFIX="${WINEPREFIX:-$CARTOGRAPH_BUILD_ROOT/wine-prefix}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDEBUG="${WINEDEBUG:--all}"
export TMPDIR="${CARTOGRAPH_TMPDIR:-$CARTOGRAPH_BUILD_ROOT/tmp}"
export XDG_CACHE_HOME="${CARTOGRAPH_CACHE_HOME:-$CARTOGRAPH_BUILD_ROOT/cache}"
parallel_jobs="${JOBS:-$(nproc)}"

if [[ ! "$parallel_jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo 'JOBS must be a positive integer.' >&2
  exit 1
fi
for command in wine gh python3 msiextract; do
  if ! command -v "$command" >/dev/null; then
    echo "Required command not found: $command. See LOCAL_BUILD.md." >&2
    exit 1
  fi
done
for executable in \
  "$UE_CSS_ROOT/Engine/Build/BatchFiles/Linux/Build.sh" \
  "$UE_CSS_ROOT/Engine/Build/BatchFiles/RunUAT.sh" \
  "$UE_WINE_MSVC/bin/x64/cl"; do
  if [ ! -x "$executable" ]; then
    echo "Required tool not found or not executable: $executable" >&2
    exit 1
  fi
done
mkdir -p "$TMPDIR" "$CARTOGRAPH_BUILD_ROOT/packages"
mkdir -p "$HOME" "$WINEPREFIX"
# Keep Wine state in a dedicated container prefix, never the host user's .wine.
WINEDLLOVERRIDES='mscoree,mshtml=' timeout 120 xvfb-run -a wineboot -u
trap 'wineserver -k >/dev/null 2>&1 || true' EXIT
"$UE_WINE_MSVC/bin/x64/cl" /? > /dev/null
cd "$project_root"

if [ "${1:-}" = --check ]; then
  wine --version
  "$UE_WINE_MSVC/bin/x64/cl" /? 2>&1 | tail -4
  dotnet="$UE_CSS_ROOT/Engine/Binaries/ThirdParty/DotNet/8.0.300/linux-x64/dotnet"
  "$dotnet" --info
  echo 'Container dependencies and mounted MSVC/CSS engine checks passed.'
  exit 0
fi

if [ ! -f Plugins/Wwise/Wwise.uplugin ] || [ ! -f Plugins/WwiseNiagara/WwiseNiagara.uplugin ]; then
  cli="$CARTOGRAPH_BUILD_ROOT/wwise-cli"
  if [ ! -x "$cli" ]; then
    echo "Wwise is missing; install wwise-cli and download its SDK first. See LOCAL_BUILD.md." >&2
    exit 1
  fi
  xvfb-run -a "$UE_CSS_ROOT/Engine/Binaries/Linux/UnrealVersionSelector" -register -unattended
  # Existing SDK cache or environment credentials are used by wwise-cli.
  "$cli" integrate-ue --integration-version '2023.1.14.3555' --project "$project" > /dev/null
fi

# These settings also apply to the shipping build invoked internally by Alpakit.
# Preserve unrelated existing project-local UBT settings.
python3 - "$project_root" "$parallel_jobs" <<'PY'
import pathlib, sys, xml.etree.ElementTree as ET
path = pathlib.Path(sys.argv[1]) / 'Saved/UnrealBuildTool/BuildConfiguration.xml'
namespace = 'https://www.unrealengine.com/BuildConfiguration'
ET.register_namespace('', namespace)
tag = lambda name: '{' + namespace + '}' + name
if path.exists():
    tree = ET.parse(path)
    root = tree.getroot()
    if root.tag != tag('Configuration'):
        raise SystemExit(f'Unexpected XML root in {path}; refusing to overwrite it.')
else:
    root = ET.Element(tag('Configuration'))
    tree = ET.ElementTree(root)
section = root.find(tag('BuildConfiguration'))
if section is None:
    section = ET.SubElement(root, tag('BuildConfiguration'))
for name, value in [('bAllowUBAExecutor', 'false'), ('MaxParallelActions', sys.argv[2]), ('DebugInfo', 'None')]:
    element = section.find(tag(name))
    if element is None:
        element = ET.SubElement(section, tag(name))
    element.text = value
import io
contents = io.BytesIO()
tree.write(contents, encoding='utf-8', xml_declaration=True)
path.parent.mkdir(parents=True, exist_ok=True)
if not path.exists() or path.read_bytes() != contents.getvalue():
    path.write_bytes(contents.getvalue())
PY

# Provide the Windows SDK debug tool used by Alpakit's staging step.
if [ ! -f "$UE_WINE_MSVC/bin/x64/pdbcopy" ]; then
  debug_tools="$CARTOGRAPH_BUILD_ROOT/packages/X64.Debuggers.And.Tools-x64_en-us.msi"
  if [ ! -f "$debug_tools" ]; then
    gh release download --repo kbandla/installers \
      --pattern X64.Debuggers.And.Tools-x64_en-us.msi --output "$debug_tools"
  fi
  msiextract -C "$UE_WINE_MSVC" "$debug_tools" > /dev/null
  cat > "$UE_WINE_MSVC/bin/x64/pdbcopy" <<'EOF'
#!/usr/bin/env bash
set -e
. "$(dirname "$0")/msvcenv.sh"
"$(dirname "$0")/wine-msvc.sh" "$SDKBASE/Debuggers/x64/pdbcopy.exe" "$@"
EOF
  ln -sf ./pdbcopy "$UE_WINE_MSVC/bin/x64/pdbcopy.exe"
  chmod +x "$UE_WINE_MSVC/bin/x64/pdbcopy"
fi

echo "Building Linux editor with up to $parallel_jobs parallel actions..."
"$UE_CSS_ROOT/Engine/Build/BatchFiles/Linux/Build.sh" FactoryEditor Linux Development \
  "-project=$project" -NoUBA -NoDebugInfo "-MaxParallelActions=$parallel_jobs"

hard=$(ulimit -Hn)
if [ "$hard" = unlimited ] || [ "$hard" -ge 1048576 ]; then
  ulimit -Sn 1048576
else
  ulimit -Sn "$hard"
fi
echo 'Packaging the Windows Steam client mod using Wine/MSVC...'
"$UE_CSS_ROOT/Engine/Build/BatchFiles/RunUAT.sh" \
  "-ScriptsForProject=$project" PackagePlugin "-project=$project" \
  -DLCName=Cartograph -Target=FactoryGameSteam -merge -build \
  -ddc=InstalledNoZenLocalFallback \
  -clientconfig=Shipping -serverconfig=Shipping -platform=Win64 \
  -nocompileeditor -installed

archive_root="$project_root/Saved/ArchivedPlugins/Cartograph"
if [ ! -f "$archive_root/Cartograph-Windows.zip" ]; then
  echo "Packaging finished without the expected archive: $archive_root/Cartograph-Windows.zip" >&2
  exit 1
fi
echo "Built package: $archive_root/Cartograph-Windows.zip"
