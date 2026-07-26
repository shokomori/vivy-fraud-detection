from __future__ import annotations

import csv
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}


@dataclass
class TriageRow:
    relative_path: str
    platform: str
    width: int
    height: int
    aspect: float
    edge_density: float
    text_pixel_ratio: float
    line_band_count: int
    component_count: int
    entropy: float
    confidence: float
    triage: str
    reason: str


def entropy_u8(gray: np.ndarray) -> float:
    hist, _ = np.histogram(gray, bins=256, range=(0, 256))
    p = hist.astype(np.float64)
    p_sum = p.sum()
    if p_sum <= 0:
        return 0.0
    p /= p_sum
    p = p[p > 0]
    return float(-(p * np.log2(p)).sum())


def sobel_edges(gray: np.ndarray) -> np.ndarray:
    # simple convolution via numpy differences for portability
    gx = np.zeros_like(gray, dtype=np.float32)
    gy = np.zeros_like(gray, dtype=np.float32)

    gx[:, 1:-1] = (gray[:, 2:] - gray[:, :-2]) * 0.5
    gy[1:-1, :] = (gray[2:, :] - gray[:-2, :]) * 0.5

    mag = np.sqrt(gx * gx + gy * gy)
    return mag


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
                if cx < minx:
                    minx = cx
                if cx > maxx:
                    maxx = cx
                if cy < miny:
                    miny = cy
                if cy > maxy:
                    maxy = cy

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
    # Count horizontal text-rich bands to approximate receipt line structure.
    proj = binary_text.mean(axis=1)
    # Robust threshold tied to distribution.
    thr = max(float(np.percentile(proj, 70)), 0.008)
    active = proj > thr

    bands = 0
    in_band = False
    run = 0
    for v in active:
        if v:
            run += 1
            if not in_band:
                in_band = True
        else:
            if in_band and run >= 2:
                bands += 1
            in_band = False
            run = 0
    if in_band and run >= 2:
        bands += 1
    return bands


def analyze_image(path: Path) -> Tuple[Dict[str, float], str]:
    with Image.open(path) as im:
        rgb = im.convert("RGB")
    arr = np.asarray(rgb)

    # Luma conversion
    gray = (0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]).astype(np.uint8)
    h, w = gray.shape

    # Resize to manageable width while keeping morphology cues.
    target_w = 512
    if w > target_w:
        scale = target_w / w
        target_h = max(1, int(h * scale))
        small = Image.fromarray(gray).resize((target_w, target_h), Image.Resampling.BILINEAR)
        gray_s = np.asarray(small)
    else:
        gray_s = gray

    g_h, g_w = gray_s.shape

    e = sobel_edges(gray_s.astype(np.float32))
    edge_thr = np.percentile(e, 80)
    edge_mask = e > edge_thr
    edge_density = float(edge_mask.mean())

    t = otsu_threshold(gray_s)
    # text-like dark pixels after threshold
    dark = gray_s < t
    text_pixel_ratio = float(dark.mean())

    # remove huge dark areas by intersecting with edges
    text_like = np.logical_and(dark, edge_mask)

    bands = line_band_count(text_like)
    comps = connected_components(text_like.astype(np.uint8), min_size=5, max_size=1000)
    ent = entropy_u8(gray_s)

    # Objective confidence score using calibrated structural priors.
    score = 0.0
    reasons = []

    # Expected ranges for receipt-like captures (broad to avoid over-rejecting).
    if 0.05 <= edge_density <= 0.30:
        score += 0.20
    else:
        reasons.append("edge_density_outlier")

    if 0.02 <= text_pixel_ratio <= 0.45:
        score += 0.20
    else:
        reasons.append("text_pixel_ratio_outlier")

    if bands >= 10:
        score += 0.25
    elif bands >= 6:
        score += 0.15
    else:
        reasons.append("few_text_line_bands")

    if comps >= 80:
        score += 0.25
    elif comps >= 40:
        score += 0.15
    else:
        reasons.append("few_text_components")

    if 3.5 <= ent <= 7.8:
        score += 0.10
    else:
        reasons.append("entropy_outlier")

    if not reasons:
        reason = "strong_receipt_structure"
    else:
        reason = ";".join(reasons)

    return (
        {
            "edge_density": edge_density,
            "text_pixel_ratio": text_pixel_ratio,
            "line_band_count": float(bands),
            "component_count": float(comps),
            "entropy": ent,
            "confidence": score,
            "width": float(w),
            "height": float(h),
            "aspect": float(w / h) if h else 0.0,
        },
        reason,
    )


def classify(score: float, bands: int, comps: int) -> str:
    # Conservative: only clearly good and clearly bad auto-decided.
    if score >= 0.75 and bands >= 10 and comps >= 80:
        return "pass"
    if score <= 0.35 or bands <= 3 or comps <= 20:
        return "fail"
    return "ambiguous"


