from __future__ import annotations

import csv
import json
import math
import statistics as st
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, List, Tuple

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from rapidocr_onnxruntime import RapidOCR

ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}


@dataclass
class OcrMetrics:
    relative_path: str
    platform: str
    subset: str
    width: int
    height: int
    aspect: float
    box_count: int
    strong_box_count: int
    line_count: int
    total_chars: int
    alpha_num_chars: int
    avg_conf: float
    median_conf: float
    text_area_ratio: float
    text_height_ratio: float
    digit_ratio: float
    ocr_pass: str = ""
    ocr_reason: str = ""
    fraud_relative_pass: str = ""
    fraud_relative_reason: str = ""
    fraud_relative_score: float = 0.0


def percentile(vals: List[float], q: float) -> float:
    if not vals:
        return 0.0
    arr = np.asarray(sorted(vals), dtype=np.float64)
    return float(np.percentile(arr, q))


def collect_images(folder: Path, root: Path, platform: str, subset: str) -> List[Tuple[Path, str, str, str]]:
    out = []
    if not folder.exists():
        return out
    for p in sorted(folder.iterdir()):
        if p.is_file() and p.suffix.lower() in ALLOWED_EXTS:
            out.append((p, str(p.relative_to(root)).replace("\\", "/"), platform, subset))
    return out


