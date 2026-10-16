"""Fetch missing official source files using the pinned download manifest."""

from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
import hashlib
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def fetch(row):
    relative = Path(row['path'])
    if relative.is_absolute() or '..' in relative.parts:
        raise ValueError('Source path must be relative to the project')
    destination = ROOT / relative
    existing = destination.is_file()
    if existing:
        data = destination.read_bytes()
    else:
        request = urllib.request.Request(
            row['url'], headers={'User-Agent': 'Mozilla/5.0 (research reproducibility)'}
        )
        with urllib.request.urlopen(request, timeout=90) as response:
            data = response.read()
    if len(data) != int(row['bytes']) or hashlib.sha256(data).hexdigest() != row['sha256']:
        raise ValueError('Source differs from the recorded original; the file and manifest were not replaced')
    if not existing:
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open('xb') as stream:
            stream.write(data)
    return not existing


def main():
    with (ROOT / 'data/download_manifest.csv').open(newline='', encoding='utf-8') as stream:
        rows = list(csv.DictReader(stream))
    failures = []
    downloaded = 0
    with ThreadPoolExecutor(max_workers=6) as pool:
        jobs = {pool.submit(fetch, row): row['path'] for row in rows}
        for job in as_completed(jobs):
            try:
                downloaded += int(job.result())
            except Exception as error:
                failures.append(f'{jobs[job]}: {error}')
    if failures:
        for message in sorted(failures):
            print(message)
        return 1
    print(f'Validated {len(rows)} original source files; downloaded {downloaded}.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