def make_sheet(rows: List[TriageRow], root: Path, out_path: Path, title: str, cols: int = 5) -> None:
    if not rows:
        return
    tw, th = 230, 230
    label_h = 90
    pad = 12
    title_h = 60
    n = len(rows)
    rcount = (n + cols - 1) // cols

    sheet_w = pad + cols * (tw + pad)
    sheet_h = title_h + pad + rcount * (th + label_h + pad)

    canvas = Image.new("RGB", (sheet_w, sheet_h), (246, 248, 253))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()

    draw.text((pad, 18), title, fill=(20, 35, 70), font=font)

    for i, row in enumerate(rows):
        rr = i // cols
        cc = i % cols
        x = pad + cc * (tw + pad)
        y = title_h + pad + rr * (th + label_h + pad)

        p = root / row.relative_path
        try:
            with Image.open(p) as im:
                rgb = im.convert("RGB")
                rgb.thumbnail((tw, th), Image.Resampling.LANCZOS)
                tile = Image.new("RGB", (tw, th), (228, 233, 243))
                ox = (tw - rgb.width) // 2
                oy = (th - rgb.height) // 2
                tile.paste(rgb, (ox, oy))
        except Exception:
            tile = Image.new("RGB", (tw, th), (255, 220, 220))

        canvas.paste(tile, (x, y))
        draw.rectangle([x, y, x + tw - 1, y + th - 1], outline=(170, 180, 205), width=1)

        draw.text((x, y + th + 4), Path(row.relative_path).name[:30], fill=(35, 45, 72), font=font)
        draw.text((x, y + th + 22), f"{row.width}x{row.height} ar={row.aspect:.3f}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 40), f"score={row.confidence:.2f} bands={row.line_band_count} comps={row.component_count}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 58), row.reason[:38], fill=(100, 55, 55), font=font)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, quality=92)


def write_csv(rows: List[TriageRow], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([
            "relative_path",
            "platform",
            "width",
            "height",
            "aspect",
            "edge_density",
            "text_pixel_ratio",
            "line_band_count",
            "component_count",
            "entropy",
            "confidence",
            "triage",
            "reason",
        ])
        for r in rows:
            w.writerow([
                r.relative_path,
                r.platform,
                r.width,
                r.height,
                f"{r.aspect:.6f}",
                f"{r.edge_density:.6f}",
                f"{r.text_pixel_ratio:.6f}",
                r.line_band_count,
                r.component_count,
                f"{r.entropy:.6f}",
                f"{r.confidence:.3f}",
                r.triage,
                r.reason,
            ])


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset = root / "dataset"
    out_dir = root / "artifacts" / "ai_fraud_audit" / "structure_triage"

    candidates = []
    for folder, platform in [
        (dataset / "AndroidAIFraudulent", "android"),
        (dataset / "iOSAIFraudulent", "ios"),
    ]:
        if not folder.exists():
            continue
        for p in sorted(folder.iterdir()):
            if p.is_file() and p.suffix.lower() in ALLOWED_EXTS:
                candidates.append((p, platform))

    rows: List[TriageRow] = []
    for p, platform in candidates:
        feat, reason = analyze_image(p)
        tri = classify(feat["confidence"], int(feat["line_band_count"]), int(feat["component_count"]))
        rows.append(
            TriageRow(
                relative_path=str(p.relative_to(root)).replace("\\", "/"),
                platform=platform,
                width=int(feat["width"]),
                height=int(feat["height"]),
                aspect=float(feat["aspect"]),
                edge_density=float(feat["edge_density"]),
                text_pixel_ratio=float(feat["text_pixel_ratio"]),
                line_band_count=int(feat["line_band_count"]),
                component_count=int(feat["component_count"]),
                entropy=float(feat["entropy"]),
                confidence=float(feat["confidence"]),
                triage=tri,
                reason=reason,
            )
        )

    rows_sorted = sorted(rows, key=lambda r: (r.triage, -r.confidence, r.relative_path))

    write_csv(rows_sorted, out_dir / "triage_results.csv")

    passed = [r for r in rows_sorted if r.triage == "pass"]
    failed = [r for r in rows_sorted if r.triage == "fail"]
    ambiguous = [r for r in rows_sorted if r.triage == "ambiguous"]

    write_csv(passed, out_dir / "triage_pass.csv")
    write_csv(failed, out_dir / "triage_fail.csv")
    write_csv(ambiguous, out_dir / "triage_ambiguous.csv")

    summary = {
        "total": len(rows_sorted),
        "pass": len(passed),
        "fail": len(failed),
        "ambiguous": len(ambiguous),
        "pass_android": sum(1 for r in passed if r.platform == "android"),
        "pass_ios": sum(1 for r in passed if r.platform == "ios"),
        "fail_android": sum(1 for r in failed if r.platform == "android"),
        "fail_ios": sum(1 for r in failed if r.platform == "ios"),
        "ambiguous_android": sum(1 for r in ambiguous if r.platform == "android"),
        "ambiguous_ios": sum(1 for r in ambiguous if r.platform == "ios"),
        "method": "structure_features_no_ocr",
        "features": [
            "edge_density",
            "text_pixel_ratio",
            "line_band_count",
            "component_count",
            "entropy",
        ],
        "thresholds": {
            "pass": "score>=0.75 and bands>=10 and components>=80",
            "fail": "score<=0.35 or bands<=3 or components<=20",
        },
    }

    with (out_dir / "triage_summary.json").open("w", encoding="utf-8") as f:
        import json

        json.dump(summary, f, indent=2)

    # Visuals for fast spot-check.
    make_sheet(failed, root, out_dir / "triage_fail_sheet.jpg", "Auto-fail candidates (structure check)", cols=4)
    make_sheet(ambiguous[:36], root, out_dir / "triage_ambiguous_sheet_top36.jpg", "Ambiguous candidates (first 36)", cols=6)
    make_sheet(passed[:24], root, out_dir / "triage_pass_sheet_top24.jpg", "Pass examples (first 24)", cols=6)

    print(f"Triage complete: {out_dir / 'triage_summary.json'}")


if __name__ == "__main__":
    main()
