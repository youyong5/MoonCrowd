#!/usr/bin/env python3
"""Check, build and package a clean MoonCrowd checkout. Standard library only.

Run from a Git checkout:
  python3 tools/release.py --output ../releases/MoonCrowd-0.1.0.zip
The output includes tracked source, generated static demo, a complete Git bundle
and a SHA-256 file list. No remote push, publish, or deployment is performed.
"""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ['web/mooncrowd.js', 'web/LICENSE.txt', 'web/NOTICE.txt']


def run(*args):
    subprocess.run(list(args), cwd=ROOT, check=True)


def git_output(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def require_clean():
    if git_output('status', '--porcelain').strip():
        raise SystemExit('Commit or isolate working changes before creating a source-history release')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--upstream', type=Path,
                        help='Also independently verify both oracle files from a clean pinned RVO2 checkout')
    args = parser.parse_args()
    destination = args.output.resolve()
    if destination == ROOT or ROOT in destination.parents:
        raise SystemExit('Release output must be outside the source directory')
    if destination.suffix.lower() != '.zip':
        raise SystemExit('Release output must use .zip')
    require_clean()
    run('python3', 'tools/test_oracle_verifier.py')
    if args.upstream is not None:
        run('python3', 'tools/generate_oracle.py', '--upstream',
            str(args.upstream.resolve()), '--check')
    for command in [
        ['moon', 'version', '--all'],
        ['moon', 'fmt', '--check'],
        ['moon', 'check', '--target', 'all', '--deny-warn'],
        ['moon', 'build', '--target', 'all', '--deny-warn'],
        ['moon', 'test', '--target', 'all', '--deny-warn'],
        ['python3', 'tools/check_consumer.py'],
        ['python3', 'tools/check_consumer.py', '--source', 'package'],
        ['python3', 'tools/build_web.py'],
        ['node', 'tools/smoke_web.cjs'],
    ]:
        run(*command)
    require_clean()
    tracked = git_output('ls-files', '-z').decode('utf-8').split('\0')
    tracked = [name for name in tracked if name]
    if any(name in tracked for name in GENERATED):
        raise SystemExit('Generated web output should not be tracked in source history')
    entries = {}
    for name in tracked + GENERATED:
        source = ROOT / name
        if source.is_symlink() or not source.is_file():
            raise SystemExit(f'Release expects a regular source file: {name}')
        entries['MoonCrowd/' + name] = source.read_bytes()
    with tempfile.TemporaryDirectory(prefix='mooncrowd-bundle-') as temporary:
        bundle = Path(temporary) / 'SOURCE_HISTORY.bundle'
        run('git', 'bundle', 'create', str(bundle), '--all')
        run('git', 'bundle', 'verify', str(bundle))
        entries['MoonCrowd/SOURCE_HISTORY.bundle'] = bundle.read_bytes()
    manifest = ''.join(
        hashlib.sha256(data).hexdigest() + '  ' + name.removeprefix('MoonCrowd/') + '\n'
        for name, data in sorted(entries.items())
    )
    entries['MoonCrowd/MANIFEST.sha256'] = manifest.encode('utf-8')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, 'w', ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(entries.items()):
            archive.writestr(name, data)
    with ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise SystemExit('Release archive CRC check failed')
        for name, data in entries.items():
            if archive.read(name) != data:
                raise SystemExit('Release entry mismatch: ' + name)
    version = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT/'moon.mod').read_text(), re.M).group(1)
    commit = git_output('rev-parse', 'HEAD').decode().strip()
    print(f'Ready: {destination} ({destination.stat().st_size} bytes, {len(entries)} files)')
    print(f'MoonCrowd {version}; source commit {commit}; local archive only')


if __name__ == '__main__':
    main()