def preprocess_for_ocr(path: Path) -> np.ndarray:
    img = cv2.imdecode(np.fromfile(str(path), dtype=np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError(f"Failed to load {path}")
    h, w = img.shape[:2]
    if w < 900:
        scale = 900.0 / max(1, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_CUBIC)
    return img


def normalize_text(text: str) -> str:
    return "".join(ch for ch in text if ch.isprintable()).strip()


def cluster_lines(boxes: List[Tuple[float, float, float, float]]) -> int:
    if not boxes:
        return 0
    centers = sorted((y1 + y2) / 2.0 for (_, y1, _, y2) in boxes)
    heights = sorted((y2 - y1) for (_, y1, _, y2) in boxes)
    median_h = st.median(heights) if heights else 12.0
    tolerance = max(8.0, median_h * 0.8)

    lines = 1
    anchor = centers[0]
    for c in centers[1:]:
        if abs(c - anchor) > tolerance:
            lines += 1
            anchor = c
        else:
            anchor = (anchor + c) / 2.0
    return lines


def run_ocr_metrics(ocr: RapidOCR, path: Path, rel: str, platform: str, subset: str) -> OcrMetrics:
    img = preprocess_for_ocr(path)
    h, w = img.shape[:2]
    result, _ = ocr(img)
    result = result or []

    boxes: List[Tuple[float, float, float, float]] = []
    confs: List[float] = []
    total_chars = 0
    alpha_num_chars = 0
    digit_chars = 0
    strong_boxes = 0
    area_sum = 0.0
    box_heights = []

    for item in result:
        if not item or len(item) < 3:
            continue
        poly, text, conf = item[0], normalize_text(str(item[1])), float(item[2])
        if len(poly) < 4:
            continue

        xs = [float(pt[0]) for pt in poly]
        ys = [float(pt[1]) for pt in poly]
        x1, x2 = min(xs), max(xs)
        y1, y2 = min(ys), max(ys)
        bw = max(1.0, x2 - x1)
        bh = max(1.0, y2 - y1)

        if conf >= 0.50 and text:
            boxes.append((x1, y1, x2, y2))
            confs.append(conf)
            total_chars += len(text)
            alpha_num = sum(ch.isalnum() for ch in text)
            digits = sum(ch.isdigit() for ch in text)
            alpha_num_chars += alpha_num
            digit_chars += digits
            area_sum += bw * bh
            box_heights.append(bh)
            if conf >= 0.75 and len(text) >= 2:
                strong_boxes += 1

    line_count = cluster_lines(boxes)
    avg_conf = float(sum(confs) / len(confs)) if confs else 0.0
    median_conf = float(st.median(confs)) if confs else 0.0
    text_area_ratio = float(area_sum / float(w * h)) if w and h else 0.0
    text_height_ratio = float((st.median(box_heights) / h)) if box_heights and h else 0.0
    digit_ratio = float(digit_chars / max(1, alpha_num_chars))

    return OcrMetrics(
        relative_path=rel,
        platform=platform,
        subset=subset,
        width=w,
        height=h,
        aspect=(w / h) if h else 0.0,
        box_count=len(boxes),
        strong_box_count=strong_boxes,
        line_count=line_count,
        total_chars=total_chars,
        alpha_num_chars=alpha_num_chars,
        avg_conf=avg_conf,
        median_conf=median_conf,
        text_area_ratio=text_area_ratio,
        text_height_ratio=text_height_ratio,
        digit_ratio=digit_ratio,
    )


def classify_ocr_readability(row: OcrMetrics) -> Tuple[str, str]:
    reasons = []
    if row.box_count < 8:
        reasons.append("too_few_ocr_boxes")
    if row.line_count < 5:
        reasons.append("too_few_text_lines")
    if row.alpha_num_chars < 35:
        reasons.append("too_few_readable_chars")
    if row.avg_conf < 0.55:
        reasons.append("low_avg_ocr_conf")
    if row.text_area_ratio < 0.010:
        reasons.append("too_little_text_area")

    if row.box_count >= 14 and row.line_count >= 8 and row.alpha_num_chars >= 70 and row.avg_conf >= 0.68 and row.text_area_ratio >= 0.018:
        return "pass", "readable_receipt_like_text_structure"
    if len(reasons) >= 3 or row.box_count <= 4 or row.alpha_num_chars <= 15:
        return "fail", ";".join(reasons) if reasons else "severe_ocr_failure"
    return "ambiguous", ";".join(reasons) if reasons else "borderline_ocr_signal"


def summarize_distribution(rows: List[OcrMetrics], fields: List[str]) -> Dict[str, Dict[str, float]]:
    out: Dict[str, Dict[str, float]] = {}
    for field in fields:
        vals = [float(getattr(r, field)) for r in rows]
        out[field] = {
            "p05": percentile(vals, 5),
            "p25": percentile(vals, 25),
            "p50": percentile(vals, 50),
            "p75": percentile(vals, 75),
            "p95": percentile(vals, 95),
        }
    return out


def score_against_fraud_distribution(row: OcrMetrics, ref_stats: Dict[str, Dict[str, float]]) -> Tuple[float, List[str]]:
    # Score relative to existing fraud distributions: strong penalty outside p05-p95,
    # mild penalty outside p25-p75.
    fields = [
        "box_count",
        "strong_box_count",
        "line_count",
        "alpha_num_chars",
        "avg_conf",
        "median_conf",
        "text_area_ratio",
        "digit_ratio",
    ]
    score = 1.0
    reasons: List[str] = []
    for field in fields:
        val = float(getattr(row, field))
        s = ref_stats[field]
        if val < s["p05"] or val > s["p95"]:
            score -= 0.18
            reasons.append(f"{field}_outside_p05_p95")
        elif val < s["p25"] or val > s["p75"]:
            score -= 0.08
            reasons.append(f"{field}_outside_iqr")
    return max(0.0, score), reasons


def classify_fraud_relative(row: OcrMetrics, ref_stats: Dict[str, Dict[str, float]]) -> Tuple[str, str, float]:
    score, reasons = score_against_fraud_distribution(row, ref_stats)

    if row.ocr_pass == "fail":
        return "fail", "ocr_fail_carries_over", 0.0

    hard_fail = [r for r in reasons if r.endswith("outside_p05_p95")]
    if score >= 0.72 and len(hard_fail) <= 1:
        return "pass", "within_existing_fraud_distribution", score
    if score <= 0.36 or len(hard_fail) >= 4:
        return "fail", ";".join(hard_fail[:6]) if hard_fail else "far_from_existing_fraud_distribution", score
    return "ambiguous", ";".join(reasons[:8]) if reasons else "borderline_vs_existing_fraud_distribution", score


def write_csv(rows: List[OcrMetrics], out_path: Path, mode: str) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([
            "relative_path",
            "platform",
            "subset",
            "width",
            "height",
            "aspect",
            "box_count",
            "strong_box_count",
            "line_count",
            "total_chars",
            "alpha_num_chars",
            "avg_conf",
            "median_conf",
            "text_area_ratio",
            "text_height_ratio",
            "digit_ratio",
            f"{mode}_pass",
            f"{mode}_reason",
            "fraud_relative_score",
        ])
        for r in rows:
            if mode == "ocr":
                tri, reason = r.ocr_pass, r.ocr_reason
            else:
                tri, reason = r.fraud_relative_pass, r.fraud_relative_reason
            w.writerow([
                r.relative_path,
                r.platform,
                r.subset,
                r.width,
                r.height,
                f"{r.aspect:.6f}",
                r.box_count,
                r.strong_box_count,
                r.line_count,
                r.total_chars,
                r.alpha_num_chars,
                f"{r.avg_conf:.6f}",
                f"{r.median_conf:.6f}",
                f"{r.text_area_ratio:.6f}",
                f"{r.text_height_ratio:.6f}",
                f"{r.digit_ratio:.6f}",
                tri,
                reason,
                f"{r.fraud_relative_score:.6f}",
            ])


def make_sheet(rows: List[OcrMetrics], root: Path, out_path: Path, title: str, triage_attr: str, reason_attr: str, cols: int = 5) -> None:
    if not rows:
        return
    tw, th = 230, 230
    label_h = 96
    pad = 12
    title_h = 64
    count = len(rows)
    rcount = (count + cols - 1) // cols
    canvas = Image.new("RGB", (pad + cols * (tw + pad), title_h + pad + rcount * (th + label_h + pad)), (246, 248, 253))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    draw.text((pad, 18), title, fill=(20, 35, 70), font=font)

    for i, row in enumerate(rows):
        rr = i // cols
        cc = i % cols
        x = pad + cc * (tw + pad)
        y = title_h + pad + rr * (th + label_h + pad)

        img_path = root / row.relative_path
        with Image.open(img_path) as im:
            rgb = im.convert("RGB")
            rgb.thumbnail((tw, th), Image.Resampling.LANCZOS)
            tile = Image.new("RGB", (tw, th), (228, 233, 243))
            ox = (tw - rgb.width) // 2
            oy = (th - rgb.height) // 2
            tile.paste(rgb, (ox, oy))
        canvas.paste(tile, (x, y))
        draw.rectangle([x, y, x + tw - 1, y + th - 1], outline=(170, 180, 205), width=1)

        name = Path(row.relative_path).name
        triage = getattr(row, triage_attr)
        reason = getattr(row, reason_attr)
        draw.text((x, y + th + 4), name[:30], fill=(35, 45, 72), font=font)
        draw.text((x, y + th + 22), f"ocr boxes={row.box_count} lines={row.line_count} chars={row.alpha_num_chars}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 40), f"avg={row.avg_conf:.2f} area={row.text_area_ratio:.3f} score={row.fraud_relative_score:.2f}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 58), f"{triage}: {reason[:32]}", fill=(100, 55, 55), font=font)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, quality=92)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset = root / "dataset"
    out_dir = root / "artifacts" / "ai_fraud_audit" / "ocr_triage"
    out_dir.mkdir(parents=True, exist_ok=True)

    ocr = RapidOCR()

    reference = []
    reference += collect_images(dataset / "AndroidFraudulent", root, "android", "reference_fraud")
    reference += collect_images(dataset / "iOSFraudulent", root, "ios", "reference_fraud")

    incoming = []
    incoming += collect_images(dataset / "AndroidAIFraudulent", root, "android", "incoming_ai")
    incoming += collect_images(dataset / "iOSAIFraudulent", root, "ios", "incoming_ai")

    ref_rows: List[OcrMetrics] = []
    for p, rel, platform, subset in reference:
        ref_rows.append(run_ocr_metrics(ocr, p, rel, platform, subset))

    incoming_rows: List[OcrMetrics] = []
    for p, rel, platform, subset in incoming:
        incoming_rows.append(run_ocr_metrics(ocr, p, rel, platform, subset))

    # Platform-specific fraud reference distributions.
    fields = [
        "box_count",
        "strong_box_count",
        "line_count",
        "alpha_num_chars",
        "avg_conf",
        "median_conf",
        "text_area_ratio",
        "digit_ratio",
    ]
    ref_stats = {
        "android": summarize_distribution([r for r in ref_rows if r.platform == "android"], fields),
        "ios": summarize_distribution([r for r in ref_rows if r.platform == "ios"], fields),
    }

    for row in incoming_rows:
        row.ocr_pass, row.ocr_reason = classify_ocr_readability(row)
        row.fraud_relative_pass, row.fraud_relative_reason, row.fraud_relative_score = classify_fraud_relative(
            row,
            ref_stats[row.platform],
        )

    write_csv(incoming_rows, out_dir / "ocr_readability_results.csv", mode="ocr")
    write_csv(incoming_rows, out_dir / "fraud_relative_results.csv", mode="fraud_relative")

    ocr_pass = [r for r in incoming_rows if r.ocr_pass == "pass"]
    ocr_amb = [r for r in incoming_rows if r.ocr_pass == "ambiguous"]
    ocr_fail = [r for r in incoming_rows if r.ocr_pass == "fail"]

    fr_pass = [r for r in incoming_rows if r.fraud_relative_pass == "pass"]
    fr_amb = [r for r in incoming_rows if r.fraud_relative_pass == "ambiguous"]
    fr_fail = [r for r in incoming_rows if r.fraud_relative_pass == "fail"]

    summary = {
        "ocr_readability": {
            "pass": len(ocr_pass),
            "ambiguous": len(ocr_amb),
            "fail": len(ocr_fail),
        },
        "fraud_relative": {
            "pass": len(fr_pass),
            "ambiguous": len(fr_amb),
            "fail": len(fr_fail),
        },
        "reference_distribution": ref_stats,
    }
    with (out_dir / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    # Pick low-confidence/uncertain sheets from the method that actually spreads.
    fr_uncertain = sorted(fr_amb + fr_fail, key=lambda r: (r.fraud_relative_score, r.box_count, r.alpha_num_chars))
    ocr_uncertain = sorted(ocr_amb + ocr_fail, key=lambda r: (r.avg_conf, r.box_count, r.alpha_num_chars))

    make_sheet(fr_uncertain[:20], root, out_dir / "fraud_relative_uncertain_20.jpg", "Fraud-relative uncertain set (top 20)", "fraud_relative_pass", "fraud_relative_reason", cols=5)
    make_sheet(fr_fail[:20], root, out_dir / "fraud_relative_fail_20.jpg", "Fraud-relative fail candidates", "fraud_relative_pass", "fraud_relative_reason", cols=5)
    make_sheet(ocr_uncertain[:20], root, out_dir / "ocr_uncertain_20.jpg", "OCR readability uncertain set (top 20)", "ocr_pass", "ocr_reason", cols=5)

    # Also emit smallest manual-review CSV.
    review_rows = fr_uncertain if fr_uncertain else ocr_uncertain
    with (out_dir / "manual_review_priority.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([
            "relative_path",
            "platform",
            "ocr_pass",
            "ocr_reason",
            "fraud_relative_pass",
            "fraud_relative_reason",
            "fraud_relative_score",
            "box_count",
            "line_count",
            "alpha_num_chars",
            "avg_conf",
        ])
        for r in review_rows[:30]:
            w.writerow([
                r.relative_path,
                r.platform,
                r.ocr_pass,
                r.ocr_reason,
                r.fraud_relative_pass,
                r.fraud_relative_reason,
                f"{r.fraud_relative_score:.6f}",
                r.box_count,
                r.line_count,
                r.alpha_num_chars,
                f"{r.avg_conf:.6f}",
            ])

    print(out_dir / "summary.json")


if __name__ == "__main__":
    main()
