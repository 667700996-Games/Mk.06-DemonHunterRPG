"""Small subprocess integration tests: no Godot templates or large packages needed."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / 'tools/build.py'
spec = importlib.util.spec_from_file_location('riftfall_build', SCRIPT)
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)

FAKE = '''#!/usr/bin/env python3
import os, pathlib, sys, time
root = pathlib.Path(__file__).parent
if '--import' in sys.argv:
    marker = root / 'started'
    marker.write_text('ready')
    if (root / 'sleep').exists():
        time.sleep(2)
    if (root / 'noisy').exists():
        sys.stdout.write('x' * (2 * 1024 * 1024))
    if (root / 'fail').exists():
        sys.exit(9)
    if (root / 'error').exists():
        print('SCRIPT ERROR: fixture')
    sys.exit(0)
if '--export-pack' in sys.argv or '--export-debug' in sys.argv or '--export-release' in sys.argv:
    output = pathlib.Path(sys.argv[-1])
    output.write_bytes(b'GDPC' + b'fixture' * 8)
    if (root / 'symbol').exists():
        (output.parent / 'game.pdb').write_bytes(b'keep for crashes')
'''


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='riftfall-cleanup-test-')
        self.root = Path(self.tmp.name)
        (self.root / 'tools').mkdir()
        shutil.copy2(SCRIPT, self.root / 'tools/build.py')
        for name in build.INPUTS:
            if '.' in name:
                (self.root / name).write_text('fixture')
            else:
                (self.root / name).mkdir()
        self.fake = self.root / 'fake-godot'
        self.fake.write_text(FAKE)
        self.fake.chmod(0o755)
        self.store = build.Store(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def command(self, *args):
        return [sys.executable, str(self.root / 'tools/build.py'), *args]

    def run_build(self, *args, ok=True):
        result = subprocess.run(self.command('build', '--godot', str(self.fake), *args),
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        self.assertFalse(list(self.store.work.iterdir()), result.stderr)
        return result

    def packages(self):
        group = self.store.dev / 'pack'
        return list(group.iterdir()) if group.exists() else []

    def test_success_retention_logs_and_failure_preserves_latest(self):
        (self.root / 'noisy').touch()
        for _ in range(12):
            self.run_build()
        self.assertEqual(len(self.packages()), 2)
        self.assertEqual(len(list(self.store.logs.iterdir())), 10)
        self.assertTrue(all(p.stat().st_size <= build.LIMIT for p in self.store.logs.iterdir()))
        pointer = self.store.base / 'latest-pack.json'
        before = pointer.read_bytes()
        hashes = {p.name: (p / 'RIFTFALL.pck').read_bytes() for p in self.packages()}
        (self.root / 'fail').touch()
        self.run_build(ok=False)
        self.assertEqual(pointer.read_bytes(), before)
        self.assertEqual(hashes, {p.name: (p / 'RIFTFALL.pck').read_bytes() for p in self.packages()})

    def test_zero_exit_with_engine_error_rejected(self):
        (self.root / 'error').touch()
        self.run_build(ok=False)
        self.assertFalse(self.packages())

    def test_release_and_symbols_never_pruned(self):
        (self.root / 'symbol').touch()
        for i in range(3):
            self.run_build('--release', f'v{i}')
        self.assertEqual(len(list((self.store.releases / 'pack').iterdir())), 3)
        self.run_build('--release', 'v0', ok=False)
        for _ in range(3):
            self.run_build()
        self.assertEqual(len(list((self.store.releases / 'pack').iterdir())), 3)
        self.assertGreaterEqual(len(list(self.store.symbols.rglob('game.pdb'))), 3)
        self.assertEqual(len(self.packages()), 2)

    def test_verify_only_and_missing_tool(self):
        self.run_build('--verify-only')
        self.assertFalse(self.packages())
        result = subprocess.run(self.command('build', '--godot', '/nonexistent/godot'), capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(list(self.store.work.iterdir()))

    def start_sleeping(self):
        (self.root / 'sleep').touch()
        (self.root / 'started').unlink(missing_ok=True)
        process = subprocess.Popen(self.command('build', '--godot', str(self.fake)),
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        deadline = time.monotonic() + 10
        while not (self.root / 'started').exists():
            if process.poll() is not None or time.monotonic() > deadline:
                process.kill()
                self.fail('fake engine never started')
            time.sleep(.02)
        return process

    def test_graceful_interrupts(self):
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            with self.subTest(signal=sig):
                process = self.start_sleeping()
                process.send_signal(sig)
                self.assertNotEqual(process.wait(timeout=15), 0)
                self.assertFalse(list(self.store.work.iterdir()))

    def test_killed_parent_live_child_protection_and_recovery(self):
        process = self.start_sleeping()
        job = next(self.store.work.iterdir())
        process.kill()
        process.wait(timeout=10)
        self.store.recover()
        self.assertTrue(job.exists(), 'live command guardian must retain lease')
        deadline = time.monotonic() + 10
        while job.exists() and time.monotonic() < deadline:
            time.sleep(.1)
            self.store.recover()
        self.assertFalse(job.exists(), 'dead job must be reclaimed on next invocation')

    def test_two_concurrent_jobs_and_clean(self):
        first = self.start_sleeping()
        second = self.start_sleeping()
        self.store.recover()
        self.assertEqual(len(list(self.store.work.iterdir())), 2)
        self.assertEqual(first.wait(timeout=15), 0)
        self.assertEqual(second.wait(timeout=15), 0)
        self.assertFalse(list(self.store.work.iterdir()))
        self.assertEqual(len(self.packages()), 2)

    def test_foreign_paths_symlinks_and_cleanup_warning(self):
        foreign = self.store.work / 'unknown'
        foreign.mkdir()
        (foreign / 'precious').write_text('preserve')
        job, lease, _ = self.store.create()
        with mock.patch.object(build.shutil, 'rmtree', side_effect=PermissionError('denied')):
            with mock.patch.object(build, 'warn') as warning:
                self.store.finish(job)
                self.assertTrue(warning.called)
                self.assertEqual(warning.call_args.args[0], job)
        self.assertTrue(job.exists())
        lease.__exit__(None, None, None)
        link_job, link_lease, _ = self.store.create()
        (link_job / 'link').symlink_to(foreign, target_is_directory=True)
        link_lease.__exit__(None, None, None)
        self.store.recover()
        self.assertTrue((foreign / 'precious').exists())
        self.assertTrue(link_job.exists())
        self.assertFalse(job.exists())
        (link_job / 'link').unlink()
        self.store.recover()

    def test_interrupted_publication_keeps_old_package(self):
        self.run_build()
        pointer = self.store.base / 'latest-pack.json'
        before = pointer.read_bytes()
        args = type('Args', (), dict(target='pack', godot=str(self.fake), release=None, verify_only=False))()
        original = build.atomic_json
        def fail_pointer(path, value):
            if path.name == 'latest-pack.json':
                raise OSError('simulated pointer replacement failure')
            return original(path, value)
        with mock.patch.object(build, 'atomic_json', side_effect=fail_pointer):
            with self.assertRaises(OSError):
                build.build(self.store, args)
        self.assertEqual(pointer.read_bytes(), before)
        current = self.store.base / json.loads(before)['path'] / 'RIFTFALL.pck'
        self.assertTrue(current.exists())
        self.assertFalse(list(self.store.work.iterdir()))
        # build() disables signal handlers on exit; restore unittest process defaults.
        signal.signal(signal.SIGINT, signal.default_int_handler)
        signal.signal(signal.SIGTERM, signal.SIG_DFL)
        signal.signal(signal.SIGHUP, signal.SIG_DFL)


if __name__ == '__main__':
    unittest.main()
