#!/usr/bin/env python3
"""Test the Docker launcher without running Docker or downloading toolchains."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "build-local.sh"


class DockerLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.tools = self.root / "toolchain with spaces"
        (self.tools / "ue").mkdir(parents=True)
        (self.tools / "msvc").mkdir()
        self.log = self.root / "docker-calls.jsonl"
        docker = self.bin / "docker"
        docker.write_text("""#!/usr/bin/env python3
import json, os, sys
with open(os.environ['DOCKER_TEST_LOG'], 'a') as f:
    f.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:3] == ['info', '--format']:
    print('x86_64')
""")
        docker.chmod(0o755)
        identity = self.bin / "id"
        identity.write_text("#!/bin/sh\nprintf '1000\\n'\n")
        identity.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(
            PATH=f"{self.bin}:{self.env['PATH']}",
            CARTOGRAPH_BUILD_ROOT=str(self.tools),
            DOCKER_TEST_LOG=str(self.log),
            JOBS="8",
            GH_TOKEN="test-secret-not-for-command-line",
        )
        for name in ("UE_CSS_ROOT", "UE_WINE_MSVC", "CARTOGRAPH_DOCKER_IMAGE", "CARTOGRAPH_WINEPREFIX",
                     "CARTOGRAPH_CACHE_HOME", "CARTOGRAPH_TMPDIR", "NUGET_PACKAGES", "GITHUB_ACTIONS"):
            self.env.pop(name, None)

    def invoke(self, *args):
        return subprocess.run(["bash", str(SCRIPT), *args], env=self.env, capture_output=True, text=True)

    def test_check_uses_nonroot_and_runtime_secret_names(self):
        result = self.invoke("--check")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        run = next(call for call in calls if call[0] == "run")
        self.assertIn("1000:1000", run)
        self.assertIn("JOBS=8", run)
        self.assertIn("CARTOGRAPH_IN_DOCKER=1", run)
        self.assertIn("GH_TOKEN", run)
        self.assertNotIn("test-secret-not-for-command-line", " ".join(run))
        self.assertNotIn("--privileged", run)
        self.assertNotIn("docker.sock", " ".join(run))
        self.assertEqual(run[-1], "--check")
        self.assertIn(f"WINEPREFIX={self.tools}/docker-wine-prefix", run)
        self.assertIn(f"UE-LocalDataCachePath={self.tools}/docker-home/ddc", run)
        self.assertIn(f"type=bind,src={self.tools},dst={self.tools}", run)
        self.assertIn(f"NUGET_PACKAGES={self.tools}/nuget", run)
        self.assertIn(f"TMPDIR={self.tools}/tmp", run)
        self.assertIn(f"XDG_CACHE_HOME={self.tools}/cache", run)

    def test_external_caches_and_ci_checkout_are_mounted(self):
        paths = {
            'CARTOGRAPH_WINEPREFIX': self.root / 'wine',
            'CARTOGRAPH_CACHE_HOME': self.root / 'cache',
            'CARTOGRAPH_TMPDIR': self.root / 'temp',
            'NUGET_PACKAGES': self.root / 'nuget',
        }
        self.env.update({name: str(path) for name, path in paths.items()})
        checkout = self.root / 'checkout'
        checkout.mkdir()
        self.env.update(GITHUB_ACTIONS='true', GITHUB_WORKSPACE=str(checkout))
        result = self.invoke('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        run = next(json.loads(line) for line in self.log.read_text().splitlines()
                   if json.loads(line)[0] == 'run')
        for path in paths.values():
            self.assertIn(f'type=bind,src={path},dst={path}', run)
        self.assertIn(f'type=bind,src={checkout},dst={checkout},readonly', run)

    def test_bad_jobs_does_not_start_container(self):
        self.env["JOBS"] = "0"
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("positive integer", result.stderr)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertFalse(any(call[0] == "run" for call in calls))

    def test_ci_provisioning_mounts_persisted_state_without_socket(self):
        checkout = self.root / 'checkout'
        checkout.mkdir()
        project = self.root / 'project'
        project.mkdir()
        self.env.update(
            CARTOGRAPH_DOCKER_IMAGE='ghcr.io/wa101200/cartograph-build@sha256:test',
            CI_CACHE_ROOT=str(self.tools), PROJECT_ROOT=str(project),
            GITHUB_WORKSPACE=str(checkout), WINEPREFIX=str(self.tools / 'docker-wine-prefix'),
        )
        helper = SCRIPT.parents[1] / '.github/scripts/run-ci-container.sh'
        result = subprocess.run(['bash', str(helper)], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        run = json.loads(self.log.read_text().splitlines()[0])
        self.assertIn(f'type=bind,src={self.tools},dst={self.tools}', run)
        self.assertIn(f'type=bind,src={project},dst={project}', run)
        self.assertIn(f'type=bind,src={checkout},dst={checkout},readonly', run)
        for setting in ['TMPDIR', 'XDG_CACHE_HOME', 'NUGET_PACKAGES']:
            self.assertTrue(any(arg.startswith(f'{setting}={self.tools}/') for arg in run))
        self.assertIn('1000:1000', run)
        self.assertNotIn('docker.sock', ' '.join(run))
        self.assertNotIn('test-secret-not-for-command-line', ' '.join(run))

    def test_help_does_not_contact_docker(self):
        result = self.invoke("--help")
        self.assertEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())

    def test_inner_script_refuses_native_execution(self):
        env = self.env.copy()
        env.pop('CARTOGRAPH_IN_DOCKER', None)
        result = subprocess.run(
            ['bash', str(SCRIPT.with_name('build-local-inner.sh'))],
            env=env, capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must run through Docker', result.stderr)


if __name__ == "__main__":
    unittest.main()
