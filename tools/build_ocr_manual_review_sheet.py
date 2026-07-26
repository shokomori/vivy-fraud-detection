from __future__ import annotations

import csv
from pathlib import Path
from typing import List

from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    src_csv = root / 'artifacts' / 'ai_fraud_audit' / 'ocr_triage' / 'ocr_triage_results.csv'
    out_csv = root / 'artifacts' / 'ai_fraud_audit' / 'ocr_triage' / 'manual_review_priority.csv'
    out_img = root / 'artifacts' / 'ai_fraud_audit' / 'ocr_triage' / 'manual_review_priority_20.jpg'

    rows: List[dict] = []
    with src_csv.open(encoding='utf-8') as f:
        for row in csv.DictReader(f):
            if row['category'] in {'ambiguous', 'fail'}:
                rows.append(row)

    rows.sort(
        key=lambda r: (
            0 if r['category'] == 'fail' else 1,
            float(r['ocr_mean_conf']),
            int(float(r['ocr_text_len'])),
            int(float(r['ocr_line_count'])),
        )
    )
    pick = rows[:20]

    with out_csv.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(pick[0].keys()) if pick else [])
        if pick:
            writer.writeheader()
            writer.writerows(pick)

    if not pick:
        return

    cols = 5
    tw, th = 230, 230
    label_h = 100
    pad = 12
    title_h = 64
    rcount = (len(pick) + cols - 1) // cols
    canvas = Image.new('RGB', (pad + cols * (tw + pad), title_h + pad + rcount * (th + label_h + pad)), (245, 248, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    draw.text((pad, 18), 'OCR-based manual review priority (ambiguous + fail top 20)', fill=(20, 35, 70), font=font)

    for i, row in enumerate(pick):
        rr = i // cols
        cc = i % cols
        x = pad + cc * (tw + pad)
        y = title_h + pad + rr * (th + label_h + pad)

        img_path = root / row['relative_path']
        with Image.open(img_path) as im:
            rgb = im.convert('RGB')
            rgb.thumbnail((tw, th), Image.Resampling.LANCZOS)
            tile = Image.new('RGB', (tw, th), (228, 233, 243))
            ox = (tw - rgb.width) // 2
            oy = (th - rgb.height) // 2
            tile.paste(rgb, (ox, oy))
        canvas.paste(tile, (x, y))
        draw.rectangle([x, y, x + tw - 1, y + th - 1], outline=(170, 180, 205), width=1)

        name = Path(row['relative_path']).name
        draw.text((x, y + th + 4), name[:30], fill=(35, 45, 72), font=font)
        draw.text((x, y + th + 22), f"{row['category']} conf={float(row['ocr_mean_conf']):.1f} txt={int(float(row['ocr_text_len']))}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 40), f"lines={int(float(row['ocr_line_count']))} words={int(float(row['ocr_word_count']))} kw={int(float(row['ocr_keyword_count']))}", fill=(60, 75, 105), font=font)
        draw.text((x, y + th + 58), row['reason'][:38], fill=(100, 55, 55), font=font)

    canvas.save(out_img, quality=92)
    print(out_img)
    print(out_csv)


if __name__ == '__main__':
    main()
