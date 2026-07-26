from __future__ import annotations

import csv
import hashlib
import json
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image

ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}


@dataclass
class AuditRow:
    source_rel: str
    target_rel: str
    platform: str
    width: int
    height: int
    aspect: float
    extension: str
    sha256: str
    status: str
    reason: str


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sanitize_stem(stem: str) -> str:
    chars = []
    for ch in stem.lower():
        chars.append(ch if ch.isalnum() else "_")
    s = "".join(chars).strip("_")
    while "__" in s:
        s = s.replace("__", "_")
    return s or "img"


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset_dir = root / "dataset"

    source_android = dataset_dir / "NEW DATASET" / "Android Fraud"
    source_ios = dataset_dir / "NEW DATASET" / "iOS Fraud"

    target_android = dataset_dir / "AndroidAIFraudulent"
    target_ios = dataset_dir / "iOSAIFraudulent"
    rejected_dir = dataset_dir / "NEW DATASET" / "_rejected"

    audit_dir = root / "artifacts" / "ai_fraud_audit"
    thumbs_dir = audit_dir / "thumbnails"
    review_dir = audit_dir / "borderline_review"

    # Reset ingestion/audit outputs for clean rerun.
    if target_android.exists():
        shutil.rmtree(target_android)
    if target_ios.exists():
        shutil.rmtree(target_ios)
    if rejected_dir.exists():
        shutil.rmtree(rejected_dir)
    if audit_dir.exists():
        shutil.rmtree(audit_dir)

    target_android.mkdir(parents=True, exist_ok=True)
    target_ios.mkdir(parents=True, exist_ok=True)
    rejected_dir.mkdir(parents=True, exist_ok=True)
    thumbs_dir.mkdir(parents=True, exist_ok=True)
    review_dir.mkdir(parents=True, exist_ok=True)

    incoming: List[Tuple[Path, str]] = []
    for p in sorted(source_android.iterdir()):
        if p.is_file():
            incoming.append((p, "android"))
    for p in sorted(source_ios.iterdir()):
        if p.is_file():
            incoming.append((p, "ios"))

    # Exact duplicate checks only (objective) against existing dataset and within incoming batch.
    existing_sha: Dict[str, str] = {}
    for folder_name in ["AndroidFraudulent", "AndroidGenuine", "iOSFraudulent", "iOSGenuine"]:
        folder = dataset_dir / folder_name
        if not folder.exists():
            continue
        for p in folder.iterdir():
            if not p.is_file() or p.suffix.lower() not in ALLOWED_EXTS:
                continue
            try:
                sh = sha256_file(p)
            except Exception:
                continue
            existing_sha[sh] = str(p.relative_to(root)).replace("\\", "/")

    seen_incoming_sha: Dict[str, str] = {}
    rows: List[AuditRow] = []

    for idx, (src, platform) in enumerate(incoming, start=1):
        ext = src.suffix.lower()
        src_rel = str(src.relative_to(root)).replace("\\", "/")
        stem = sanitize_stem(src.stem)

        target_folder = target_android if platform == "android" else target_ios
        target_name = f"ai_{platform}_{idx:03d}_{stem}{ext if ext else '.png'}"
        target_path = target_folder / target_name

        target_rel = str(target_path.relative_to(root)).replace("\\", "/")

        if ext not in ALLOWED_EXTS:
            rej = rejected_dir / f"{platform}_{src.name}"
            shutil.copy2(src, rej)
            rows.append(
                AuditRow(src_rel, target_rel, platform, 0, 0, 0.0, ext, "", "rejected", "format_not_allowed")
            )
            continue

        try:
            with Image.open(src) as img:
                img.load()
                width, height = img.size
        except Exception:
            rej = rejected_dir / f"{platform}_{src.name}"
            shutil.copy2(src, rej)
            rows.append(
                AuditRow(src_rel, target_rel, platform, 0, 0, 0.0, ext, "", "rejected", "corrupt_or_unreadable")
            )
            continue

        aspect = (width / height) if height else 0.0

        sh = sha256_file(src)
        if sh in existing_sha:
            rej = rejected_dir / f"{platform}_{src.name}"
            shutil.copy2(src, rej)
            rows.append(
                AuditRow(
                    src_rel,
                    target_rel,
                    platform,
                    width,
                    height,
                    aspect,
                    ext,
                    sh,
                    "rejected",
                    f"exact_duplicate_existing:{existing_sha[sh]}",
                )
            )
            continue

        if sh in seen_incoming_sha:
            rej = rejected_dir / f"{platform}_{src.name}"
            shutil.copy2(src, rej)
            rows.append(
                AuditRow(
                    src_rel,
                    target_rel,
                    platform,
                    width,
                    height,
                    aspect,
                    ext,
                    sh,
                    "rejected",
                    f"exact_duplicate_incoming:{seen_incoming_sha[sh]}",
                )
            )
            continue

        # Borderline only (manual review): low-res or unusual aspect for screenshot-like content.
        borderline_reasons: List[str] = []
        if width < 540 or height < 960:
            borderline_reasons.append("low_resolution")
        if aspect < 0.38 or aspect > 0.60:
            borderline_reasons.append("aspect_outlier")

        suffix_counter = 1
        while target_path.exists():
            target_name = f"ai_{platform}_{idx:03d}_{stem}_{suffix_counter}{ext}"
            target_path = target_folder / target_name
            target_rel = str(target_path.relative_to(root)).replace("\\", "/")
            suffix_counter += 1

        shutil.copy2(src, target_path)
        seen_incoming_sha[sh] = src_rel

        status = "borderline" if borderline_reasons else "accepted"
        reason = ";".join(borderline_reasons) if borderline_reasons else "passed_objective_checks"
        rows.append(
            AuditRow(src_rel, target_rel, platform, width, height, aspect, ext, sh, status, reason)
        )

        if status == "borderline":
            with Image.open(target_path) as img:
                thumb = img.convert("RGB")
                thumb.thumbnail((300, 300), Image.Resampling.LANCZOS)
                thumb.save(thumbs_dir / f"{target_path.stem}_thumb.jpg", quality=90)

    accepted = [r for r in rows if r.status == "accepted"]
    borderline = [r for r in rows if r.status == "borderline"]
    rejected = [r for r in rows if r.status == "rejected"]

    # Write full CSV.
    audit_csv = audit_dir / "ai_fraud_audit.csv"
    with audit_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "source_rel",
            "target_rel",
            "platform",
            "width",
            "height",
            "aspect",
            "extension",
            "sha256",
            "status",
            "reason",
        ])
        for r in rows:
            writer.writerow([
                r.source_rel,
                r.target_rel,
                r.platform,
                r.width,
                r.height,
                f"{r.aspect:.6f}",
                r.extension,
                r.sha256,
                r.status,
                r.reason,
            ])

    # Borderline review CSV.
    review_csv = review_dir / "borderline_review.csv"
    with review_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "target_rel",
            "platform",
            "width",
            "height",
            "aspect",
            "reason",
            "thumbnail_rel",
        ])
        for r in borderline:
            thumb_rel = str((thumbs_dir / f"{Path(r.target_rel).stem}_thumb.jpg").relative_to(root)).replace("\\", "/")
            writer.writerow([
                r.target_rel,
                r.platform,
                r.width,
                r.height,
                f"{r.aspect:.6f}",
                r.reason,
                thumb_rel,
            ])

    # Summary.
    rej_counts: Dict[str, int] = {}
    for r in rejected:
        rej_counts[r.reason] = rej_counts.get(r.reason, 0) + 1

    def stats(items: List[AuditRow]) -> Dict[str, float]:
        if not items:
            return {
                "count": 0,
                "min_w": 0,
                "max_w": 0,
                "median_w": 0,
                "min_h": 0,
                "max_h": 0,
                "median_h": 0,
                "min_aspect": 0,
                "max_aspect": 0,
                "median_aspect": 0,
            }
        ws = sorted(i.width for i in items)
        hs = sorted(i.height for i in items)
        ars = sorted(i.aspect for i in items)
        n = len(items)

        def med(vals: List[float]) -> float:
            m = n // 2
            if n % 2:
                return float(vals[m])
            return float((vals[m - 1] + vals[m]) / 2.0)

        return {
            "count": n,
            "min_w": int(ws[0]),
            "max_w": int(ws[-1]),
            "median_w": med([float(v) for v in ws]),
            "min_h": int(hs[0]),
            "max_h": int(hs[-1]),
            "median_h": med([float(v) for v in hs]),
            "min_aspect": float(ars[0]),
            "max_aspect": float(ars[-1]),
            "median_aspect": med(ars),
        }

    summary = {
        "incoming_total": len(incoming),
        "accepted_total": len(accepted),
        "borderline_total": len(borderline),
        "rejected_total": len(rejected),
        "accepted_android": sum(1 for r in accepted if r.platform == "android"),
        "accepted_ios": sum(1 for r in accepted if r.platform == "ios"),
        "borderline_android": sum(1 for r in borderline if r.platform == "android"),
        "borderline_ios": sum(1 for r in borderline if r.platform == "ios"),
        "rejected_reasons": rej_counts,
        "accepted_stats": stats(accepted),
        "borderline_stats": stats(borderline),
    }

    summary_json = audit_dir / "ai_fraud_audit_summary.json"
    with summary_json.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    report_md = audit_dir / "README.md"
    with report_md.open("w", encoding="utf-8") as f:
        f.write("# AI Fraud Audit\n\n")
        f.write(f"Incoming: {len(incoming)}\n\n")
        f.write(f"Accepted: {len(accepted)}\n\n")
        f.write(f"Borderline: {len(borderline)}\n\n")
        f.write(f"Rejected: {len(rejected)}\n\n")
        f.write("Outputs:\n")
        f.write("- artifacts/ai_fraud_audit/ai_fraud_audit.csv\n")
        f.write("- artifacts/ai_fraud_audit/ai_fraud_audit_summary.json\n")
        f.write("- artifacts/ai_fraud_audit/borderline_review/borderline_review.csv\n")
        f.write("- artifacts/ai_fraud_audit/thumbnails/*.jpg\n")

    print(f"Audit complete: {summary_json}")


if __name__ == "__main__":
    main()
