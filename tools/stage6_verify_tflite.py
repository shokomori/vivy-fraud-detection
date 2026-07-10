from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Tuple

import numpy as np
import pandas as pd
import tensorflow as tf


def binary_from_label_text(labels: np.ndarray) -> np.ndarray:
    return np.asarray([1 if "fraud" in str(x).lower() else 0 for x in labels], dtype=np.int32)


def load_test_split(npz_path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    data = np.load(npz_path, allow_pickle=True)
    images = data["images"].astype(np.float32)
    labels_text = np.asarray(data["labels_text"]).astype(str)
    labels_bin = binary_from_label_text(labels_text)
    source_paths = np.asarray(data["source_paths"]).astype(str)
    return images, labels_bin, source_paths


def predict_keras(model_path: Path, images: np.ndarray, batch_size: int) -> np.ndarray:
    model = tf.keras.models.load_model(model_path)
    preds = model.predict(images, batch_size=batch_size, verbose=0)
    preds = np.asarray(preds)
    if preds.ndim == 2 and preds.shape[1] == 1:
        preds = preds[:, 0]
    return preds.astype(np.float32)


def predict_tflite(tflite_path: Path, images: np.ndarray) -> np.ndarray:
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    in_scale, in_zero = input_details.get("quantization", (0.0, 0))
    out_scale, out_zero = output_details.get("quantization", (0.0, 0))

    probs = []
    for i in range(images.shape[0]):
        sample = images[i : i + 1]
        if input_details["dtype"] in (np.uint8, np.int8) and in_scale not in (0.0, None):
            q = np.round(sample / in_scale + in_zero).astype(input_details["dtype"])
            input_tensor = q
        else:
            input_tensor = sample.astype(input_details["dtype"])

        interpreter.set_tensor(input_details["index"], input_tensor)
        interpreter.invoke()
        out = interpreter.get_tensor(output_details["index"])

        if output_details["dtype"] in (np.uint8, np.int8) and out_scale not in (0.0, None):
            out = (out.astype(np.float32) - out_zero) * out_scale

        out = np.asarray(out)
        if out.ndim == 2 and out.shape[1] == 1:
            probs.append(float(out[0, 0]))
        elif out.ndim == 1:
            probs.append(float(out[0]))
        else:
            raise ValueError(f"Unexpected TFLite output shape: {out.shape}")

    return np.asarray(probs, dtype=np.float32)


def main() -> None:
    parser = argparse.ArgumentParser(description="Stage 6 TFLite vs Keras verification")
    parser.add_argument("--keras-model", default="artifacts/stage4/mobilenetv2_fraud_detector.keras")
    parser.add_argument("--tflite-model", default="artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite")
    parser.add_argument("--test-npz", default="artifacts/stage3/arrays/test.npz")
    parser.add_argument("--threshold", type=float, default=0.16, help="Fraud decision threshold from Stage 5")
    parser.add_argument("--sample-size", type=int, default=40, help="Number of test samples to compare")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--output-dir", default="artifacts/stage6")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    keras_model = root / args.keras_model
    tflite_model = root / args.tflite_model
    test_npz = root / args.test_npz
    out_dir = root / args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    if not keras_model.exists():
        raise FileNotFoundError(f"Keras model not found: {keras_model}")
    if not tflite_model.exists():
        raise FileNotFoundError(f"TFLite model not found: {tflite_model}")
    if not test_npz.exists():
        raise FileNotFoundError(f"Test NPZ not found: {test_npz}")

    images, y_true, source_paths = load_test_split(test_npz)
    n = min(args.sample_size, len(images))
    images = images[:n]
    y_true = y_true[:n]
    source_paths = source_paths[:n]

    p_keras = predict_keras(keras_model, images, batch_size=args.batch_size)
    p_tflite = predict_tflite(tflite_model, images)

    yk = (p_keras >= args.threshold).astype(np.int32)
    yt = (p_tflite >= args.threshold).astype(np.int32)

    decision_match = yk == yt
    prob_abs_diff = np.abs(p_keras - p_tflite)

    df = pd.DataFrame(
        {
            "source_path": source_paths,
            "y_true": y_true,
            "keras_prob": p_keras,
            "tflite_prob": p_tflite,
            "abs_diff": prob_abs_diff,
            "keras_pred": yk,
            "tflite_pred": yt,
            "decision_match": decision_match.astype(int),
        }
    )

    csv_path = out_dir / "tflite_verification_samples.csv"
    df.to_csv(csv_path, index=False)

    total = int(len(df))
    matches = int(decision_match.sum())
    mismatches = int(total - matches)

    report = {
        "threshold": args.threshold,
        "sample_size": total,
        "matches": matches,
        "mismatches": mismatches,
        "match_rate": float(matches / total if total else 0.0),
        "max_abs_prob_diff": float(prob_abs_diff.max() if total else 0.0),
        "mean_abs_prob_diff": float(prob_abs_diff.mean() if total else 0.0),
        "keras_model": str(keras_model),
        "tflite_model": str(tflite_model),
        "details_csv": str(csv_path),
    }

    report_path = out_dir / "tflite_verification_report.json"
    with report_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print("Stage 6 verification complete.")
    print(f"Threshold: {args.threshold:.3f}")
    print(f"Samples compared: {total}")
    print(f"Matches: {matches}")
    print(f"Mismatches: {mismatches}")
    print(f"Match rate: {report['match_rate']:.4f}")
    print(f"Max abs prob diff: {report['max_abs_prob_diff']:.6f}")
    print(f"Mean abs prob diff: {report['mean_abs_prob_diff']:.6f}")
    print(f"Report: {report_path}")


if __name__ == "__main__":
    main()
