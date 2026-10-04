#!/usr/bin/env python3
"""Exercise incremental source synchronization without any external SDKs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/prepare-ci-project.sh'


class CacheSyncTests(unittest.TestCase):
    def test_preserves_outputs_and_unchanged_input_timestamps(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / 'source', root / 'cached'
            source.mkdir()
            target.mkdir()
            (source / '.git').mkdir()
            for name in ['Mods/SML', 'Mods/GameFeatures/Cartograph', 'Plugins']:
                (source / name).mkdir(parents=True, exist_ok=True)
            (source / 'unchanged.cpp').write_text('same contents')
            (source / 'changed.cpp').write_text('new contents')
            (target / 'unchanged.cpp').write_text('same contents')
            (target / 'changed.cpp').write_text('old contents')
            (target / 'deleted.cpp').write_text('obsolete')
            os.utime(target / 'unchanged.cpp', (1000000000, 1000000000))
            protected = [
                'Intermediate/compiler.obj', 'Binaries/module.so',
                'Saved/Cooked/asset.bin', 'DerivedDataCache/cache.bin',
                'Saved/UnrealBuildTool/BuildConfiguration.xml',
                'Mods/GameFeatures/Cartograph/Binaries/module.dll',
                'Mods/SML/Intermediate/generated.h',
                'Plugins/Wwise/Wwise.uplugin',
                'Plugins/WwiseNiagara/WwiseNiagara.uplugin',
                'lost+found/keep',
            ]
            for name in protected:
                path = target / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('cached output')
            env = os.environ.copy()
            env.update(PROJECT_ROOT=str(target), GITHUB_WORKSPACE=str(source))
            subprocess.run(['bash', str(SCRIPT)], env=env, check=True)
            self.assertEqual((target / 'unchanged.cpp').stat().st_mtime, 1000000000)
            self.assertEqual((target / 'changed.cpp').read_text(), 'new contents')
            self.assertFalse((target / 'deleted.cpp').exists())
            for name in protected:
                self.assertEqual((target / name).read_text(), 'cached output')
            self.assertTrue((target / '.git').is_symlink())
            config = target / 'Saved/UnrealBuildTool/BuildConfiguration.xml'
            timestamp = config.stat().st_mtime_ns
            subprocess.run(['bash', str(SCRIPT)], env=env, check=True)
            self.assertEqual(config.stat().st_mtime_ns, timestamp)
            self.assertEqual((target / 'unchanged.cpp').stat().st_mtime, 1000000000)


if __name__ == '__main__':
    unittest.main()
