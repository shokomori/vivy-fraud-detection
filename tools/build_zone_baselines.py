from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict

import cv2
import numpy as np
import pandas as pd

from image_pipeline import crop_receipt_roi


ZONE_LAYOUTS: dict[str, dict[str, tuple[float, float, float, float]]] = {
    "android-like": {
        "transaction_amount": (0.52, 0.16, 0.95, 0.32),
        "reference_number": (0.52, 0.34, 0.95, 0.48),
        "timestamp": (0.52, 0.50, 0.95, 0.63),
        "name_block": (0.08, 0.66, 0.95, 0.84),
    },
    "ios-like": {
        "transaction_amount": (0.50, 0.18, 0.94, 0.34),
        "reference_number": (0.50, 0.35, 0.94, 0.50),
        "timestamp": (0.50, 0.52, 0.94, 0.66),
        "name_block": (0.08, 0.67, 0.94, 0.86),
    },
}


@dataclass
class ZoneMetrics:
    laplacian_var: float
    edge_density: float
    spacing_cv: float
    alignment_std: float
    font_height_cv: float
    stroke_fill_ratio: float


def _safe_crop(gray: np.ndarray, bounds: tuple[float, float, float, float]) -> np.ndarray:
    h, w = gray.shape
    x0n, y0n, x1n, y1n = bounds
    x0 = max(0, min(w - 1, int(round(x0n * w))))
    y0 = max(0, min(h - 1, int(round(y0n * h))))
    x1 = max(x0 + 1, min(w, int(round(x1n * w))))
    y1 = max(y0 + 1, min(h, int(round(y1n * h))))
    return gray[y0:y1, x0:x1]


def _zone_metrics(zone_gray: np.ndarray) -> ZoneMetrics:
    lap = cv2.Laplacian(zone_gray, cv2.CV_64F)
    lap_var = float(lap.var())

    edges = cv2.Canny(zone_gray, 80, 180)
    edge_density = float(np.count_nonzero(edges) / max(1, zone_gray.size))

    _, bin_inv = cv2.threshold(
        zone_gray,
        0,
        255,
        cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU,
    )
    stroke_fill_ratio = float(np.count_nonzero(bin_inv) / max(1, zone_gray.size))

    num_labels, _, stats, centroids = cv2.connectedComponentsWithStats(bin_inv, connectivity=8)
    valid_indices: list[int] = []
    heights: list[float] = []
    center_y: list[float] = []
    center_x: list[float] = []
    for i in range(1, num_labels):
        area = int(stats[i, cv2.CC_STAT_AREA])
        width = float(stats[i, cv2.CC_STAT_WIDTH])
        height = float(stats[i, cv2.CC_STAT_HEIGHT])
        if area < 10 or width < 2 or height < 4:
            continue
        valid_indices.append(i)
        heights.append(height)
        center_y.append(float(centroids[i, 1]))
        center_x.append(float(centroids[i, 0]))

    if len(valid_indices) < 4:
        return ZoneMetrics(
            laplacian_var=lap_var,
            edge_density=edge_density,
            spacing_cv=0.0,
            alignment_std=0.0,
            font_height_cv=0.0,
            stroke_fill_ratio=stroke_fill_ratio,
        )

    center_x_sorted = np.sort(np.asarray(center_x, dtype=np.float64))
    gaps = np.diff(center_x_sorted)
    positive_gaps = gaps[gaps > 1.0]
    if positive_gaps.size < 2:
        spacing_cv = 0.0
    else:
        spacing_cv = float(positive_gaps.std() / max(positive_gaps.mean(), 1e-6))

    zone_h = max(1.0, float(zone_gray.shape[0]))
    alignment_std = float(np.std(np.asarray(center_y, dtype=np.float64)) / zone_h)

    heights_np = np.asarray(heights, dtype=np.float64)
    font_height_cv = float(heights_np.std() / max(heights_np.mean(), 1e-6))

    return ZoneMetrics(
        laplacian_var=lap_var,
        edge_density=edge_density,
        spacing_cv=spacing_cv,
        alignment_std=alignment_std,
        font_height_cv=font_height_cv,
        stroke_fill_ratio=stroke_fill_ratio,
    )


def _robust_stats(values: np.ndarray) -> dict[str, float]:
    if values.size == 0:
        return {
            "median": 0.0,
            "mad": 1e-6,
            "p05": 0.0,
            "p95": 0.0,
        }
    median = float(np.median(values))
    mad = float(np.median(np.abs(values - median)))
    if mad < 1e-6:
        mad = 1e-6
    return {
        "median": median,
        "mad": mad,
        "p05": float(np.percentile(values, 5)),
        "p95": float(np.percentile(values, 95)),
    }


