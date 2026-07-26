from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np


TARGETS = [
    "dataset/iOSGenuine/gI_388.jpg",
    "dataset/iOSGenuine/gI_390.jpg",
    "dataset/iOSGenuine/gI_391.jpg",
]


def image_stats(img_bgr: np.ndarray) -> dict[str, float]:
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    lap_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    mean = float(gray.mean())
    std = float(gray.std())
    p10 = float(np.percentile(gray, 10))
    p90 = float(np.percentile(gray, 90))
    return {
        "width": float(w),
        "height": float(h),
        "mean_luma": mean,
        "std_luma": std,
        "p10_luma": p10,
        "p90_luma": p90,
        "laplacian_var_focus": lap_var,
    }


def make_contact_sheet(root: Path, out_path: Path) -> None:
    tiles = []
    for rel in TARGETS:
        img = cv2.imread(str(root / rel))
        if img is None:
            raise FileNotFoundError(rel)
        tile = cv2.resize(img, (480, 900), interpolation=cv2.INTER_AREA)
        cv2.rectangle(tile, (0, 0), (479, 80), (0, 0, 0), thickness=-1)
        cv2.putText(
            tile,
            Path(rel).name,
            (14, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            1.0,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )
        tiles.append(tile)

    sheet = np.concatenate(tiles, axis=1)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(out_path), sheet)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_dir = root / "artifacts" / "analysis"
    out_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for rel in TARGETS:
        img = cv2.imread(str(root / rel))
        if img is None:
            continue
        stats = image_stats(img)
        stats["path"] = rel
        rows.append(stats)

    stats_path = out_dir / "ios_fp_visual_stats.json"
    with stats_path.open("w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)

    sheet_path = out_dir / "ios_fp_388_390_391_sheet.png"
    make_contact_sheet(root, sheet_path)

    print(f"Saved stats: {stats_path}")
    print(f"Saved contact sheet: {sheet_path}")


if __name__ == "__main__":
    main()
