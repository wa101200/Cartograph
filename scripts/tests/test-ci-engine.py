#!/usr/bin/env python3
"""Engine registration must never launch a GUI or redownload a completed cache."""
import configparser
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / '.github/scripts/setup-ci-engine.sh'


class HeadlessEngineTests(unittest.TestCase):
    def test_registers_from_cache_without_selector_or_network(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine, project, home = root / 'engine', root / 'project', root / 'home'
            (engine / 'Engine/Build').mkdir(parents=True)
            (engine / 'Engine/Build/Build.version').write_text(json.dumps({
                'MajorVersion': 5, 'MinorVersion': 6, 'PatchVersion': 1,
            }))
            (engine / '.cartograph-installed').write_text('5.6.1-css-83\n')
            project.mkdir()
            (project / 'FactoryGame.uproject').write_text('{"EngineAssociation":"5.6.1-CSS"}')
            config_path = home / '.config/Epic/UnrealEngine/Install.ini'
            config_path.parent.mkdir(parents=True)
            config_path.write_text('[Installations]\nUE_other=/keep/this/engine\n')
            env = os.environ.copy()
            env.pop('XDG_CONFIG_HOME', None)
            env.update(CI_CACHE_ROOT=str(root / 'cache'), UE_CSS_ROOT=str(engine),
                       PROJECT_ROOT=str(project), HOME=str(home), ENGINE_RELEASE='5.6.1-css-83')
            result = subprocess.run(['bash', str(SCRIPT)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('(headless)', result.stdout)
            config = configparser.ConfigParser()
            config.read(config_path)
            self.assertEqual(config['Installations']['UE_5.6.1-CSS'], str(engine))
            self.assertEqual(config['Installations']['UE_other'], '/keep/this/engine')
            timestamp = config_path.stat().st_mtime_ns
            subprocess.run(['bash', str(SCRIPT)], env=env, check=True, capture_output=True)
            self.assertEqual(config_path.stat().st_mtime_ns, timestamp)


if __name__ == '__main__':
    unittest.main()
