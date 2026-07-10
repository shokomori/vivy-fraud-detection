from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
import tensorflow as tf

from image_pipeline import preprocess_image


def preprocess_android_opencv_semantics(image_path: Path) -> np.ndarray:
    bgr = cv2.imread(str(image_path))
    if bgr is None:
        raise ValueError(f"Unable to read image: {image_path}")

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    kernel = np.ones((5, 5), np.uint8)
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel, iterations=2)

    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return cv2.cvtColor(cv2.resize(bgr, (224, 224), interpolation=cv2.INTER_AREA), cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0

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
        roi = bgr
    else:
        x, y, bw, bh = best
        pad_x = int(0.03 * bw)
        pad_y = int(0.03 * bh)
        x0 = max(x - pad_x, 0)
        y0 = max(y - pad_y, 0)
        x1 = min(x + bw + pad_x, w)
        y1 = min(y + bh + pad_y, h)
        roi = bgr[y0:y1, x0:x1]

    resized = cv2.resize(roi, (224, 224), interpolation=cv2.INTER_AREA)
    rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
    return rgb.astype(np.float32) / 255.0


def tflite_score(interpreter: tf.lite.Interpreter, arr_hwc: np.ndarray) -> float:
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    x = arr_hwc[np.newaxis, ...].astype(np.float32)
    interpreter.set_tensor(inp["index"], x)
    interpreter.invoke()
    y = interpreter.get_tensor(out["index"])
    return float(y.reshape(-1)[0])


def old_flutter_tensor(root: Path, sample_stem: str) -> np.ndarray:
    path = root / f"artifacts/debug_compare/{sample_stem}_flutter/flutter_tensor_f32.bin"
    return np.fromfile(path, dtype=np.float32).reshape(224, 224, 3)


def main() -> None:
    root = Path(__file__).resolve().parents[1]

    samples = [
        ("gA_145", Path("dataset/AndroidGenuine/gA_145.jfif")),
        ("gA_147", Path("dataset/AndroidGenuine/gA_147.jfif")),
        ("gI_054", Path("dataset/iOSGenuine/gI_054.jpg")),
        ("gA_053", Path("dataset/AndroidGenuine/gA_053.jpg")),
        ("gA_120", Path("dataset/AndroidGenuine/gA_120.jfif")),
    ]

    interp = tf.lite.Interpreter(model_path=str(root / "artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite"))
    interp.allocate_tensors()

    rows = []
    for stem, rel in samples:
        image_path = root / rel
        stage3 = preprocess_image(image_path).astype(np.float32)
        after = preprocess_android_opencv_semantics(image_path).astype(np.float32)
        before = old_flutter_tensor(root, stem)

        before_diff = np.abs(before - stage3)
        after_diff = np.abs(after - stage3)

        rows.append(
            {
                "sample": str(rel).replace("\\", "/"),
                "before_allclose_atol_1e-6": bool(np.allclose(before, stage3, atol=1e-6)),
                "before_mean_abs_diff_vs_stage3": float(before_diff.mean()),
                "before_max_abs_diff_vs_stage3": float(before_diff.max()),
                "after_allclose_atol_1e-6": bool(np.allclose(after, stage3, atol=1e-6)),
                "after_mean_abs_diff_vs_stage3": float(after_diff.mean()),
                "after_max_abs_diff_vs_stage3": float(after_diff.max()),
                "before_tflite_fraud_score": tflite_score(interp, before),
                "after_tflite_fraud_score": tflite_score(interp, after),
                "stage3_tflite_fraud_score": tflite_score(interp, stage3),
            }
        )

    report = {
        "description": "Before/after preprocessing alignment report on 5 genuine samples",
        "notes": {
            "before": "Old Flutter package:image preprocessing export",
            "after": "New OpenCV-aligned semantics matching Android native bridge and Stage 3",
        },
        "rows": rows,
    }

    out = root / "artifacts/debug_compare/preprocess_before_after_report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(json.dumps(report, indent=2))
    print(f"\nSaved report: {out}")


if __name__ == "__main__":
    main()
