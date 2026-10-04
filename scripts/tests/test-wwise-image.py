#!/usr/bin/env python3
"""Check image-template initialization without SDK downloads or credentials."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'install-wwise-from-image.sh'


class WwiseTemplateTests(unittest.TestCase):
    def test_copies_once_and_preserves_local_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            template, project = root / 'template', root / 'project'
            project.mkdir()
            for name in ['Wwise', 'WwiseNiagara']:
                plugin = template / name
                plugin.mkdir(parents=True)
                (plugin / f'{name}.uplugin').write_text('{}')
                (plugin / 'library.lib').write_text('SDK binary')
            env = os.environ.copy()
            env.update(CARTOGRAPH_WWISE_TEMPLATE=str(template))
            subprocess.run(['bash', str(SCRIPT), str(project)], env=env, check=True)
            output = project / 'Plugins/Wwise/library.lib'
            output.write_text('local output or edit')
            timestamp = output.stat().st_mtime_ns
            subprocess.run(['bash', str(SCRIPT), str(project)], env=env, check=True)
            self.assertEqual(output.read_text(), 'local output or edit')
            self.assertEqual(output.stat().st_mtime_ns, timestamp)

    def test_refuses_to_overwrite_incomplete_existing_plugin(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            template = root / 'template/Wwise'
            template.mkdir(parents=True)
            (template / 'Wwise.uplugin').write_text('{}')
            plugin = root / 'project/Plugins/Wwise'
            plugin.mkdir(parents=True)
            user_file = plugin / 'user-file'
            user_file.write_text('keep')
            env = os.environ.copy()
            env.update(CARTOGRAPH_WWISE_TEMPLATE=str(root / 'template'))
            result = subprocess.run(['bash', str(SCRIPT), str(root / 'project')],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Refusing to overwrite', result.stderr)
            self.assertEqual(user_file.read_text(), 'keep')


if __name__ == '__main__':
    unittest.main()
