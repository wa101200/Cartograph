#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'run-with-watchdog.py'


class WatchdogTests(unittest.TestCase):
    def test_preserves_success_and_output(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--', sys.executable,
                                 '-c', 'print("finished")'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('finished', result.stdout)

    def test_cancels_silent_process(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--idle-seconds', '0.3',
                                 '--', sys.executable, '-c', 'import time;time.sleep(30)'],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 124)
        self.assertIn('cancelling', result.stdout)

    def test_preserves_failed_exit_status(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--', sys.executable,
                                 '-c', 'raise SystemExit(42)'], capture_output=True)
        self.assertEqual(result.returncode, 42)


if __name__ == '__main__':
    unittest.main()
