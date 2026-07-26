from __future__ import annotations

import csv
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFont

ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}
LOW_W = 540
LOW_H = 960


@dataclass
class ImgInfo:
    path: Path
    rel: str
    platform: str
    width: int
    height: int
    aspect: float
    reason: str = ""


def median(vals: List[float]) -> float:
    vals = sorted(vals)
    n = len(vals)
    if n == 0:
        return 0.0
    m = n // 2
    if n % 2:
        return float(vals[m])
    return float((vals[m - 1] + vals[m]) / 2.0)


def collect_folder(folder: Path, root: Path) -> List[ImgInfo]:
    items: List[ImgInfo] = []
    if not folder.exists():
        return items
    for p in sorted(folder.iterdir()):
        if not p.is_file() or p.suffix.lower() not in ALLOWED_EXTS:
            continue
        try:
            with Image.open(p) as im:
                w, h = im.size
        except Exception:
            continue
        rel = str(p.relative_to(root)).replace("\\", "/")
        platform = "android" if "android" in p.parts[-2].lower() else ("ios" if "ios" in p.parts[-2].lower() else "unknown")
        items.append(ImgInfo(path=p, rel=rel, platform=platform, width=w, height=h, aspect=(w / h) if h else 0.0))
    return items


def stats(items: List[ImgInfo]) -> Dict[str, float]:
    if not items:
        return {
            "count": 0,
            "width_min": 0,
            "width_median": 0,
            "width_max": 0,
            "height_min": 0,
            "height_median": 0,
            "height_max": 0,
            "aspect_min": 0,
            "aspect_median": 0,
            "aspect_max": 0,
            "low_resolution_count": 0,
            "low_resolution_pct": 0,
        }

    ws = [i.width for i in items]
    hs = [i.height for i in items]
    ars = [i.aspect for i in items]
    low = [i for i in items if i.width < LOW_W or i.height < LOW_H]

    return {
        "count": len(items),
        "width_min": min(ws),
        "width_median": median([float(v) for v in ws]),
        "width_max": max(ws),
        "height_min": min(hs),
        "height_median": median([float(v) for v in hs]),
        "height_max": max(hs),
        "aspect_min": min(ars),
        "aspect_median": median(ars),
        "aspect_max": max(ars),
        "low_resolution_count": len(low),
        "low_resolution_pct": (len(low) / len(items)) * 100.0,
    }


def load_borderline_csv(path: Path, root: Path) -> Dict[str, str]:
    reasons: Dict[str, str] = {}
    if not path.exists():
        return reasons
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            reasons[row["target_rel"]] = row["reason"]
    return reasons


