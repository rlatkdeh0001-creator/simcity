#!/usr/bin/env python3
"""Read-only provenance checks. Never install or execute remote skill content."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import urllib.request

LOCK = Path(__file__).resolve().parents[1] / 'docs/asset-skills/sources.lock.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-heads', action='store_true', help='Compare current remote HEADs with reviewed commits; never update them.')
    parser.add_argument('--verify-pins', action='store_true', help='Read pinned source files and check their SHA-256 hashes.')
    args = parser.parse_args()
    data = json.loads(LOCK.read_text())
    errors = 0
    heads = {}
    for source in data['sources']:
        repo, commit = source['repository'], source['commit']
        if args.check_heads:
            if repo not in heads:
                result = subprocess.run(['git', 'ls-remote', f'https://github.com/{repo}.git', 'HEAD'], capture_output=True, text=True, timeout=30)
                words = result.stdout.split()
                heads[repo] = words[0] if result.returncode == 0 and words else None
            latest = heads[repo]
            status = 'UNKNOWN (read failed)' if latest is None else ('unchanged' if latest == commit else f'UPDATE AVAILABLE {latest}')
            print(source['id'], status)
            errors += latest is None
        if args.verify_pins:
            for item in source['files']:
                url = f'https://raw.githubusercontent.com/{repo}/{commit}/{item["path"]}'
                try:
                    with urllib.request.urlopen(url, timeout=30) as response:
                        digest = hashlib.sha256(response.read()).hexdigest()
                    if digest != item.get('sha256'):
                        raise ValueError('SHA-256 does not match reviewed source')
                    print('PASS', source['id'], item['path'])
                except Exception as error:
                    print('FAIL', source['id'], item['path'], type(error).__name__)
                    errors += 1
        if not args.check_heads and not args.verify_pins:
            print(source['id'], source['kind'], commit[:12], source['status'])
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
