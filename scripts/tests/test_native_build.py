#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'build-local.sh'


class NativeLauncherTests(unittest.TestCase):
    def test_help_requires_no_toolchain(self):
        result = subprocess.run(['bash', str(SCRIPT), '--help'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('native Linux/Wine', result.stdout)

    def test_invalid_parallelism_is_rejected_before_build(self):
        env = os.environ.copy()
        env['JOBS'] = '0'
        result = subprocess.run(['bash', str(SCRIPT), '--check'], env=env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('positive integer', result.stderr)


if __name__ == '__main__':
    unittest.main()
