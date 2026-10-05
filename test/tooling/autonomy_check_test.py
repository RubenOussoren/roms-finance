"""Offline stdlib regression coverage; never invokes Docker, Rails or services."""
import contextlib
import fcntl
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

HELPER = Path(__file__).resolve().parents[2] / 'bin/autonomy-check'
loader = importlib.machinery.SourceFileLoader('autonomy_check', str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
h = importlib.util.module_from_spec(spec)
loader.exec_module(h)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'source'
        self.root.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        self.common = self.root / '.git'
        self.file('app/tracked.rb', 'tracked')
        self.file('config/database.yml', 'synthetic')
        subprocess.run(['git', '-C', str(self.root), 'add', '.'], check=True)

    def file(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        return target

    def snapshot(self, name='snapshot'):
        path = self.base / name
        path.mkdir()
        return path

    def git_output(self, args):
        if args[0] != 'git':
            raise AssertionError('Unexpected resource operation: ' + repr(args))
        if '--show-toplevel' in args:
            return str(self.root)
        if '--show-current' in args:
            return 'automation/test'
        if '--git-common-dir' in args:
            return str(self.common)
        if args[-1] == 'HEAD':
            return 'a' * 40
        raise AssertionError(args)

    def main_patches(self):
        stack = contextlib.ExitStack()
        stack.enter_context(mock.patch.object(h, 'output', side_effect=self.git_output))
        stack.enter_context(mock.patch.object(h, 'verify_resources'))
        stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
        stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
        return stack


class SnapshotTests(Fixture):
    def test_tracked_and_authorized_new_source_frozen(self):
        self.file('app/new.rb', 'new untracked app code')
        self.file('test/new_test.rb', 'new test')
        self.file('unapproved/new.txt', 'not authorized')
        self.file('.gitignore', 'app/assets/builds/*\npublic/assets/*\napp/ignored.rb\n')
        self.file('app/ignored.rb', 'ignored')
        self.file('app/assets/builds/site.css', 'compiled')
        self.file('public/assets/site.js', 'compiled js')
        snapshot = self.snapshot()
        digest = h.freeze_source(self.root, snapshot)
        self.assertEqual(len(digest), 64)
        self.assertEqual((snapshot / 'app/new.rb').read_text(), 'new untracked app code')
        self.assertTrue((snapshot / 'public/assets/site.js').exists())
        self.assertFalse((snapshot / 'app/ignored.rb').exists())
        self.assertFalse((snapshot / 'unapproved/new.txt').exists())
        self.file('app/new.rb', 'changed after capture')
        self.assertEqual((snapshot / 'app/new.rb').read_text(), 'new untracked app code')
        self.assertNotEqual(h.freeze_source(self.root, self.snapshot('later')), digest)

    def test_tracked_vendored_browser_source_is_not_runtime_dependency(self):
        self.file('vendor/javascript/menu.js', 'checked in application source')
        self.file('vendor/assets/site.css', 'checked in style source')
        self.file('vendor/bundle/runtime.rb', 'MUST NOT CAPTURE')
        subprocess.run(['git', '-C', str(self.root), 'add', 'vendor'], check=True)
        snapshot = self.snapshot()
        h.freeze_source(self.root, snapshot)
        self.assertEqual((snapshot / 'vendor/javascript/menu.js').read_text(), 'checked in application source')
        self.assertTrue((snapshot / 'vendor/assets/site.css').exists())
        self.assertFalse((snapshot / 'vendor/bundle').exists())

    def test_sensitive_exclusion_never_opens_secret_content(self):
        secrets = ['config/master.key', 'config/credentials.yml.enc',
                   'config/credentials/test.yml.enc', 'config/secrets.yml', '.env',
                   '.env.local', 'config/dotenv', 'tmp/private', 'log/private',
                   'vendor/private', 'node_modules/private']
        for path in secrets:
            self.file(path, 'MUST NOT READ')
        self.file('.env.example', 'safe example')
        # Include excluded tracked files as well, not only ignored/untracked files.
        subprocess.run(['git', '-C', str(self.root), 'add', '-f', '.'], check=True)
        original_open = os.open
        original_read = Path.read_bytes

        def checked_open(path, *args, **kwargs):
            if str(path).startswith(str(self.root) + '/'):
                self.assertNotIn(Path(path).relative_to(self.root).as_posix(), secrets)
            return original_open(path, *args, **kwargs)

        def checked_read(path):
            self.assertNotIn(path.relative_to(self.root).as_posix(), secrets)
            return original_read(path)

        snapshot = self.snapshot()
        with mock.patch.object(h.os, 'open', side_effect=checked_open), mock.patch.object(Path, 'read_bytes', checked_read):
            h.freeze_source(self.root, snapshot)
        self.assertTrue((snapshot / '.env.example').exists())
        for path in secrets:
            self.assertFalse((snapshot / path).exists(), path)

    def test_safe_relative_symlink_preserved(self):
        (self.root / 'app/link.rb').symlink_to('tracked.rb')
        snapshot = self.snapshot()
        h.freeze_source(self.root, snapshot)
        self.assertTrue((snapshot / 'app/link.rb').is_symlink())
        self.assertEqual((snapshot / 'app/link.rb').read_text(), 'tracked')

    def test_unsafe_symlinks_refused_without_reading_targets(self):
        self.file('config/master.key', 'MUST NOT READ')
        for target in ['../config/master.key', '../../outside', '/etc/passwd', 'missing.rb', 'link.rb']:
            with self.subTest(target=target):
                link = self.root / 'app/link.rb'
                link.symlink_to(target)
                try:
                    with self.assertRaises(h.HarnessError):
                        h.freeze_source(self.root, self.snapshot('snapshot-' + str(len(list(self.base.iterdir())))))
                finally:
                    link.unlink()

    def test_digest_records_mode_and_content(self):
        first = h.freeze_source(self.root, self.snapshot('one'))
        (self.root / 'app/tracked.rb').chmod(0o755)
        second = h.freeze_source(self.root, self.snapshot('two'))
        self.assertNotEqual(first, second)
        self.assertEqual(second, h.freeze_source(self.root, self.snapshot('three')))

    def test_assets_copy_only_new_changed_approved_files(self):
        self.file('app/assets/builds/old.css', 'old')
        snapshot = self.snapshot()
        h.freeze_source(self.root, snapshot)
        before = h.asset_manifest(snapshot)
        self.file('app/assets/builds/old.css', 'concurrent source update')
        (snapshot / 'app/assets/builds/new.css').write_text('new')
        (snapshot / 'app/tracked.rb').write_text('do not copy')
        h.publish_assets(snapshot, self.root, before)
        self.assertEqual((self.root / 'app/assets/builds/old.css').read_text(), 'concurrent source update')
        self.assertEqual((self.root / 'app/assets/builds/new.css').read_text(), 'new')
        self.assertEqual((self.root / 'app/tracked.rb').read_text(), 'tracked')
    def test_asset_publication_refuses_nested_destination_symlink(self):
        self.file('public/assets/nested/site.js', 'before')
        snapshot = self.snapshot()
        h.freeze_source(self.root, snapshot)
        before = h.asset_manifest(snapshot)
        (snapshot / 'public/assets/nested/site.js').write_text('after')
        outside = self.base / 'outside'
        outside.mkdir()
        protected = outside / 'site.js'
        protected.write_text('do not change')
        (self.root / 'public/assets/nested/site.js').unlink()
        (self.root / 'public/assets/nested').rmdir()
        (self.root / 'public/assets/nested').symlink_to(outside, target_is_directory=True)
        with self.assertRaises(h.HarnessError):
            h.publish_assets(snapshot, self.root, before)
        self.assertEqual(protected.read_text(), 'do not change')

    def test_asset_publication_refuses_symlinked_root_ancestor(self):
        self.file('public/assets/site.js', 'before')
        snapshot = self.snapshot()
        h.freeze_source(self.root, snapshot)
        before = h.asset_manifest(snapshot)
        (snapshot / 'public/assets/site.js').write_text('after')
        outside = self.base / 'outside'
        (self.root / 'public').rename(outside)
        (self.root / 'public').symlink_to(outside, target_is_directory=True)
        with self.assertRaises(h.HarnessError):
            h.publish_assets(snapshot, self.root, before)
        self.assertEqual((outside / 'assets/site.js').read_text(), 'before')


class LifecycleTests(Fixture):
    def test_invalid_cli_and_unapproved_preparation_touch_nothing(self):
        for args in [[], ['unknown'], ['db:schema:load'], ['test', '../evil'],
                     ['test', '/absolute'], ['test', '--help'], ['docs', 'extra']]:
            with self.subTest(args=args), mock.patch.object(h, 'output') as output, mock.patch.object(h, 'Pending') as pending:
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(h.main(args, {}), 1)
                output.assert_not_called()
                pending.assert_not_called()
        h.validate_cli(['db:schema:load'], {'AUTONOMY_PREPARE_APPROVED': 'bootstrap-2026-10'})
        h.validate_cli(['test', 'test/models/account_test.rb'], {})

    def test_pending_refuses_reuse_without_cleanup(self):
        pending = h.Pending(self.common, self.root, 'head')
        with self.main_patches(), mock.patch.object(h, 'verify_resources') as resources:
            self.assertEqual(h.main(['docs'], {}), 1)
            resources.assert_not_called()
        self.assertTrue(pending.snapshot.exists())
        self.assertTrue(pending.path.exists())
        with self.assertRaises(h.HarnessError):
            h.Pending(self.common, self.root, 'head')

    def test_ordinary_exit_confirmed_before_cleanup_and_exit_propagated(self):
        pending = h.Pending(self.common, self.root, 'head')
        calls = []

        def fake_run(args, **kwargs):
            self.assertTrue(pending.path.exists())
            calls.append(args)
            if args[0] == 'compose':
                self.assertIn('-d', args)
                self.assertNotIn('--rm', args)
                self.assertIn(str(pending.snapshot) + ':/workspace', args)
                self.assertIn('cache:/bundle:ro', ' '.join(args))
            if 'rm' in args:
                self.assertEqual(pending.data['phase'], 'settled')
            return subprocess.CompletedProcess(args, 0)

        with mock.patch.object(h, 'run', side_effect=fake_run), mock.patch.object(h, 'output', side_effect=['7', json.dumps({'Status': 'exited', 'Running': False, 'ExitCode': 7})]):
            self.assertEqual(h.ordinary(pending, ['compose'], ['docker'], ['env', '-i'], self.base, h.DeferredSignals()), 7)
        self.assertEqual(calls[-1][:2], ['docker', 'rm'])
        self.assertFalse(any('--force' in c or '-f' in c for c in calls if 'rm' in c))
        override = json.loads((pending.directory / 'compose.json').read_text())
        self.assertEqual(override, {'services': {'app': {'restart': 'no'}}})

    def test_attachment_failure_retains_pending_and_snapshot(self):
        def uncertain(*args, **kwargs):
            raise subprocess.CalledProcessError(1, ['fake', 'wait'])
        with self.main_patches(), mock.patch.object(h, 'ordinary', side_effect=uncertain):
            self.assertEqual(h.main(['docs'], {}), 1)
        record = json.loads((self.common / 'roms-autonomy-pending.json').read_text())
        self.assertTrue(Path(record['snapshot']).exists())
        with self.main_patches(), mock.patch.object(h, 'ordinary') as operation:
            self.assertEqual(h.main(['docs'], {}), 1)
            operation.assert_not_called()

    def test_running_container_is_not_settled_by_cli_exit(self):
        pending = h.Pending(self.common, self.root, 'head')
        with mock.patch.object(h, 'run') as run, mock.patch.object(h, 'output', side_effect=['0', json.dumps({'Status': 'running', 'Running': True})]):
            with self.assertRaises(h.HarnessError):
                h.ordinary(pending, ['compose'], ['docker'], ['env', '-i'], self.base, h.DeferredSignals())
        self.assertEqual(run.call_count, 1)  # launch only; no logs/removal
        self.assertTrue(pending.path.exists())
        self.assertTrue(pending.snapshot.exists())

    def test_browser_polls_marker_not_attachment_and_cleans_after_exit(self):
        pending = h.Pending(self.common, self.root, 'head')
        calls = []

        def fake_run(args, **kwargs):
            calls.append(args)
            self.assertTrue(pending.path.exists())
            if 'rm' in args:
                self.assertEqual(pending.data['phase'], 'settled')
            return subprocess.CompletedProcess(args, 0)

        with mock.patch.object(h, 'run', side_effect=fake_run), mock.patch.object(h, 'output', side_effect=['pending', '0', 'pending', '9', '']), mock.patch.object(h.time, 'sleep'):
            self.assertEqual(h.browser(pending, ['compose'], ['test', 'test/system/example_test.rb'], {}, h.DeferredSignals()), 9)
        copy = calls[0]
        self.assertIn('--archive', copy)
        self.assertEqual(copy[3], str(pending.snapshot))
        detached = [c for c in calls if '-d' in c]
        self.assertEqual(len(detached), 2)
        # Syntax-check the real owned dependency-copy wrapper, without running it.
        dependency_script = detached[0][-3]
        subprocess.run(['sh', '-n'], input=dependency_script, text=True, check=True)
        self.assertIn('Unsafe dependency symlink', dependency_script)
        self.assertIn('printf "%s\\n"', detached[-1][detached[-1].index('-c') + 1])
        self.assertIn('env', detached[-1])
        self.assertIn('-i', detached[-1])
        self.assertTrue(any('BUNDLE_PATH=/tmp/roms-autonomy-browser-' in a for a in detached[-1]))
        self.assertEqual(calls[-1][-4:-2], ['rm', '-rf'])

    def test_browser_missing_completion_fails_closed_no_remove(self):
        pending = h.Pending(self.common, self.root, 'head')
        with mock.patch.object(h, 'run') as run, mock.patch.object(h, 'output', side_effect=subprocess.CalledProcessError(1, ['fake', 'poll'])):
            with self.assertRaises(subprocess.CalledProcessError):
                h.browser(pending, ['compose'], ['test', 'test/system/example_test.rb'], {}, h.DeferredSignals())
        self.assertFalse(any('rm' in call.args[0] for call in run.call_args_list))
        self.assertTrue(pending.path.exists())

    def test_both_entrypoint_routes_receive_same_frozen_capture(self):
        self.file('app/new.rb', 'untracked app')
        captures = []
        def operation(pending, *_args):
            captures.append((pending.data['head'], pending.data['digest'],
                             (pending.snapshot / 'app/new.rb').read_text()))
            return 13
        for args in [['test', 'test/models/example_test.rb'], ['test', 'test/system/example_test.rb']]:
            with self.main_patches(), mock.patch.object(h, 'ordinary', side_effect=operation), mock.patch.object(h, 'browser', side_effect=operation):
                self.assertEqual(h.main(args, {}), 13)
            self.assertFalse((self.common / 'roms-autonomy-pending.json').exists())
        self.assertEqual(captures[0], captures[1])

    def test_assets_not_published_on_failure(self):
        with self.main_patches(), mock.patch.object(h, 'ordinary', return_value=1), mock.patch.object(h, 'publish_assets') as publish:
            self.assertEqual(h.main(['assets:precompile'], {}), 1)
            publish.assert_not_called()

    def test_real_browser_wrapper_marker_preserves_child_exit_code(self):
        pending = h.Pending(self.common, self.root, 'head')
        children = []
        def launch(args, **_kwargs):
            if '-d' in args:
                command = args[args.index('sh'):]
                children.append(subprocess.Popen(command, start_new_session=True))
            return subprocess.CompletedProcess(args, 0)
        def marker(_args):
            path = Path(pending.data['completion_marker'])
            return path.read_text().strip() if path.exists() else 'pending'
        with mock.patch.object(h, 'run', side_effect=launch), mock.patch.object(h, 'output', side_effect=marker):
            code = h.browser_step(pending, ['compose'], str(pending.snapshot),
                                  [sys.executable, '-c', 'import time; time.sleep(.05); raise SystemExit(19)'], 'validation')
        self.assertEqual(code, 19)
        self.assertEqual(children[0].wait(timeout=5), 0)  # Wrapper vs operation status.
        self.assertEqual(pending.data['exit_code'], 19)
        self.assertTrue(Path(pending.data['completion_marker']).exists())

    def test_browser_interrupt_during_dependencies_skips_validation(self):
        pending = h.Pending(self.common, self.root, 'head')
        signals = h.DeferredSignals()
        def completed(_args):
            signals.receive(signal.SIGTERM, None)
            signals.receive(signal.SIGINT, None)
            return '0'
        with mock.patch.object(h, 'run') as run, mock.patch.object(h, 'output', side_effect=completed):
            self.assertEqual(h.browser(pending, ['compose'], ['test', 'test/system/example_test.rb'], {}, signals), 143)
        detached = [call.args[0] for call in run.call_args_list if '-d' in call.args[0]]
        self.assertEqual(len(detached), 1)
        self.assertTrue(any('rm' in call.args[0] for call in run.call_args_list))

    def test_sigkill_leaves_durable_pending_and_refuses_next_entrypoint(self):
        script = r'''
import importlib.machinery, importlib.util, os, pathlib, signal, sys
loader = importlib.machinery.SourceFileLoader('h', sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
h = importlib.util.module_from_spec(spec); loader.exec_module(h)
root = pathlib.Path(sys.argv[2])
pending = h.Pending(root / '.git', root, 'head')
pending.save(phase='ordinary-launch', container='roms-autonomy-check-' + pending.data['id'])
os.kill(os.getpid(), signal.SIGKILL)
'''
        killed = subprocess.run([sys.executable, '-c', script, str(HELPER), str(self.root)], check=False)
        self.assertEqual(killed.returncode, -signal.SIGKILL)
        record = json.loads((self.common / 'roms-autonomy-pending.json').read_text())
        self.assertEqual(record['phase'], 'ordinary-launch')
        self.assertTrue(Path(record['snapshot']).exists())
        with self.main_patches(), mock.patch.object(h, 'ordinary') as ordinary:
            self.assertEqual(h.main(['docs'], {}), 1)
            ordinary.assert_not_called()
        self.assertTrue(Path(record['snapshot']).exists())

    def test_repeated_signals_hold_lock_until_real_child_settles(self):
        # Real main(), flock and local subprocess; only Docker/resource calls faked.
        script = r'''
import importlib.machinery, importlib.util, json, os, pathlib, subprocess, sys
loader = importlib.machinery.SourceFileLoader('h', sys.argv[1])
spec = importlib.util.spec_from_loader(loader.name, loader)
h = importlib.util.module_from_spec(spec); loader.exec_module(h)
root = pathlib.Path(sys.argv[2]); common = root / '.git'; base = root.parent
original_output = h.output; original_run = h.run
child = None

def output(args):
    if args[0] == 'git':
        if '--show-toplevel' in args: return str(root)
        if '--show-current' in args: return 'automation/test'
        if '--git-common-dir' in args: return str(common)
        if args[-1] == 'HEAD': return 'a' * 40
    if 'wait' in args:
        child.wait()
        return str(child.returncode)
    if 'inspect' in args:
        return json.dumps({'Status': 'exited', 'Running': False, 'ExitCode': child.returncode})
    raise AssertionError(args)

def run(args, **kwargs):
    global child
    if args[0] == 'git': return original_run(args, **kwargs)
    if 'run' in args:
        code = 'import pathlib,time; p=pathlib.Path(' + repr(str(base)) + '); (p/"started").touch();\nwhile not (p/"release").exists(): time.sleep(.02)\n(p/"settled").touch()'
        child = subprocess.Popen([sys.executable, '-c', code], start_new_session=True)
    elif 'rm' in args:
        assert (base / 'settled').exists()
        (base / 'removed').touch()
    return subprocess.CompletedProcess(args, 0)

h.output = output; h.run = run; h.verify_resources = lambda *args: None
sys.exit(h.main(['docs'], {}))
'''
        process = subprocess.Popen([sys.executable, '-c', script, str(HELPER), str(self.root)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        self.addCleanup(lambda: (self.base / 'release').touch())
        deadline = time.monotonic() + 10
        while not (self.base / 'started').exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertTrue((self.base / 'started').exists())
        process.send_signal(signal.SIGINT)
        process.send_signal(signal.SIGTERM)
        process.send_signal(signal.SIGINT)
        time.sleep(0.1)
        self.assertIsNone(process.poll())
        pending = json.loads((self.common / 'roms-autonomy-pending.json').read_text())
        self.assertTrue(Path(pending['snapshot']).exists())
        self.assertFalse((self.base / 'removed').exists())
        with open(self.common / 'roms-autonomy-test.lock', 'a') as lock:
            with self.assertRaises(BlockingIOError):
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        (self.base / 'release').touch()
        stdout, stderr = process.communicate(timeout=10)
        self.assertIn(process.returncode, [130, 143], (stdout, stderr))
        self.assertTrue((self.base / 'settled').exists())
        self.assertTrue((self.base / 'removed').exists())
        self.assertFalse(Path(pending['snapshot']).exists())
        self.assertFalse((self.common / 'roms-autonomy-pending.json').exists())
        with open(self.common / 'roms-autonomy-test.lock', 'a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)


if __name__ == '__main__':
    unittest.main()
