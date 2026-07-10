from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
import pandas as pd
import tensorflow as tf

from image_pipeline import preprocess_image


def python_crop_bbox(image_bgr: np.ndarray) -> tuple[int, int, int, int] | None:
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    kernel = np.ones((5, 5), np.uint8)
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel, iterations=2)

    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None

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
            best = (x, y, bw, bh)
            best_area = area

    if best is None:
        return None

    x, y, bw, bh = best
    pad_x = int(0.03 * bw)
    pad_y = int(0.03 * bh)
    x0 = max(x - pad_x, 0)
    y0 = max(y - pad_y, 0)
    x1 = min(x + bw + pad_x, w)
    y1 = min(y + bh + pad_y, h)
    return x0, y0, x1 - 1, y1 - 1


def tensor_stats(arr: np.ndarray) -> dict[str, float]:
    return {
        "mean": float(arr.mean()),
        "std": float(arr.std()),
        "min": float(arr.min()),
        "max": float(arr.max()),
    }


def run_tflite_score(interpreter: tf.lite.Interpreter, arr_hwc: np.ndarray) -> float:
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    x = arr_hwc[np.newaxis, ...].astype(np.float32)
    interpreter.set_tensor(input_details["index"], x)
    interpreter.invoke()
    out = interpreter.get_tensor(output_details["index"])
    return float(out.reshape(-1)[0])


def main() -> None:
    root = Path(__file__).resolve().parents[1]

    # Pick a known genuine sample correctly classified in Stage 5.
    image_rel = Path("dataset/AndroidGenuine/gA_145.jfif")
    image_path = root / image_rel
    flutter_export_dir = root / "artifacts/debug_compare/gA_145_flutter"

    flutter_meta_path = flutter_export_dir / "flutter_preprocess_metadata.json"
    flutter_tensor_path = flutter_export_dir / "flutter_tensor_f32.bin"

    if not flutter_meta_path.exists() or not flutter_tensor_path.exists():
        raise FileNotFoundError(
            "Flutter export artifacts are missing. Run dart export first for gA_145.jfif."
        )

    with flutter_meta_path.open("r", encoding="utf-8") as f:
        flutter_meta = json.load(f)

    flutter_tensor = np.fromfile(flutter_tensor_path, dtype=np.float32).reshape(224, 224, 3)
    stage3_tensor = preprocess_image(image_path).astype(np.float32)

    diff = np.abs(flutter_tensor - stage3_tensor)
    max_idx = np.unravel_index(np.argmax(diff), diff.shape)

    # Heuristics to identify source of mismatch.
    mae_direct = float(diff.mean())
    mae_channel_swap = float(np.abs(flutter_tensor - stage3_tensor[..., ::-1]).mean())
    mae_scale_255 = float(np.abs(flutter_tensor - (stage3_tensor * 255.0)).mean())

    bgr = cv2.imread(str(image_path))
    if bgr is None:
        raise ValueError(f"Unable to read image: {image_path}")
    py_bbox = python_crop_bbox(bgr)
    fl_crop = flutter_meta.get("crop_box_with_padding", {})

    tflite_model_path = root / "artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite"
    interpreter = tf.lite.Interpreter(model_path=str(tflite_model_path))
    interpreter.allocate_tensors()

    primary_scores = {
        "flutter_tensor_tflite_score": run_tflite_score(interpreter, flutter_tensor),
        "stage3_tensor_tflite_score": run_tflite_score(interpreter, stage3_tensor),
    }

    # Score a handful of genuine samples using exported Flutter tensors.
    sample_names = ["gA_145", "gA_147", "gI_054", "gA_053", "gA_120"]
    sample_scores: list[dict[str, object]] = []

    pred_df = pd.read_csv(root / "artifacts/stage5/test_predictions.csv")
    test_npz = np.load(root / "artifacts/stage3/arrays/test.npz", allow_pickle=True)
    source_paths = [str(x) for x in test_npz["source_paths"]]
    stage5_prob_by_path = {
        source_paths[i]: float(pred_df.loc[i, "fraud_probability"]) for i in range(len(source_paths))
    }

    name_to_rel = {
        "gA_145": "dataset/AndroidGenuine/gA_145.jfif",
        "gA_147": "dataset/AndroidGenuine/gA_147.jfif",
        "gI_054": "dataset/iOSGenuine/gI_054.jpg",
        "gA_053": "dataset/AndroidGenuine/gA_053.jpg",
        "gA_120": "dataset/AndroidGenuine/gA_120.jfif",
    }

    for name in sample_names:
        tensor_path = root / f"artifacts/debug_compare/{name}_flutter/flutter_tensor_f32.bin"
        meta_path = root / f"artifacts/debug_compare/{name}_flutter/flutter_preprocess_metadata.json"
        if not tensor_path.exists() or not meta_path.exists():
            continue
        arr = np.fromfile(tensor_path, dtype=np.float32).reshape(224, 224, 3)
        with meta_path.open("r", encoding="utf-8") as f:
            meta = json.load(f)
        rel = name_to_rel[name]
        sample_scores.append(
            {
                "sample": rel,
                "flutter_geometry_pass": bool(meta.get("geometry_pass", False)),
                "flutter_tflite_fraud_score": run_tflite_score(interpreter, arr),
                "stage5_keras_fraud_score": stage5_prob_by_path.get(rel),
            }
        )

    report = {
        "primary_image": str(image_rel),
        "flutter_export_dir": str(flutter_export_dir),
        "shape_match": list(flutter_tensor.shape) == list(stage3_tensor.shape),
        "dtype": {"flutter": str(flutter_tensor.dtype), "stage3": str(stage3_tensor.dtype)},
        "byte_for_byte_equal": bool(np.array_equal(flutter_tensor, stage3_tensor)),
        "allclose_atol_1e-6": bool(np.allclose(flutter_tensor, stage3_tensor, atol=1e-6)),
        "diff": {
            "mean_abs_diff": mae_direct,
            "max_abs_diff": float(diff.max()),
            "max_abs_diff_location_hwc": [int(x) for x in max_idx],
            "flutter_value_at_max": float(flutter_tensor[max_idx]),
            "stage3_value_at_max": float(stage3_tensor[max_idx]),
            "mae_if_stage3_channels_reversed": mae_channel_swap,
            "mae_if_stage3_scaled_0_255": mae_scale_255,
        },
        "stats": {
            "flutter": tensor_stats(flutter_tensor),
            "stage3": tensor_stats(stage3_tensor),
        },
        "roi_boxes": {
            "flutter_crop_xyxy": {
                "x0": fl_crop.get("x0"),
                "y0": fl_crop.get("y0"),
                "x1": fl_crop.get("x1"),
                "y1": fl_crop.get("y1"),
            },
            "python_stage3_crop_xyxy": None
            if py_bbox is None
            else {"x0": py_bbox[0], "y0": py_bbox[1], "x1": py_bbox[2], "y1": py_bbox[3]},
        },
        "primary_scores_tflite": primary_scores,
        "genuine_sample_scores": sample_scores,
    }

    out_path = root / "artifacts/debug_compare/preprocess_comparison_report.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(json.dumps(report, indent=2))
    print(f"\nSaved report: {out_path}")


if __name__ == "__main__":
    main()
