import csv
import collections
from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = root / 'artifacts' / 'ai_fraud_audit' / 'ocr_triage' / 'ocr_triage_results.csv'
out = root / 'artifacts' / 'ai_fraud_audit' / 'ocr_triage' / 'fail_reason_summary.txt'
rows = list(csv.DictReader(p.open(encoding='utf-8')))
fails = [r for r in rows if r['category'] == 'fail']

lines = []
lines.append('FAIL_COUNTS_BY_PLATFORM')
counts = collections.Counter(r['platform'] for r in fails)
for key, value in counts.items():
    lines.append(f'{key} {value}')
lines.append('---REASONS_BY_PLATFORM---')

for platform in ['ios', 'android']:
    pf = [r for r in fails if r['platform'] == platform]
    reasons = collections.Counter()
    for row in pf:
        for reason in row['reason'].split(';'):
            if reason:
                reasons[reason] += 1
    lines.append(f'PLATFORM {platform}')
    for key, value in reasons.most_common():
        lines.append(f'{key} {value}')
    lines.append('---')

out.write_text('\n'.join(lines), encoding='utf-8')
print(out)
