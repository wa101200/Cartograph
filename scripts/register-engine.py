#!/usr/bin/env python3
"""Register a native CSS engine without launching UnrealVersionSelector dialogs."""
import configparser
import json
import os
from pathlib import Path
import sys


def register(engine, project):
    engine = Path(engine).resolve()
    with (engine / 'Engine/Build/Build.version').open() as f:
        version = json.load(f)
    if [version[k] for k in ('MajorVersion', 'MinorVersion', 'PatchVersion')] != [5, 6, 1]:
        raise SystemExit('Expected CSS Unreal Engine 5.6.1')
    with Path(project).open() as f:
        association = json.load(f)['EngineAssociation']
    config_root = Path(os.environ.get('XDG_CONFIG_HOME') or str(Path.home() / '.config'))
    path = config_root / 'Epic/UnrealEngine/Install.ini'
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = str
    if path.exists():
        config.read(path)
    if not config.has_section('Installations'):
        config.add_section('Installations')
    key = f'UE_{association}'
    if config.get('Installations', key, fallback=None) != str(engine):
        config.set('Installations', key, str(engine))
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open('w') as f:
            config.write(f)
    print(f'Registered {association}: {engine} (headless)', flush=True)
    return path


if __name__ == '__main__':
    register(sys.argv[1], sys.argv[2])
