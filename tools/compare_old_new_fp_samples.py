from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf


OLD_THRESHOLD = 0.16
NEW_THRESHOLD = 0.05


def _predict(model: tf.keras.Model, images: np.ndarray, batch_size: int = 32) -> np.ndarray:
    probs = model.predict(images, batch_size=batch_size, verbose=0)
    probs = np.asarray(probs)
    if probs.ndim == 2 and probs.shape[1] == 1:
        return probs[:, 0].astype(np.float32)
    if probs.ndim == 1:
        return probs.astype(np.float32)
    raise ValueError(f"Unexpected output shape: {probs.shape}")


def _metrics(y_true: np.ndarray, probs: np.ndarray, threshold: float) -> dict[str, float | list[list[int]]]:
    y_pred = (probs >= threshold).astype(np.int32)
    tn = int(((y_true == 0) & (y_pred == 0)).sum())
    fp = int(((y_true == 0) & (y_pred == 1)).sum())
    fn = int(((y_true == 1) & (y_pred == 0)).sum())
    tp = int(((y_true == 1) & (y_pred == 1)).sum())

    accuracy = float((tn + tp) / len(y_true))
    precision = float(tp / max(1, tp + fp))
    recall = float(tp / max(1, tp + fn))
    f1 = float(0.0 if (precision + recall) == 0 else (2 * precision * recall / (precision + recall)))

    return {
        "accuracy": accuracy,
        "precision_fraudulent": precision,
        "recall_fraudulent": recall,
        "f1_fraudulent": f1,
        "confusion_matrix": [[tn, fp], [fn, tp]],
    }


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_dir = root / "artifacts" / "analysis"
    out_dir.mkdir(parents=True, exist_ok=True)

    old_model_path = root / "artifacts" / "analysis" / "pre_ai_model_237499f4.keras"
    new_model_path = root / "artifacts" / "stage4" / "mobilenetv2_fraud_detector.keras"

    test_npz = np.load(root / "artifacts" / "stage3" / "arrays" / "test.npz", allow_pickle=True)
    images = test_npz["images"].astype(np.float32)
    y_true = np.asarray([1 if "fraud" in str(x).lower() else 0 for x in test_npz["labels_text"]], dtype=np.int32)
    source_paths = np.asarray(test_npz["source_paths"]).astype(str)

    stage5 = pd.read_csv(root / "artifacts" / "stage5" / "test_predictions.csv")
    stage5 = stage5.reset_index().rename(columns={"index": "row_idx"})
    stage5["source_path"] = source_paths

    # Exact seven false positives from current run at threshold 0.05.
    fp7 = stage5[(stage5["y_true"] == 0) & (stage5["y_pred"] == 1)].copy()

    old_model = tf.keras.models.load_model(old_model_path)
    new_model = tf.keras.models.load_model(new_model_path)

    old_probs = _predict(old_model, images)
    new_probs = _predict(new_model, images)

    # Full-set model comparison at both thresholds.
    comparison = {
        "new_model_threshold_0_05": _metrics(y_true, new_probs, NEW_THRESHOLD),
        "new_model_threshold_0_16": _metrics(y_true, new_probs, OLD_THRESHOLD),
        "old_model_threshold_0_16": _metrics(y_true, old_probs, OLD_THRESHOLD),
        "old_model_threshold_0_05": _metrics(y_true, old_probs, NEW_THRESHOLD),
    }

    rows = []
    for _, r in fp7.iterrows():
        idx = int(r["row_idx"])
        old_score = float(old_probs[idx])
        new_score = float(new_probs[idx])
        rows.append(
            {
                "row_idx": idx,
                "source_path": str(r["source_path"]),
                "label_text": str(r["label_text"]),
                "y_true": int(r["y_true"]),
                "new_model_score": new_score,
                "new_pred_at_0_05": int(new_score >= NEW_THRESHOLD),
                "new_pred_at_0_16": int(new_score >= OLD_THRESHOLD),
                "old_model_score": old_score,
                "old_pred_at_0_16": int(old_score >= OLD_THRESHOLD),
                "old_pred_at_0_05": int(old_score >= NEW_THRESHOLD),
            }
        )

    fp_df = pd.DataFrame(rows).sort_values(by="new_model_score", ascending=False)
    fp_csv = out_dir / "fp7_old_vs_new_scores.csv"
    fp_df.to_csv(fp_csv, index=False)

    report = {
        "old_model_path": str(old_model_path),
        "new_model_path": str(new_model_path),
        "thresholds": {"old": OLD_THRESHOLD, "new": NEW_THRESHOLD},
        "fp7_count": int(len(fp_df)),
        "comparison_metrics": comparison,
        "fp7_csv": str(fp_csv),
    }

    report_path = out_dir / "old_vs_new_model_comparison.json"
    with report_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(f"Saved FP comparison CSV: {fp_csv}")
    print(f"Saved model comparison JSON: {report_path}")


if __name__ == "__main__":
    main()
