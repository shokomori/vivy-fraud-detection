from __future__ import annotations

import csv
import json
import math
import re
import statistics
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import cv2
import numpy as np
from PIL import Image
import pytesseract

# Explicit Tesseract binary location installed via winget.
TESSERACT_PATH = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
pytesseract.pytesseract.tesseract_cmd = str(TESSERACT_PATH)

OCR_CONFIG = "--oem 3 --psm 6"

RECEIPT_KEYWORDS = [
    "gcash",
    "receipt",
    "total",
    "amount",
    "reference",
    "ref",
    "transaction",
    "merchant",
    "balance",
    "date",
    "time",
    "id",
    "order",
    "phone",
    "number",
    "no.",
    "₱",
    "php",
    "peso",
    "gcash",
    "paid",
    "due",
    "cash",
]

STRUCT_FEATURES = [
    "edge_density",
    "text_pixel_ratio",
    "line_band_count",
    "component_count",
    "entropy",
]

OCR_FEATURES = [
    "ocr_text_len",
    "ocr_word_count",
    "ocr_line_count",
    "ocr_mean_conf",
    "ocr_keyword_count",
    "ocr_numeric_ratio",
    "ocr_currency_count",
]

@dataclass
class ReviewRow:
    relative_path: str
    platform: str
    width: int
    height: int
    aspect: float
    structural: Dict[str, float]
    ocr: Dict[str, float]
    category: str
    reasons: str


def entropy_u8(gray: np.ndarray) -> float:
    hist = np.bincount(gray.ravel(), minlength=256).astype(np.float64)
    total = hist.sum()
    if total <= 0:
        return 0.0
    p = hist / total
    p = p[p > 0]
    return float(-(p * np.log2(p)).sum())


def sobel_edges(gray: np.ndarray) -> np.ndarray:
    gx = np.zeros_like(gray, dtype=np.float32)
    gy = np.zeros_like(gray, dtype=np.float32)
    gx[:, 1:-1] = (gray[:, 2:] - gray[:, :-2]) * 0.5
    gy[1:-1, :] = (gray[2:, :] - gray[:-2, :]) * 0.5
    return np.sqrt(gx * gx + gy * gy)


def otsu_threshold(gray: np.ndarray) -> int:
    hist = np.bincount(gray.ravel(), minlength=256).astype(np.float64)
    total = gray.size
    sum_total = np.dot(np.arange(256), hist)
    sum_b = 0.0
    w_b = 0.0
    max_var = -1.0
    threshold = 127
    for t in range(256):
        w_b += hist[t]
        if w_b == 0:
            continue
        w_f = total - w_b
        if w_f == 0:
            break
        sum_b += t * hist[t]
        m_b = sum_b / w_b
        m_f = (sum_total - sum_b) / w_f
        var_between = w_b * w_f * (m_b - m_f) ** 2
        if var_between > max_var:
            max_var = var_between
            threshold = t
    return int(threshold)


