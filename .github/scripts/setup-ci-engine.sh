#!/usr/bin/env bash
set -euo pipefail
: "${CI_CACHE_ROOT:?}"
: "${UE_CSS_ROOT:?}"
: "${PROJECT_ROOT:?}"
: "${ENGINE_RELEASE:?Pin the CSS engine release for reproducible caching}"
mkdir -p "$UE_CSS_ROOT" "$CI_CACHE_ROOT/downloads/engine"
cd "$UE_CSS_ROOT"
if [ ! -f .cartograph-installed ] || [ "$(cat .cartograph-installed)" != "$ENGINE_RELEASE" ]; then
  gh release download "$ENGINE_RELEASE" --repo satisfactorymodding/UnrealEngine \
    --pattern 'UnrealEngine-CSS-Editor-Linux.tar.zst.*' \
    --dir "$CI_CACHE_ROOT/downloads/engine" --clobber
  cat "$CI_CACHE_ROOT"/downloads/engine/UnrealEngine-CSS-Editor-Linux.tar.zst.* | zstd -d | tar -xf -
  # Delete only the downloaded archive parts, after complete extraction.
  find "$CI_CACHE_ROOT/downloads/engine" -maxdepth 1 -type f \
    -name 'UnrealEngine-CSS-Editor-Linux.tar.zst.*' -delete
else
  echo "Reusing cached CSS engine $ENGINE_RELEASE."
fi
python3 - <<'PY'
import json
with open('Engine/Build/Build.version') as f:
    version = json.load(f)
assert [version[k] for k in ('MajorVersion', 'MinorVersion', 'PatchVersion')] == [5, 6, 1], 'Wrong engine version'
PY
if [ ! -f .cartograph-installed ] || [ "$(cat .cartograph-installed)" != "$ENGINE_RELEASE" ]; then
  printf '%s\n' "$ENGINE_RELEASE" > .cartograph-installed
fi
# The Linux selector can launch modal zenity dialogs even with -unattended.
# Register only the project association directly, without starting a GUI process.
python3 - <<'PY'
import configparser, json, os
from pathlib import Path
with open(Path(os.environ['PROJECT_ROOT']) / 'FactoryGame.uproject') as f:
    association = json.load(f)['EngineAssociation']
config_root = Path(os.environ.get('XDG_CONFIG_HOME') or str(Path.home() / '.config'))
path = config_root / 'Epic/UnrealEngine/Install.ini'
config = configparser.ConfigParser(interpolation=None)
config.optionxform = str
if path.exists():
    config.read(path)
if not config.has_section('Installations'):
    config.add_section('Installations')
engine = str(Path(os.environ['UE_CSS_ROOT']).resolve())
key = f'UE_{association}'
if config.get('Installations', key, fallback=None) != engine:
    config.set('Installations', key, engine)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w') as f:
        config.write(f)
print(f'Registered {association}: {engine} (headless)')
PY
