#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / 'register-engine.py'
spec = importlib.util.spec_from_file_location('registration', path)
registration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(registration)


class HeadlessRegistrationTests(unittest.TestCase):
    def test_preserves_other_engines_and_unchanged_timestamps(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            engine = root / 'engine'
            (engine / 'Engine/Build').mkdir(parents=True)
            (engine / 'Engine/Build/Build.version').write_text(json.dumps({
                'MajorVersion': 5, 'MinorVersion': 6, 'PatchVersion': 1,
            }))
            project = root / 'FactoryGame.uproject'
            project.write_text('{"EngineAssociation":"5.6.1-CSS"}')
            config = root / 'config'
            ini = config / 'Epic/UnrealEngine/Install.ini'
            ini.parent.mkdir(parents=True)
            ini.write_text('[Installations]\nUE_other=/keep/this\n')
            with patch.dict(os.environ, {'XDG_CONFIG_HOME': str(config)}):
                registration.register(engine, project)
                timestamp = ini.stat().st_mtime_ns
                registration.register(engine, project)
            self.assertEqual(ini.stat().st_mtime_ns, timestamp)
            self.assertIn('UE_other = /keep/this', ini.read_text())
            self.assertIn(str(engine), ini.read_text())


if __name__ == '__main__':
    unittest.main()