def connected_components(binary: np.ndarray, min_size: int = 6, max_size: int = 1200) -> int:
    h, w = binary.shape
    visited = np.zeros((h, w), dtype=np.uint8)
    count = 0
    for y in range(h):
        for x in range(w):
            if binary[y, x] == 0 or visited[y, x]:
                continue
            stack = [(y, x)]
            visited[y, x] = 1
            size = 0
            minx = maxx = x
            miny = maxy = y
            while stack:
                cy, cx = stack.pop()
                size += 1
                minx = min(minx, cx)
                maxx = max(maxx, cx)
                miny = min(miny, cy)
                maxy = max(maxy, cy)
                for ny in (cy - 1, cy, cy + 1):
                    if ny < 0 or ny >= h:
                        continue
                    for nx in (cx - 1, cx, cx + 1):
                        if nx < 0 or nx >= w:
                            continue
                        if binary[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = 1
                            stack.append((ny, nx))
            bw = maxx - minx + 1
            bh = maxy - miny + 1
            aspect = bw / max(1, bh)
            if min_size <= size <= max_size and 0.15 <= aspect <= 15:
                count += 1
    return count


def line_band_count(binary_text: np.ndarray) -> int:
    proj = binary_text.mean(axis=1)
    thr = max(float(np.percentile(proj, 70)), 0.008)
    active = proj > thr
    bands = 0
    in_band = False
    run = 0
    for v in active:
        if v:
            run += 1
            in_band = True
        else:
            if in_band and run >= 2:
                bands += 1
            in_band = False
            run = 0
    if in_band and run >= 2:
        bands += 1
    return bands


def resize_gray(gray: np.ndarray, target_w: int = 1024) -> np.ndarray:
    h, w = gray.shape
    if w <= target_w:
        return gray
    scale = target_w / float(w)
    new_h = max(1, int(round(h * scale)))
    return cv2.resize(gray, (target_w, new_h), interpolation=cv2.INTER_LINEAR)


def structural_features(path: Path) -> Dict[str, float]:
    with Image.open(path) as im:
        rgb = im.convert("RGB")
    arr = np.asarray(rgb)
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    gray = resize_gray(gray, target_w=1024)
    e = sobel_edges(gray.astype(np.float32))
    edge_thr = float(np.percentile(e, 80))
    edge_mask = e > edge_thr
    edge_density = float(edge_mask.mean())
    t = otsu_threshold(gray)
    dark = gray < t
    text_pixel_ratio = float(dark.mean())
    text_like = np.logical_and(dark, edge_mask)
    bands = line_band_count(text_like)
    comps = connected_components(text_like.astype(np.uint8), min_size=5, max_size=1000)
    ent = entropy_u8(gray)
    return {
        "edge_density": edge_density,
        "text_pixel_ratio": text_pixel_ratio,
        "line_band_count": float(bands),
        "component_count": float(comps),
        "entropy": ent,
    }


def ocr_features(path: Path) -> Dict[str, float]:
    with Image.open(path) as im:
        rgb = im.convert("RGB")
    arr = np.asarray(rgb)
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    gray = resize_gray(gray, target_w=1024)
    blur = cv2.GaussianBlur(gray, (3, 3), 0)
    thr = cv2.adaptiveThreshold(blur, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 15, 10)
    try:
        raw_text = pytesseract.image_to_string(thr, config=OCR_CONFIG, lang="eng")
        data = pytesseract.image_to_data(thr, output_type=pytesseract.Output.DICT, config=OCR_CONFIG, lang="eng")
    except pytesseract.TesseractError as exc:
        raw_text = ""
        data = {"text": [], "conf": []}
    words = [w.strip() for w in data.get("text", []) if w and w.strip()]
    confs = []
    for c in data.get("conf", []):
        try:
            confs.append(int(float(c)))
        except Exception:
            continue
    text_len = len(raw_text.strip())
    word_count = len(words)
    line_count = len([ln for ln in raw_text.splitlines() if ln.strip()])
    keyword_count = sum(1 for w in words if any(k in w.lower() for k in RECEIPT_KEYWORDS))
    numeric_tokens = sum(1 for w in words if re.search(r"\d", w))
    currency_tokens = sum(1 for w in words if re.search(r"[₱$]|php|peso", w.lower()))
    avg_conf = float(statistics.mean(confs)) if confs else 0.0
    return {
        "ocr_text_len": float(text_len),
        "ocr_word_count": float(word_count),
        "ocr_line_count": float(line_count),
        "ocr_mean_conf": avg_conf,
        "ocr_keyword_count": float(keyword_count),
        "ocr_numeric_ratio": float(numeric_tokens / word_count) if word_count else 0.0,
        "ocr_currency_count": float(currency_tokens),
    }


def make_ranges(values: List[float]) -> Dict[str, float]:
    arr = np.array(values, dtype=np.float64)
    if arr.size == 0:
        return {"p5": 0.0, "p10": 0.0, "p25": 0.0, "p50": 0.0, "p75": 0.0, "p90": 0.0, "p95": 0.0}
    return {
        "p5": float(np.percentile(arr, 5)),
        "p10": float(np.percentile(arr, 10)),
        "p25": float(np.percentile(arr, 25)),
        "p50": float(np.percentile(arr, 50)),
        "p75": float(np.percentile(arr, 75)),
        "p90": float(np.percentile(arr, 90)),
        "p95": float(np.percentile(arr, 95)),
    }


def compute_baseline(paths: List[Path]) -> Tuple[List[Dict[str, float]], Dict[str, Dict[str, float]]]:
    rows = []
    for path in paths:
        struct = structural_features(path)
        ocr = ocr_features(path)
        rows.append({**struct, **ocr})
    summary: Dict[str, Dict[str, float]] = {}
    for feature in STRUCT_FEATURES + OCR_FEATURES:
        values = [row[feature] for row in rows]
        summary[feature] = make_ranges(values)
    return rows, summary


def compare_to_baseline(value: float, baseline: Dict[str, float]) -> Tuple[bool, bool]:
    below = value < baseline["p5"]
    above = value > baseline["p95"]
    return below, above


def classify_image(struct: Dict[str, float], ocr: Dict[str, float], baseline: Dict[str, Dict[str, float]]) -> Tuple[str, str]:
    reasons: List[str] = []
    outliers = []
    for feature in STRUCT_FEATURES:
        below, above = compare_to_baseline(struct[feature], baseline[feature])
        if below or above:
            outliers.append(feature)
            reasons.append(f"struct_{feature}_{'low' if below else 'high'}")
    ocr_reasons: List[str] = []
    if ocr["ocr_text_len"] < baseline["ocr_text_len"]["p10"]:
        ocr_reasons.append("ocr_text_len_low")
    if ocr["ocr_mean_conf"] < baseline["ocr_mean_conf"]["p10"]:
        ocr_reasons.append("ocr_mean_conf_low")
    if ocr["ocr_line_count"] < baseline["ocr_line_count"]["p10"]:
        ocr_reasons.append("ocr_line_count_low")
    if ocr["ocr_keyword_count"] == 0:
        ocr_reasons.append("ocr_no_receipt_keyword")
    if ocr["ocr_numeric_ratio"] < 0.2:
        ocr_reasons.append("ocr_few_numeric_tokens")
    if ocr["ocr_mean_conf"] < 20:
        ocr_reasons.append("ocr_confidence_very_low")
    if ocr["ocr_text_len"] < 30:
        ocr_reasons.append("ocr_text_very_short")
    if ocr["ocr_line_count"] <= 1:
        ocr_reasons.append("ocr_one_line_or_empty")

    reasons.extend(ocr_reasons)
    strong_struct = len(outliers) == 0
    moderate_struct = len(outliers) <= 2
    weak_struct = len(outliers) >= 3
    ocr_good = (
        ocr["ocr_text_len"] >= baseline["ocr_text_len"]["p25"]
        and ocr["ocr_mean_conf"] >= baseline["ocr_mean_conf"]["p25"]
        and (ocr["ocr_keyword_count"] >= 1 or ocr["ocr_line_count"] >= 4)
    )
    ocr_bad = (
        ocr["ocr_text_len"] < baseline["ocr_text_len"]["p10"]
        or ocr["ocr_mean_conf"] < baseline["ocr_mean_conf"]["p10"]
        or ocr["ocr_line_count"] < baseline["ocr_line_count"]["p10"]
        or ocr["ocr_keyword_count"] == 0 and ocr["ocr_numeric_ratio"] < 0.18
    )
    if strong_struct and ocr_good:
        return "pass", ";".join(reasons or ["strong_struct_and_ocr"])
    if weak_struct or ocr_bad:
        return "fail", ";".join(reasons or ["weak_struct_or_ocr"])
    return "ambiguous", ";".join(reasons or ["moderate_struct_or_ocr"])


def gather_image_paths(root: Path, folders: List[Tuple[str, str]]) -> List[Tuple[Path, str]]:
    result: List[Tuple[Path, str]] = []
    for folder_name, platform in folders:
        folder = root / folder_name
        if not folder.exists():
            continue
        for path in sorted(folder.iterdir()):
            if path.is_file() and path.suffix.lower() in {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}:
                result.append((path, platform))
    return result


def write_csv(rows: List[ReviewRow], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([
            "relative_path",
            "platform",
            "width",
            "height",
            "aspect",
            *STRUCT_FEATURES,
            *OCR_FEATURES,
            "category",
            "reason",
        ])
        for row in rows:
            writer.writerow([
                row.relative_path,
                row.platform,
                row.width,
                row.height,
                f"{row.aspect:.6f}",
                *[f"{row.structural[f]:.6f}" for f in STRUCT_FEATURES],
                *[f"{row.ocr[f]:.6f}" for f in OCR_FEATURES],
                row.category,
                row.reasons,
            ])


def write_json(data: Dict, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def summarize_baseline(baseline: Dict[str, Dict[str, float]]) -> Dict[str, Dict[str, float]]:
    return baseline


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset = root / "dataset"
    out_dir = root / "artifacts" / "ai_fraud_audit" / "ocr_triage"
    existing_fraud_folders = [
        ("AndroidFraudulent", "android"),
        ("iOSFraudulent", "ios"),
    ]
    new_fraud_folders = [
        ("AndroidAIFraudulent", "android"),
        ("iOSAIFraudulent", "ios"),
    ]
    existing_paths = gather_image_paths(dataset, existing_fraud_folders)
    new_paths = gather_image_paths(dataset, new_fraud_folders)
    print(f"Existing fraud images: {len(existing_paths)}")
    print(f"Incoming candidate images: {len(new_paths)}")
    if not TESSERACT_PATH.exists():
        raise FileNotFoundError(f"Tesseract executable not found at {TESSERACT_PATH}")
    _, baseline = compute_baseline([path for path, _ in existing_paths])
    baseline_path = out_dir / "baseline_fraud_percentiles.json"
    write_json(baseline, baseline_path)
    rows: List[ReviewRow] = []
    counts = {"pass": 0, "fail": 0, "ambiguous": 0}
    for path, platform in new_paths:
        with Image.open(path) as im:
            width, height = im.size
        struct = structural_features(path)
        ocr = ocr_features(path)
        category, reason = classify_image(struct, ocr, baseline)
        row = ReviewRow(
            relative_path=str(path.relative_to(root)).replace("\\", "/"),
            platform=platform,
            width=width,
            height=height,
            aspect=float(width / height) if height else 0.0,
            structural=struct,
            ocr=ocr,
            category=category,
            reasons=reason,
        )
        rows.append(row)
        counts[category] += 1
    rows_sorted = sorted(rows, key=lambda r: (r.category, -r.ocr["ocr_text_len"], -r.ocr["ocr_mean_conf"], r.relative_path))
    write_csv(rows_sorted, out_dir / "ocr_triage_results.csv")
    write_json(
        {
            "total": len(rows_sorted),
            "pass": counts["pass"],
            "fail": counts["fail"],
            "ambiguous": counts["ambiguous"],
            "pass_android": sum(1 for r in rows_sorted if r.category == "pass" and r.platform == "android"),
            "pass_ios": sum(1 for r in rows_sorted if r.category == "pass" and r.platform == "ios"),
            "fail_android": sum(1 for r in rows_sorted if r.category == "fail" and r.platform == "android"),
            "fail_ios": sum(1 for r in rows_sorted if r.category == "fail" and r.platform == "ios"),
            "ambiguous_android": sum(1 for r in rows_sorted if r.category == "ambiguous" and r.platform == "android"),
            "ambiguous_ios": sum(1 for r in rows_sorted if r.category == "ambiguous" and r.platform == "ios"),
            "rules": {
                "structural_pass": "no structural feature outside 5-95 percentile",
                "ocr_pass": "ocr_text_len >= 25th percentile, ocr_mean_conf >= 25th percentile, and receipt keyword or >=4 lines",
                "fail": ">=3 structural outliers or OCR strongly low",
                "ambiguous": "everything else",
            },
        },
        out_dir / "ocr_triage_summary.json",
    )
    print(json.dumps({"total": len(rows_sorted), **counts}, indent=2))
    print("Results written to:", out_dir)


if __name__ == "__main__":
    main()
