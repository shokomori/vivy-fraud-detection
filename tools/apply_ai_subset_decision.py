from __future__ import annotations

import csv
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / 'artifacts' / 'ai_fraud_audit' / 'ocr_triage' / 'ocr_triage_results.csv'
EXCLUDED_DIR = ROOT / 'dataset' / 'NEW DATASET' / '_ocr_excluded_fail'
MANIFEST_PATH = EXCLUDED_DIR / 'excluded_manifest.csv'


def main() -> None:
    EXCLUDED_DIR.mkdir(parents=True, exist_ok=True)

    rows = list(csv.DictReader(CSV_PATH.open(encoding='utf-8')))
    excluded = []

    for row in rows:
        if row.get('category') != 'fail':
            continue
        rel = row['relative_path'].replace('/', '\\')
        src = ROOT / rel
        if not src.exists():
            continue
        dst = EXCLUDED_DIR / src.name
        counter = 1
        while dst.exists():
            dst = EXCLUDED_DIR / f"{src.stem}_{counter}{src.suffix}"
            counter += 1
        shutil.move(str(src), str(dst))
        excluded.append({
            'source_relative_path': row['relative_path'],
            'excluded_to': str(dst.relative_to(ROOT)).replace('\\', '/'),
            'platform': row['platform'],
            'reason': row['reason'],
            'category': row['category'],
        })

    with MANIFEST_PATH.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(
            f,
            fieldnames=['source_relative_path', 'excluded_to', 'platform', 'reason', 'category'],
        )
        writer.writeheader()
        writer.writerows(excluded)

    print(f'Excluded {len(excluded)} fail images to {EXCLUDED_DIR}')
    print(f'Manifest: {MANIFEST_PATH}')


if __name__ == '__main__':
    main()