def _template_family_for_row(class_folder: str) -> str:
    if class_folder.lower().startswith("android"):
        return "android-like"
    if class_folder.lower().startswith("ios"):
        return "ios-like"
    return "android-like"


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Build robust per-zone baselines from Stage3 TRAIN genuine split only."
        )
    )
    parser.add_argument(
        "--train-split-csv",
        default="artifacts/stage3/splits/train.csv",
        help="Stage3 train split CSV path.",
    )
    parser.add_argument(
        "--output-json",
        default="vivy_app/assets/config/zone_baselines.json",
        help="Output baseline JSON path.",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    train_split_csv = root / args.train_split_csv
    output_json = root / args.output_json

    if not train_split_csv.exists():
        raise FileNotFoundError(f"Train split CSV not found: {train_split_csv}")

    df = pd.read_csv(train_split_csv)
    required_cols = {"relative_path", "class_folder", "binary_label"}
    if not required_cols.issubset(df.columns):
        raise ValueError(f"Missing required columns in split CSV: {required_cols}")

    genuine_df = df[df["binary_label"] == "Genuine"].copy()
    if genuine_df.empty:
        raise ValueError("No genuine rows found in train split.")

    metric_store: dict[str, dict[str, dict[str, list[float]]]] = {}
    for family in list(ZONE_LAYOUTS.keys()) + ["generic"]:
        metric_store[family] = {}
        for zone in ZONE_LAYOUTS["android-like"].keys():
            metric_store[family][zone] = {
                "laplacian_var": [],
                "edge_density": [],
                "spacing_cv": [],
                "alignment_std": [],
                "font_height_cv": [],
                "stroke_fill_ratio": [],
            }

    used_count = 0
    for row in genuine_df.itertuples(index=False):
        rel_path = str(row.relative_path)
        image_path = root / rel_path
        if not image_path.exists():
            continue

        bgr = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if bgr is None:
            continue

        roi_bgr = crop_receipt_roi(bgr)
        if roi_bgr.size == 0:
            continue

        roi_gray = cv2.cvtColor(roi_bgr, cv2.COLOR_BGR2GRAY)
        family = _template_family_for_row(str(row.class_folder))
        zone_defs = ZONE_LAYOUTS[family]

        used_count += 1
        for zone_name, bounds in zone_defs.items():
            zone_gray = _safe_crop(roi_gray, bounds)
            metrics = _zone_metrics(zone_gray)
            metric_store[family][zone_name]["laplacian_var"].append(metrics.laplacian_var)
            metric_store[family][zone_name]["edge_density"].append(metrics.edge_density)
            metric_store[family][zone_name]["spacing_cv"].append(metrics.spacing_cv)
            metric_store[family][zone_name]["alignment_std"].append(metrics.alignment_std)
            metric_store[family][zone_name]["font_height_cv"].append(metrics.font_height_cv)
            metric_store[family][zone_name]["stroke_fill_ratio"].append(metrics.stroke_fill_ratio)

            for metric_name, value in (
                ("laplacian_var", metrics.laplacian_var),
                ("edge_density", metrics.edge_density),
                ("spacing_cv", metrics.spacing_cv),
                ("alignment_std", metrics.alignment_std),
                ("font_height_cv", metrics.font_height_cv),
                ("stroke_fill_ratio", metrics.stroke_fill_ratio),
            ):
                metric_store["generic"][zone_name][metric_name].append(value)

    if used_count < 100:
        raise RuntimeError(
            f"Too few genuine train images used for baseline: {used_count}."
        )

    stats_payload: dict[str, dict[str, dict[str, dict[str, float]]]] = {}
    for family, zones in metric_store.items():
        stats_payload[family] = {}
        for zone_name, metrics in zones.items():
            stats_payload[family][zone_name] = {}
            for metric_name, values in metrics.items():
                arr = np.asarray(values, dtype=np.float64)
                stats_payload[family][zone_name][metric_name] = _robust_stats(arr)

    payload = {
        "version": 1,
        "source": {
            "split_csv": str(train_split_csv),
            "split": "train",
            "label_filter": "Genuine",
            "images_used": used_count,
        },
        "zones": list(ZONE_LAYOUTS["android-like"].keys()),
        "families": list(stats_payload.keys()),
        "stats": stats_payload,
        "precision_bias": {
            "metric_z_threshold": 3.5,
            "zone_fail_metrics_min": 3,
            "zone_fail_metrics_min_with_severe": 2,
            "severe_metrics": ["laplacian_var", "spacing_cv", "alignment_std"],
            "template_confidence_min": 0.8,
        },
    }

    output_json.parent.mkdir(parents=True, exist_ok=True)
    with output_json.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

    print(json.dumps({
        "output": str(output_json),
        "images_used": used_count,
        "source_split": str(train_split_csv),
    }, indent=2))


if __name__ == "__main__":
    main()
