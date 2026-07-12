from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            'Run images through the app debug-batch pipeline via adb, '
            'verify backend usage, merge exported CSVs, and optionally run '
            'the Stage3/TFLite comparator.'
        )
    )
    parser.add_argument(
        '--manifest',
        required=True,
        help='Text file containing one absolute or repo-relative image path per line.',
    )
    parser.add_argument(
        '--output-dir',
        required=True,
        help='Directory where pulled CSVs, logs, and merged outputs will be written.',
    )
    parser.add_argument(
        '--chunk-size',
        type=int,
        default=50,
        help='Maximum number of images per adb-triggered batch run.',
    )
    parser.add_argument(
        '--require-backend',
        default='native-opencv',
        help='Expected backend_used value for every exported CSV row.',
    )
    parser.add_argument(
        '--compare-images-dir',
        help='Optional images root for compare_realworld_app_vs_stage3.py.',
    )
    parser.add_argument(
        '--compare-model',
        default='artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite',
        help='Model path for compare_realworld_app_vs_stage3.py when comparator is enabled.',
    )
    parser.add_argument(
        '--compare-out-name',
        default='comparison.json',
        help='Output filename for compare_realworld_app_vs_stage3.py JSON report.',
    )
    parser.add_argument(
        '--adb-serial',
        help='Optional adb serial to target a specific emulator/device.',
    )
    parser.add_argument(
        '--poll-interval-seconds',
        type=float,
        default=0.5,
        help='Polling interval while waiting for the app to finish a batch.',
    )
    parser.add_argument(
        '--poll-timeout-seconds',
        type=float,
        default=180.0,
        help='Maximum wait time per batch for last_batch_status.json to update.',
    )
    parser.add_argument(
        '--repo-root',
        default=str(Path(__file__).resolve().parents[1]),
        help='Workspace root used to resolve relative paths.',
    )
    return parser.parse_args()