def make_contact_sheet(items: List[ImgInfo], out_path: Path, title: str, cols: int = 10, thumb_size: Tuple[int, int] = (180, 180)) -> None:
    if not items:
        return

    tw, th = thumb_size
    label_h = 48
    pad = 12
    title_h = 60
    rows = (len(items) + cols - 1) // cols

    sheet_w = pad + cols * (tw + pad)
    sheet_h = title_h + pad + rows * (th + label_h + pad)

    canvas = Image.new("RGB", (sheet_w, sheet_h), (245, 248, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()

    draw.text((pad, 18), title, fill=(24, 38, 68), font=font)

    for idx, item in enumerate(items):
        r = idx // cols
        c = idx % cols
        x = pad + c * (tw + pad)
        y = title_h + pad + r * (th + label_h + pad)

        try:
            with Image.open(item.path) as im:
                rgb = im.convert("RGB")
                rgb.thumbnail((tw, th), Image.Resampling.LANCZOS)
                tile = Image.new("RGB", (tw, th), (230, 235, 245))
                ox = (tw - rgb.width) // 2
                oy = (th - rgb.height) // 2
                tile.paste(rgb, (ox, oy))
        except Exception:
            tile = Image.new("RGB", (tw, th), (255, 220, 220))

        canvas.paste(tile, (x, y))
        draw.rectangle([x, y, x + tw - 1, y + th - 1], outline=(180, 190, 210), width=1)

        name = item.path.name
        line1 = name[:28]
        line2 = f"{item.width}x{item.height} ar={item.aspect:.3f}"
        draw.text((x, y + th + 4), line1, fill=(40, 52, 75), font=font)
        draw.text((x, y + th + 22), line2, fill=(70, 84, 110), font=font)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, quality=92)


def choose_representative_sample(items: List[ImgInfo], n: int = 20) -> List[ImgInfo]:
    if len(items) <= n:
        return items
    android = [i for i in items if i.platform == "android"]
    ios = [i for i in items if i.platform == "ios"]

    def pick_spread(group: List[ImgInfo], k: int) -> List[ImgInfo]:
        if not group:
            return []
        ordered = sorted(group, key=lambda x: (x.aspect, x.width * x.height))
        if len(ordered) <= k:
            return ordered
        out = []
        for j in range(k):
            idx = round(j * (len(ordered) - 1) / (k - 1)) if k > 1 else 0
            out.append(ordered[idx])
        # unique preserve order
        seen = set()
        unique = []
        for it in out:
            if it.rel in seen:
                continue
            seen.add(it.rel)
            unique.append(it)
        return unique

    ka = n // 2
    ki = n - ka
    sample = pick_spread(android, ka) + pick_spread(ios, ki)

    # backfill if duplicates reduced size
    if len(sample) < n:
        existing = {s.rel for s in sample}
        for it in sorted(items, key=lambda x: x.rel):
            if it.rel in existing:
                continue
            sample.append(it)
            existing.add(it.rel)
            if len(sample) == n:
                break

    return sample[:n]


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset = root / "dataset"
    audit_dir = root / "artifacts" / "ai_fraud_audit"

    incoming_android = collect_folder(dataset / "AndroidAIFraudulent", root)
    incoming_ios = collect_folder(dataset / "iOSAIFraudulent", root)

    old_android_fraud = collect_folder(dataset / "AndroidFraudulent", root)
    old_android_genuine = collect_folder(dataset / "AndroidGenuine", root)
    old_ios_fraud = collect_folder(dataset / "iOSFraudulent", root)
    old_ios_genuine = collect_folder(dataset / "iOSGenuine", root)

    comparison = {
        "low_resolution_rule": {"width_lt": LOW_W, "height_lt": LOW_H},
        "incoming_android": stats(incoming_android),
        "incoming_ios": stats(incoming_ios),
        "old_android_fraud": stats(old_android_fraud),
        "old_android_genuine": stats(old_android_genuine),
        "old_ios_fraud": stats(old_ios_fraud),
        "old_ios_genuine": stats(old_ios_genuine),
    }

    out_json = audit_dir / "resolution_aspect_comparison.json"
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(comparison, indent=2), encoding="utf-8")

    all_incoming = sorted(incoming_android + incoming_ios, key=lambda i: i.rel)
    sample20 = choose_representative_sample(all_incoming, n=20)

    make_contact_sheet(
        all_incoming,
        audit_dir / "contact_sheet_all_incoming_79.jpg",
        title="AI Fraud Incoming Set (current ingested files): 79 images",
        cols=10,
        thumb_size=(170, 170),
    )

    make_contact_sheet(
        sample20,
        audit_dir / "contact_sheet_representative_20.jpg",
        title="AI Fraud Representative Sample: 20 images (spread by platform/aspect/size)",
        cols=5,
        thumb_size=(220, 220),
    )

    sample_csv = audit_dir / "representative_sample_20.csv"
    with sample_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["relative_path", "platform", "width", "height", "aspect"])
        for i in sample20:
            w.writerow([i.rel, i.platform, i.width, i.height, f"{i.aspect:.6f}"])

    print(f"Wrote comparison stats: {out_json}")
    print(f"Wrote all-image contact sheet: {audit_dir / 'contact_sheet_all_incoming_79.jpg'}")
    print(f"Wrote representative sample sheet: {audit_dir / 'contact_sheet_representative_20.jpg'}")
    print(f"Wrote representative sample CSV: {sample_csv}")


if __name__ == "__main__":
    main()
