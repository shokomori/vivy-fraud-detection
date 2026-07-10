from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf

from report_before_after_preprocess_alignment import preprocess_android_opencv_semantics


THRESHOLD = 0.16


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    pred = pd.read_csv(root / "artifacts/stage5/test_predictions.csv")
    test_npz = np.load(root / "artifacts/stage3/arrays/test.npz", allow_pickle=True)
    source_paths = [str(x) for x in test_npz["source_paths"]]
    y_true = pred["y_true"].astype(int).to_numpy()

    # Deterministic 16-sample probe: 8 genuine + 8 fraudulent from test set.
    idx_g = [i for i, y in enumerate(y_true) if y == 0][:8]
    idx_f = [i for i, y in enumerate(y_true) if y == 1][:8]
    idx = idx_g + idx_f

    interpreter = tf.lite.Interpreter(
        model_path=str(root / "artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite")
    )
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]["index"]
    out = interpreter.get_output_details()[0]["index"]

    rows: list[dict[str, object]] = []
    for i in idx:
        rel = source_paths[i]
        arr = preprocess_android_opencv_semantics(root / rel).astype(np.float32)
        interpreter.set_tensor(inp, arr[np.newaxis, ...])
        interpreter.invoke()
        score = float(interpreter.get_tensor(out).reshape(-1)[0])
        y_pred = 1 if score >= THRESHOLD else 0
        rows.append(
            {
                "index": int(i),
                "source_path": rel,
                "y_true": int(y_true[i]),
                "y_pred_native_like": int(y_pred),
                "fraud_score_native_like": score,
                "stage5_keras_score": float(pred.loc[i, "fraud_probability"]),
                "matches_stage5_label": bool(int(y_pred) == int(pred.loc[i, "y_pred"])),
            }
        )

    df = pd.DataFrame(rows)
    genuine = df[df["y_true"] == 0]
    fraud = df[df["y_true"] == 1]

    fp = int(((genuine["y_pred_native_like"] == 1)).sum())
    fn = int(((fraud["y_pred_native_like"] == 0)).sum())
    total = len(df)
    acc = float((df["y_true"] == df["y_pred_native_like"]).mean())

    report = {
        "threshold": THRESHOLD,
        "sample_size": int(total),
        "class_balance": {"genuine": int(len(genuine)), "fraudulent": int(len(fraud))},
        "metrics_native_like": {
            "accuracy": acc,
            "false_positive_count": fp,
            "false_positive_rate_on_genuine": float(fp / max(1, len(genuine))),
            "false_negative_count": fn,
            "false_negative_rate_on_fraudulent": float(fn / max(1, len(fraud))),
        },
        "rows": rows,
    }

    out_path = root / "artifacts/debug_compare/native_like_16sample_report.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(json.dumps(report, indent=2))
    print(f"\nSaved report: {out_path}")


if __name__ == "__main__":
    main()
