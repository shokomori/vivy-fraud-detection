from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np

from image_pipeline import preprocess_image


def preprocess_android_opencv_semantics_with_meta(image_path: Path) -> tuple[np.ndarray, dict[str, object]]:
    bgr = cv2.imread(str(image_path))
    if bgr is None:
        raise ValueError(f"Unable to read image: {image_path}")

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    kernel = np.ones((5, 5), np.uint8)
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel, iterations=2)

    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    h, w = gray.shape
    min_area = 0.12 * h * w
    best = None
    best_area = 0.0

    for c in contours:
        area = cv2.contourArea(c)
        if area < min_area:
            continue
        x, y, bw, bh = cv2.boundingRect(c)
        aspect = bw / max(float(bh), 1.0)
        if 0.25 <= aspect <= 3.5 and area > best_area:
            best = (x, y, bw, bh, area)
            best_area = area

    if best is None:
        roi = bgr
        roi_meta = {
            "geometry_pass": False,
            "reason": "no_valid_component",
            "crop_box_xyxy": [0, 0, w - 1, h - 1],
            "area_ratio": 0.0,
            "aspect_ratio": 0.0,
        }
    else:
        x, y, bw, bh, area = best
        pad_x = int(0.03 * bw)
        pad_y = int(0.03 * bh)
        x0 = max(x - pad_x, 0)
        y0 = max(y - pad_y, 0)
        x1 = min(x + bw + pad_x, w)
        y1 = min(y + bh + pad_y, h)
        roi = bgr[y0:y1, x0:x1]
        roi_meta = {
            "geometry_pass": True,
            "reason": "largest_valid_component",
            "crop_box_xyxy": [int(x0), int(y0), int(x1 - 1), int(y1 - 1)],
            "component_xywh": [int(x), int(y), int(bw), int(bh)],
            "component_area": float(area),
            "area_ratio": float(area / (h * w)),
            "aspect_ratio": float(bw / max(float(bh), 1.0)),
        }

    resized = cv2.resize(roi, (224, 224), interpolation=cv2.INTER_AREA)
    rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
    tensor = rgb.astype(np.float32) / 255.0

    return tensor, {
        "source_shape_hw": [int(h), int(w)],
        "roi_shape_hw": [int(roi.shape[0]), int(roi.shape[1])],
        **roi_meta,
    }


def arr_stats(arr: np.ndarray) -> dict[str, float]:
    return {
        "mean": float(arr.mean()),
        "std": float(arr.std()),
        "min": float(arr.min()),
        "max": float(arr.max()),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Byte-level tensor diff: Stage3 vs app semantics.")
    parser.add_argument("--image", required=True, help="Image path relative to repo or absolute")
    parser.add_argument(
        "--out-json",
        default="artifacts/debug_compare/gA_022_stage3_vs_app_semantics_bytelevel.json",
        help="Output report path",
    )
    parser.add_argument(
        "--out-dir",
        default="artifacts/debug_compare/gA_022_stage3_vs_app_semantics",
        help="Directory to write intermediate tensors/images",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    image_path = (root / args.image).resolve() if not Path(args.image).is_absolute() else Path(args.image)
    out_json = (root / args.out_json).resolve() if not Path(args.out_json).is_absolute() else Path(args.out_json)
    out_dir = (root / args.out_dir).resolve() if not Path(args.out_dir).is_absolute() else Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    stage3 = preprocess_image(image_path).astype(np.float32)
    app_sem, app_meta = preprocess_android_opencv_semantics_with_meta(image_path)

    diff = np.abs(stage3 - app_sem)
    max_idx = np.unravel_index(int(np.argmax(diff)), diff.shape)

    # Diagnostics for common mismatch classes.
    mae_direct = float(diff.mean())
    mae_channel_swap = float(np.abs(stage3 - app_sem[..., ::-1]).mean())
    mae_scale_255 = float(np.abs(stage3 - (app_sem * 255.0)).mean())

    stage3_bin = out_dir / "stage3_tensor_f32.bin"
    app_bin = out_dir / "app_semantics_tensor_f32.bin"
    stage3.tofile(stage3_bin)
    app_sem.tofile(app_bin)

    # Save preview images for manual inspection.
    stage3_u8 = (np.clip(stage3, 0.0, 1.0) * 255.0).astype(np.uint8)
    app_u8 = (np.clip(app_sem, 0.0, 1.0) * 255.0).astype(np.uint8)
    cv2.imwrite(str(out_dir / "stage3_preview_224.png"), cv2.cvtColor(stage3_u8, cv2.COLOR_RGB2BGR))
    cv2.imwrite(str(out_dir / "app_semantics_preview_224.png"), cv2.cvtColor(app_u8, cv2.COLOR_RGB2BGR))

    report = {
        "image": str(image_path),
        "shape_match": list(stage3.shape) == list(app_sem.shape),
        "dtype": {"stage3": str(stage3.dtype), "app_semantics": str(app_sem.dtype)},
        "byte_for_byte_equal": bool(np.array_equal(stage3, app_sem)),
        "allclose_atol_1e-6": bool(np.allclose(stage3, app_sem, atol=1e-6)),
        "diff": {
            "mean_abs_diff": mae_direct,
            "max_abs_diff": float(diff.max()),
            "max_abs_diff_location_hwc": [int(max_idx[0]), int(max_idx[1]), int(max_idx[2])],
            "stage3_value_at_max": float(stage3[max_idx]),
            "app_semantics_value_at_max": float(app_sem[max_idx]),
            "mae_if_app_channels_reversed": mae_channel_swap,
            "mae_if_app_scaled_0_255": mae_scale_255,
        },
        "stats": {
            "stage3": arr_stats(stage3),
            "app_semantics": arr_stats(app_sem),
        },
        "app_semantics_meta": app_meta,
        "artifacts": {
            "stage3_tensor": str(stage3_bin),
            "app_semantics_tensor": str(app_bin),
            "stage3_preview_png": str(out_dir / "stage3_preview_224.png"),
            "app_semantics_preview_png": str(out_dir / "app_semantics_preview_224.png"),
        },
    }

    out_json.parent.mkdir(parents=True, exist_ok=True)
    with out_json.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(json.dumps(report, indent=2))
    print(f"\nSaved report: {out_json}")


if __name__ == "__main__":
    main()
