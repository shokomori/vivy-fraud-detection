from __future__ import annotations

import csv
from pathlib import Path
from typing import List

from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    triage_csv = root / "artifacts" / "ai_fraud_audit" / "structure_triage" / "triage_results.csv"
    out_img = root / "artifacts" / "ai_fraud_audit" / "structure_triage" / "triage_low_confidence_15.jpg"
    out_csv = root / "artifacts" / "ai_fraud_audit" / "structure_triage" / "triage_low_confidence_15.csv"

    rows: List[dict] = []
    with triage_csv.open(encoding="utf-8") as f:
        for r in csv.DictReader(f):
            rows.append(r)

    rows.sort(key=lambda r: (float(r["confidence"]), int(r["line_band_count"]), int(r["component_count"])))
    pick = rows[:15]

    with out_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(pick[0].keys()))
        w.writeheader()
        w.writerows(pick)

    cols = 5
    tw, th = 230, 230
    label_h = 90
    pad = 12
    title_h = 64
    n = len(pick)
    rcount = (n + cols - 1) // cols

    canvas = Image.new("RGB", (pad + cols * (tw + pad), title_h + pad + rcount * (th + label_h + pad)), (245, 248, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    draw.text((pad, 18), "Lowest-confidence 15 (for spot-check)", fill=(20, 35, 70), font=font)

    for i, r in enumerate(pick):
        rr = i // cols
        cc = i % cols
        x = pad + cc * (tw + pad)
        y = title_h + pad + rr * (th + label_h + pad)

        img_path = root / r["relative_path"]
        with Image.open(img_path) as im:
            im = im.convert("RGB")
            im.thumbnail((tw, th), Image.Resampling.LANCZOS)
            tile = Image.new("RGB", (tw, th), (228, 233, 243))
            ox = (tw - im.width) // 2
            oy = (th - im.height) // 2
            tile.paste(im, (ox, oy))

        canvas.paste(tile, (x, y))
        draw.rectangle([x, y, x + tw - 1, y + th - 1], outline=(170, 180, 205), width=1)

        name = Path(r["relative_path"]).name
        draw.text((x, y + th + 4), name[:30], fill=(35, 45, 72), font=font)
        draw.text((x, y + th + 22), f"score={float(r['confidence']):.2f} bands={r['line_band_count']} comps={r['component_count']}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 40), f"{r['width']}x{r['height']} ar={float(r['aspect']):.3f}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 58), r["reason"][:40], fill=(100, 55, 55), font=font)

    canvas.save(out_img, quality=92)
    print(out_img)
    print(out_csv)


if __name__ == "__main__":
    main()