class BatchValidator:
  DEVICE_ROOT = '/sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch'
  DEVICE_INBOX = f'{DEVICE_ROOT}/batch_inbox'
  DEVICE_TRIGGER = f'{DEVICE_ROOT}/trigger.run'
  DEVICE_STATUS = f'{DEVICE_ROOT}/last_batch_status.json'

  def __init__(self, args: argparse.Namespace) -> None:
    self.args = args
    self.repo_root = Path(args.repo_root).resolve()
    self.manifest_path = self._resolve_path(args.manifest)
    self.output_dir = self._resolve_path(args.output_dir)
    self.batch_root = self.output_dir / 'batches'
    self.log_path = self.output_dir / 'run.log'
    self.combined_csv_path = self.output_dir / 'combined_results.csv'
    self.comparison_json_path = self.output_dir / args.compare_out_name
    self.comparison_csv_path = self.comparison_json_path.with_suffix('.csv')
    self.comparator_log_path = self.output_dir / 'comparator.log'
    self.compare_script = self.repo_root / 'tools' / 'compare_realworld_app_vs_stage3.py'
    self.compare_images_dir = (
      self._resolve_path(args.compare_images_dir)
      if args.compare_images_dir
      else None
    )
    self.compare_model = self._resolve_path(args.compare_model)
    self.adb_prefix = ['adb']
    if args.adb_serial:
      self.adb_prefix.extend(['-s', args.adb_serial])

  def _resolve_path(self, raw_path: str | None) -> Path:
    if raw_path is None:
      raise ValueError('Path value must not be None.')
    path = Path(raw_path)
    if not path.is_absolute():
      path = self.repo_root / path
    return path.resolve()

  def log(self, message: str) -> None:
    self.output_dir.mkdir(parents=True, exist_ok=True)
    with self.log_path.open('a', encoding='utf-8') as handle:
      handle.write(message + '\n')

  def run_adb(self, *args: str) -> str:
    command = [*self.adb_prefix, *args]
    self.log(f'ADB {" ".join(args)}')
    proc = subprocess.run(command, capture_output=True, text=True)
    output = ((proc.stdout or '') + (proc.stderr or '')).strip()
    if proc.returncode != 0:
      self.log(f'ADB_FAIL code={proc.returncode} output={output!r}')
      raise RuntimeError(
        f'adb {" ".join(args)} failed with exit code {proc.returncode}\n{output}'
      )
    return output

  def get_status(self) -> dict | None:
    proc = subprocess.run(
      [*self.adb_prefix, 'shell', 'cat', self.DEVICE_STATUS],
      capture_output=True,
      text=True,
    )
    if proc.returncode != 0:
      return None
    text = (proc.stdout or '').strip()
    if not text.startswith('{'):
      return None
    try:
      return json.loads(text)
    except json.JSONDecodeError:
      return None

  def read_manifest(self) -> list[Path]:
    items = []
    for line in self.manifest_path.read_text(encoding='utf-8').splitlines():
      raw = line.strip()
      if not raw:
        continue
      items.append(self._resolve_path(raw))
    return items

  def read_rows(self, csv_path: Path) -> list[dict[str, str]]:
    with csv_path.open('r', encoding='utf-8', newline='') as handle:
      return list(csv.DictReader(handle))

  def chunked(self, items: list[Path]) -> list[list[Path]]:
    size = max(1, int(self.args.chunk_size))
    return [items[index:index + size] for index in range(0, len(items), size)]

  def write_combined_csv(self, csv_paths: list[Path]) -> None:
    header_written = False
    with self.combined_csv_path.open('w', encoding='utf-8', newline='') as out_handle:
      writer = None
      for csv_path in csv_paths:
        rows = self.read_rows(csv_path)
        if not rows:
          continue
        if not header_written:
          writer = csv.DictWriter(out_handle, fieldnames=list(rows[0].keys()))
          writer.writeheader()
          header_written = True
        assert writer is not None
        writer.writerows(rows)

  def run_comparator(self) -> None:
    if self.compare_images_dir is None:
      return
    command = [
      sys.executable,
      str(self.compare_script),
      '--app-csv',
      str(self.combined_csv_path),
      '--images-dir',
      str(self.compare_images_dir),
      '--model',
      str(self.compare_model),
      '--out-json',
      str(self.comparison_json_path),
    ]
    proc = subprocess.run(
      command,
      cwd=self.repo_root,
      capture_output=True,
      text=True,
    )
    combined_output = ((proc.stdout or '') + (proc.stderr or '')).strip()
    self.comparator_log_path.write_text(combined_output, encoding='utf-8')
    if proc.returncode != 0:
      raise RuntimeError(
        f'Comparator failed with exit code {proc.returncode}\n{combined_output}'
      )

  def run(self) -> None:
    if self.output_dir.exists():
      shutil.rmtree(self.output_dir)
    self.batch_root.mkdir(parents=True, exist_ok=True)
    self.log('START')

    files = self.read_manifest()
    if not files:
      raise RuntimeError('Manifest produced zero files.')

    previous_export = None
    baseline = self.get_status()
    if baseline:
      previous_export = baseline.get('export_csv_path')

    batch_summaries: list[dict[str, object]] = []
    batch_csvs: list[Path] = []
    for batch_index, batch_files in enumerate(self.chunked(files), start=1):
      self.log(f'BATCH_START {batch_index} size={len(batch_files)}')
      batch_dir = self.batch_root / f'batch_{batch_index:02d}'
      batch_dir.mkdir(parents=True, exist_ok=True)

      self.run_adb('shell', 'rm', '-f', f'{self.DEVICE_INBOX}/*')
      self.run_adb('shell', 'rm', '-f', self.DEVICE_TRIGGER)
      for file_path in batch_files:
        self.run_adb('push', str(file_path), f'{self.DEVICE_INBOX}/')

      self.run_adb('shell', 'touch', self.DEVICE_TRIGGER)
      self.run_adb(
        'shell',
        'monkey',
        '-p',
        'com.example.vivy_app',
        '-c',
        'android.intent.category.LAUNCHER',
        '1',
      )

      deadline = time.time() + float(self.args.poll_timeout_seconds)
      status = None
      while time.time() < deadline:
        candidate = self.get_status()
        if (
          candidate
          and candidate.get('export_csv_path')
          and candidate.get('export_csv_path') != previous_export
          and int(candidate.get('processed_count', -1)) == len(batch_files)
        ):
          status = candidate
          break
        time.sleep(float(self.args.poll_interval_seconds))

      if status is None:
        raise RuntimeError(
          f'Batch {batch_index} did not complete with expected processed_count={len(batch_files)}'
        )

      previous_export = str(status['export_csv_path'])
      local_csv = batch_dir / Path(previous_export).name
      self.log(f'BATCH_DONE {batch_index} export={previous_export}')
      self.run_adb('pull', previous_export, str(local_csv))
      (batch_dir / 'last_batch_status.json').write_text(
        json.dumps(status, indent=2),
        encoding='utf-8',
      )

      rows = self.read_rows(local_csv)
      if len(rows) != len(batch_files):
        raise RuntimeError(
          f'Batch {batch_index} CSV row count mismatch: expected {len(batch_files)}, got {len(rows)}'
        )

      fallback_rows = [
        row for row in rows if row.get('backend_used') != self.args.require_backend
      ]
      if fallback_rows:
        fallback_path = batch_dir / 'unexpected_backend_rows.csv'
        with fallback_path.open('w', encoding='utf-8', newline='') as handle:
          writer = csv.DictWriter(handle, fieldnames=list(fallback_rows[0].keys()))
          writer.writeheader()
          writer.writerows(fallback_rows)
        raise RuntimeError(
          f'Batch {batch_index} has {len(fallback_rows)} row(s) with backend_used != {self.args.require_backend}'
        )

      batch_summaries.append(
        {
          'batch': batch_index,
          'row_count': len(rows),
          'csv': str(local_csv),
          'backend_expected_rows': len(rows),
          'required_backend': self.args.require_backend,
        }
      )
      batch_csvs.append(local_csv)

    self.write_combined_csv(batch_csvs)
    (self.output_dir / 'batch_summary.json').write_text(
      json.dumps(batch_summaries, indent=2),
      encoding='utf-8',
    )
    self.run_comparator()
    self.log('DONE')


def main() -> None:
  args = parse_args()
  validator = BatchValidator(args)
  try:
    validator.run()
  except Exception as exc:
    validator.log(f'FATAL {type(exc).__name__}: {exc}')
    raise


if __name__ == '__main__':
  main()