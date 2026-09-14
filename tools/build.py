#!/usr/bin/env python3
"""Owned, crash-recoverable Godot export jobs. Build hosts: macOS/Linux (POSIX)."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid

OWNER = 'riftfall-build-v1'
LIMIT = 1024 * 1024
ID = re.compile(r'^[0-9a-f]{32}$')
TARGETS = {'macos': ('macOS', 'RIFTFALL.app'),
           'windows': ('Windows Desktop', 'RIFTFALL.exe'),
           'pack': ('Windows Desktop', 'RIFTFALL.pck')}
# Explicit source inputs: includes untracked work and optional plugins, never caches.
INPUTS = ['project.godot', 'export_presets.cfg', 'default_bus_layout.tres',
          'assets', 'autoload', 'data', 'scenes', 'scripts', 'localization', 'addons']


def warn(path, reason):
    print(f'WARNING: retained path {path}: {reason}', file=sys.stderr, flush=True)


def read_json(path):
    if path.is_symlink():
        raise ValueError(f'symlink refused: {path}')
    return json.loads(path.read_text())


def atomic_json(path, value):
    temp = path.with_name(path.name + '.pending')
    if temp.is_symlink() or path.is_symlink():
        raise ValueError(f'symlink refused: {path}')
    with temp.open('w') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temp, path)
    sync_dir(path.parent)


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def directory(path):
    if path.is_symlink():
        raise ValueError(f'symlink refused: {path}')
    path.mkdir(exist_ok=True)
    return path


@contextlib.contextmanager
def lock(path, blocking=True):
    fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB))
        yield fd
    finally:
        os.close(fd)  # do not LOCK_UN: a live command guardian may share this lease


def owned(path, kind):
    if path.is_symlink() or not path.is_dir() or not ID.fullmatch(path.name):
        return False
    try:
        meta = read_json(path / 'owner.json')
        return meta.get('owner') == OWNER and meta.get('id') == path.name and meta.get('kind') == kind
    except (OSError, ValueError):
        return False


def remove_owned(path, parent, kind):
    if path.parent != parent or not owned(path, kind):
        warn(path, 'ownership check failed; no deletion')
        return False
    # Refuse nested symlinks too: do not traverse arbitrary source/plugin paths.
    if any(p.is_symlink() for p in path.rglob('*')):
        warn(path, 'symlink found; manual inspection required')
        return False
    try:
        shutil.rmtree(path)
        return True
    except OSError as exc:
        warn(path, str(exc))
        return False


class Store:
    def __init__(self, project):
        self.project = project.resolve()
        self.base = directory(directory(self.project / 'builds') / '.managed')
        with lock(self.base / 'registry.lock'):
            marker = self.base / 'owner.json'
            if marker.exists():
                if read_json(marker) != {'owner': OWNER, 'project': str(self.project)}:
                    raise ValueError(f'foreign build store: {self.base}')
            else:
                # An existing unmarked store with content must never be adopted.
                if set(p.name for p in self.base.iterdir()) != {'registry.lock'}:
                    raise ValueError(f'unmarked nonempty store: {self.base}')
                atomic_json(marker, {'owner': OWNER, 'project': str(self.project)})
            self.work = directory(self.base / 'work')
            self.dev = directory(self.base / 'dev')
            self.releases = directory(self.base / 'releases')
            self.logs = directory(self.base / 'logs')
            self.symbols = directory(self.base / 'symbols')
            (self.base / '.gdignore').touch()

    def recover(self):
        with lock(self.base / 'registry.lock'):
            for job in self.work.iterdir():
                if not owned(job, 'work'):
                    warn(job, 'unrecognized job; no deletion')
                    continue
                try:
                    with lock(job / 'lease.lock', blocking=False):
                        self.protect_symbols(job)
                        self.archive_log(job)
                        remove_owned(job, self.work, 'work')
                except BlockingIOError:
                    print(f'ACTIVE: {job}', flush=True)
                except (OSError, ValueError) as exc:
                    warn(job, str(exc))
            self.prune()

    def create(self):
        with lock(self.base / 'registry.lock'):
            job = self.work / uuid.uuid4().hex
            job.mkdir()
            atomic_json(job / 'owner.json', {'owner': OWNER, 'id': job.name, 'kind': 'work'})
            lease = lock(job / 'lease.lock')
            fd = lease.__enter__()
            return job, lease, fd

    def archive_log(self, job):
        src = job / 'raw.log'
        if src.is_symlink():
            raise ValueError(f'symlink refused: {src}')
        if src.exists():
            with src.open('rb') as stream:
                stream.seek(max(0, src.stat().st_size - LIMIT))
                data = stream.read(LIMIT)
            dst = self.logs / (job.name + '.log')
            if dst.is_symlink():
                raise ValueError(f'symlink refused: {dst}')
            dst.write_bytes(data)

    def prune(self):
        # Caller holds registry lock. Only successful managed development exports.
        for target in TARGETS:
            group = self.dev / target
            if not group.exists():
                continue
            if group.is_symlink():
                warn(group, 'symlink refused')
                continue
            packages = []
            for p in group.iterdir():
                if owned(p, 'dev'):
                    try:
                        meta = read_json(p / 'owner.json')
                        if meta.get('target') == target and meta.get('complete') is True:
                            packages.append((meta['completed_ns'], p))
                    except (OSError, ValueError, KeyError) as exc:
                        warn(p, str(exc))
                else:
                    warn(p, 'unrecognized package; no deletion')
            packages.sort(reverse=True)
            # Latest is switched only after a fully validated export is durable.
            pointer = self.base / ('latest-' + target + '.json')
            latest = None
            if pointer.exists():
                try:
                    latest = read_json(pointer)['id']
                except (OSError, ValueError, KeyError) as exc:
                    warn(pointer, f'cannot establish current package; skip pruning: {exc}')
                    continue
            keep = {p.name for _, p in packages[:2]}
            if latest:
                keep.add(latest)
            for _, p in packages:
                if p.name not in keep:
                    remove_owned(p, group, 'dev')
        logs = sorted((p for p in self.logs.iterdir() if p.is_file() and
                       not p.is_symlink() and re.fullmatch(r'[0-9a-f]{32}\.log', p.name)),
                      key=lambda p: p.stat().st_mtime_ns, reverse=True)
        for p in logs[10:]:
            try:
                p.unlink()
            except OSError as exc:
                warn(p, str(exc))

    def protect_symbols(self, job):
        package = job / 'package'
        if not package.exists():
            return
        candidates = []
        for p in package.rglob('*'):
            if p.suffix.lower() in {'.pdb', '.dsym', '.sym', '.map', '.debug'} or p.name == 'mapping.txt':
                if not any(parent in candidates for parent in p.parents):
                    candidates.append(p)
        if candidates:
            archive = directory(self.symbols / job.name)
            for p in candidates:
                relative = p.relative_to(package)
                dest = archive / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(p), str(dest))
            atomic_json(archive / 'owner.json', {'owner': OWNER, 'id': job.name, 'kind': 'symbols'})
            print(f'SYMBOLS PRESERVED: {archive}', flush=True)

    def finish(self, job):
        try:
            with lock(self.base / 'registry.lock'):
                self.protect_symbols(job)
                self.archive_log(job)
                remove_owned(job, self.work, 'work')
                self.prune()
        except (OSError, ValueError) as exc:
            warn(job, f'cleanup failed: {exc}')


def snapshot(project, dest):
    dest.mkdir()
    for name in INPUTS:
        src = project / name
        if not src.exists():
            if name == 'addons':
                continue
            raise ValueError(f'missing source input: {src}')
        if src.is_symlink() or (src.is_dir() and any(p.is_symlink() for p in src.rglob('*'))):
            raise ValueError(f'source symlink requires explicit build integration: {src}')
        if src.is_dir():
            shutil.copytree(src, dest / name, ignore=shutil.ignore_patterns('__pycache__', '.DS_Store'))
        else:
            shutil.copy2(src, dest / name)


def command_guardian(fd, log, command):
    # This separate process keeps the inherited lease even if the build CLI is
    # SIGKILLed. A subsequent invocation cannot reclaim files from a live Godot.
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, lambda *_: None)
    env = os.environ.copy()
    temporary = Path(log).parent / 'tmp'
    temporary.mkdir(exist_ok=True)
    env.update({key: str(temporary) for key in ('TMPDIR', 'TMP', 'TEMP')})
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    errors = False
    carry = b''
    with open(log, 'a+b') as stream:
        while True:
            block = process.stdout.read1(65536)
            if not block:
                break
            scan = carry + block
            errors |= b'ERROR:' in scan
            carry = scan[-32:]
            stream.seek(0, os.SEEK_END)
            stream.write(block)
            if stream.tell() > LIMIT:
                stream.seek(-LIMIT, os.SEEK_END)
                tail = stream.read(LIMIT)
                stream.seek(0)
                stream.write(tail)
                stream.truncate()
            stream.flush()
    code = process.wait()
    os.close(fd)
    return code if code else (1 if errors else 0)


def run(command, job, fd):
    print('STEP: ' + command[0] + ' ' + ' '.join(command[1:]), flush=True)
    proc = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--_command',
                             str(fd), str(job / 'raw.log'), *command],
                            pass_fds=(fd,), start_new_session=True, cwd=job)
    try:
        code = proc.wait()
        if code:
            raise RuntimeError(f'command failed ({code}); log: {job / "raw.log"}')
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()


def validate(package, target):
    path = package / TARGETS[target][1]
    if target == 'macos':
        executable = path / 'Contents/MacOS/RIFTFALL'
        if not executable.is_file() or not (path / 'Contents/Info.plist').is_file():
            raise ValueError('incomplete macOS app')
        packs = list((path / 'Contents/Resources').glob('*.pck'))
        if not packs or any(p.stat().st_size < 16 for p in packs):
            raise ValueError('missing macOS resources')
    else:
        with path.open('rb') as stream:
            magic = stream.read(4)
        if path.stat().st_size < 16 or (target == 'pack' and magic != b'GDPC') or (target == 'windows' and magic[:2] != b'MZ'):
            raise ValueError(f'invalid export: {path}')
    return {str(p.relative_to(package)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in package.rglob('*') if p.is_file()}


def build(store, args):
    store.recover()
    job, lease, fd = store.create()
    try:
        source = job / 'source'
        snapshot(store.project, source)
        package = job / 'package'
        package.mkdir()
        output = package / TARGETS[args.target][1]
        godot = shutil.which(args.godot)
        if not godot:
            raise ValueError(f'Godot executable not found: {args.godot}')
        run([godot, '--headless', '--path', str(source), '--import',
             '--log-file', str(job / 'engine.log')], job, fd)
        mode = '--export-pack' if args.target == 'pack' else ('--export-release' if args.release else '--export-debug')
        run([godot, '--headless', '--path', str(source), '--log-file', str(job / 'engine.log'),
             mode, TARGETS[args.target][0], str(output)], job, fd)
        hashes = validate(package, args.target)
        if not args.release:
            store.protect_symbols(job)
            hashes = validate(package, args.target)
        # Read-only resource load checks the actual packed project. Do not start
        # gameplay: that would access the user's persistent save directory.
        validator = job / 'validate.gd'
        validator.write_text('extends SceneTree\nfunc _init():\n'
                             '\tfor path in ["res://scenes/main.tscn", "res://data/content.tres", "res://assets/art/title_graveyard.png"]:\n'
                             '\t\tif load(path) == null:\n\t\t\tquit(1)\n\t\t\treturn\n\tquit(0)\n')
        pack = output if args.target == 'pack' else (next((output / 'Contents/Resources').glob('*.pck')) if args.target == 'macos' else None)
        if pack:
            run([godot, '--headless', '--path', str(source), '--main-pack', str(pack),
                 '--script', str(validator), '--log-file', str(job / 'engine.log')], job, fd)
        if args.verify_only:
            print('VERIFIED: temporary export; no package retained', flush=True)
            return
        kind = 'release' if args.release else 'dev'
        atomic_json(package / 'owner.json', {'owner': OWNER, 'id': job.name, 'kind': kind,
                    'target': args.target, 'complete': True, 'completed_ns': time.time_ns(),
                    'release': args.release, 'sha256': hashes})
        # Flush package bytes before the directory rename and pointer commit.
        for p in package.rglob('*'):
            if p.is_dir():
                sync_dir(p)
            if p.is_file():
                with p.open('rb') as stream:
                    os.fsync(stream.fileno())
        sync_dir(package)
        with lock(store.base / 'registry.lock'):
            group = directory((store.releases if args.release else store.dev) / args.target)
            if args.release:
                for p in group.iterdir():
                    if owned(p, 'release') and read_json(p / 'owner.json').get('release') == args.release:
                        raise ValueError(f'release label already archived: {args.release}')
            destination = group / job.name
            os.rename(package, destination)
            sync_dir(group)
            if not args.release:
                atomic_json(store.base / ('latest-' + args.target + '.json'),
                            {'id': job.name, 'path': str(destination.relative_to(store.base))})
            store.prune()
        print(f'PUBLISHED: {destination}', flush=True)
    finally:
        # Ignore repeated graceful cancellation while stopping children/cleaning.
        for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(sig, signal.SIG_IGN)
        store.finish(job)
        lease.__exit__(None, None, None)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--_command':
        return command_guardian(int(sys.argv[2]), sys.argv[3], sys.argv[4:])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['build', 'clean'])
    parser.add_argument('--target', choices=TARGETS, default='pack')
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--release', help='unique archival label; never automatically pruned')
    parser.add_argument('--verify-only', action='store_true', help='discard verified development export')
    args = parser.parse_args()
    if args.release and (args.verify_only or not re.fullmatch(r'[A-Za-z0-9._-]+', args.release)):
        parser.error('release label must be safe and cannot use --verify-only')
    def interrupted(sig, _frame):
        # One cancellation is enough; subsequent signals cannot break cleanup.
        for caught in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(caught, signal.SIG_IGN)
        raise KeyboardInterrupt(f'signal {sig}')
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, interrupted)
    try:
        store = Store(Path(__file__).resolve().parent.parent)
        if args.action == 'clean':
            store.recover()
        else:
            build(store, args)
        return 0
    except KeyboardInterrupt:
        print('CANCELLED: child stopped; owned work cleanup attempted', file=sys.stderr)
        return 130
    except (OSError, ValueError, RuntimeError) as exc:
        print(f'FAILED: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
