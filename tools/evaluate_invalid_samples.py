from __future__ import annotations

from pathlib import Path
import csv
import sys

try:
    import cv2
    import numpy as np
    import tensorflow as tf
except Exception as e:
    print(f"Missing dependency: {e}", file=sys.stderr)
    raise

from tools.image_pipeline import preprocess_image


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset_dir = root / "dataset" / "Invalid samples"
    model_path = root / "vivy_app" / "assets" / "models" / "mobilenetv2_fraud_detector_float16.tflite"

    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Dataset not found: {dataset_dir}")

    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    exts = {".jpg", ".jpeg", ".jfif", ".png", ".webp"}
    rows = []
    for path in sorted(dataset_dir.rglob("*")):
        if path.suffix.lower() not in exts:
            continue
        try:
            arr = preprocess_image(path)
        except Exception as exc:
            print(f"SKIP {path.name}: {exc}")
            continue
        x = np.expand_dims(arr.astype(np.float32), axis=0)
        interpreter.set_tensor(input_details["index"], x)
        interpreter.invoke()
        out = interpreter.get_tensor(output_details["index"]).reshape(-1)
        score = float(out[0])
        label = "genuine" if score < 0.135 else ("invalid" if score <= 0.185 else "fraudulent")
        rows.append((path.name, score, label))

    rows.sort(key=lambda item: item[1])
    counts = {"genuine": 0, "invalid": 0, "fraudulent": 0}
    for _, _, label in rows:
        counts[label] += 1

    print(f"Total samples: {len(rows)}")
    print("Counts:")
    for label in ["genuine", "invalid", "fraudulent"]:
        print(f"  {label}: {counts[label]}")

    if rows:
        print("\nLowest scores:")
        for name, score, label in rows[:5]:
            print(f"  {name}: {score:.4f} -> {label}")
        print("\nHighest scores:")
        for name, score, label in rows[-5:]:
            print(f"  {name}: {score:.4f} -> {label}")

    csv_path = root / "artifacts" / "invalid_sample_scores.csv"
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["filename", "score", "label"])
        writer.writerows(rows)
    print(f"Wrote results to {csv_path}")


if __name__ == "__main__":
    main()
