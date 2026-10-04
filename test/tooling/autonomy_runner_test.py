"""Offline runner lifecycle tests. No Docker, Rails, provider or database access."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

SOURCE = Path(__file__).resolve().parents[2]


class AutonomyRunnerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / 'bin').mkdir()
        (self.root / 'tmp').mkdir()
        (self.root / '.term-llm').mkdir()
        shutil.copy(SOURCE / 'bin/autonomy-run', self.root / 'bin/autonomy-run')
        (self.root / 'bin/autonomy-check').write_text('#!/bin/sh\nexit 0\n')
        (self.root / 'bin/autonomy-check').chmod(0o755)
        (self.root / '.term-llm/pilot-prompt.md').write_text('Offline test')
        self.git('init', '-b', 'automation/issue-151')
        self.git('config', 'user.email', 'offline@example.invalid')
        self.git('config', 'user.name', 'Offline Test')
        self.git('add', 'bin', '.term-llm')
        self.git('commit', '-m', 'Fixture')
        self.env = os.environ.copy()
        self.env['PATH'] = str(self.root / 'bin') + ':' + self.env['PATH']
        self.checkpoint = self.root / '.git/roms-autonomy-checkpoint.json'
        self.run_cli('init', expected=0)

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, capture_output=True, check=True)

    def run_cli(self, mode, expected):
        result = subprocess.run(['bin/autonomy-run', mode], cwd=self.root, env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(expected, result.returncode, result.stderr + result.stdout)
        return result

    def fake_cli(self, body):
        (self.root / 'bin/term-llm').write_text('#!/usr/bin/env python3\n' + body)
        (self.root / 'bin/term-llm').chmod(0o755)
        self.git('add', 'bin/term-llm')
        self.git('commit', '-m', 'Fake CLI')
        state = self.state()
        state['head_sha'] = self.git('rev-parse', 'HEAD').stdout.decode().strip()
        self.checkpoint.write_text(json.dumps(state))

    def state(self):
        return json.loads(self.checkpoint.read_text())

    def test_charges_iteration_and_checkpoints_success(self):
        self.fake_cli("import sys\nassert '--done-file' in sys.argv\nassert sys.argv[sys.argv.index('--max') + 1] == '1'\nfrom pathlib import Path\nPath('tmp/autonomy-result.json').write_text('{\"status\":\"complete\",\"unsuccessful_repair_approaches\":0}')\n")
        self.run_cli('run', 0)
        self.assertEqual(1, self.state()['iterations_started'])
        self.assertEqual('checkpointed', self.state()['status'])

    def test_failed_exit_needs_reconciliation(self):
        self.fake_cli("from pathlib import Path\nPath('tmp/autonomy-result.json').write_text('{\"status\":\"complete\",\"unsuccessful_repair_approaches\":1}')\nraise SystemExit(2)\n")
        self.run_cli('run', 2)
        self.assertEqual('needs-reconciliation', self.state()['status'])
        self.assertEqual(1, self.state()['unsuccessful_repair_approaches'])
        self.run_cli('run', 1)

    def test_budget_is_not_reset_on_resume(self):
        state = self.state()
        state['iterations_started'] = 5
        self.checkpoint.write_text(json.dumps(state))
        self.run_cli('run', 1)
        self.assertEqual(5, self.state()['iterations_started'])
        self.run_cli('init', 1)

    def test_wrong_sha_rejected(self):
        state = self.state()
        state['head_sha'] = 'wrong'
        self.checkpoint.write_text(json.dumps(state))
        self.run_cli('run', 1)

    def test_lock_contention_rejected(self):
        import fcntl
        with open(self.root / '.git/roms-autonomy.lock', 'a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.run_cli('run', 1)
        self.assertEqual(0, self.state()['iterations_started'])

    def test_term_reaps_managed_descendant_and_preserves_budget(self):
        self.fake_cli("import subprocess, time\nfrom pathlib import Path\nchild=subprocess.Popen(['sleep','60'])\nPath('tmp/descendant.pid').write_text(str(child.pid))\ntime.sleep(60)\n")
        parent = subprocess.Popen(['bin/autonomy-run', 'run'], cwd=self.root, env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            for _ in range(100):
                if (self.root / 'tmp/descendant.pid').exists():
                    break
                time.sleep(0.02)
            descendant = int((self.root / 'tmp/descendant.pid').read_text())
            parent.send_signal(signal.SIGTERM)
            parent.wait(timeout=5)
            with self.assertRaises(ProcessLookupError):
                os.kill(descendant, 0)
            self.assertEqual(1, self.state()['iterations_started'])
            self.assertEqual('needs-reconciliation', self.state()['status'])
        finally:
            if parent.poll() is None:
                parent.kill()
                parent.wait()


if __name__ == '__main__':
    unittest.main()
