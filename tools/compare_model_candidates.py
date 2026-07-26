from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf


def metrics(y_true: np.ndarray, probs: np.ndarray, threshold: float) -> dict:
    y_pred = (probs >= threshold).astype(np.int32)
    tn = int(((y_true == 0) & (y_pred == 0)).sum())
    fp = int(((y_true == 0) & (y_pred == 1)).sum())
    fn = int(((y_true == 1) & (y_pred == 0)).sum())
    tp = int(((y_true == 1) & (y_pred == 1)).sum())

    acc = float((tn + tp) / len(y_true))
    prec = float(tp / max(1, tp + fp))
    rec = float(tp / max(1, tp + fn))
    f1 = float(0.0 if (prec + rec) == 0 else (2 * prec * rec / (prec + rec)))

    return {
        "accuracy": acc,
        "precision_fraudulent": prec,
        "recall_fraudulent": rec,
        "f1_fraudulent": f1,
        "confusion_matrix": [[tn, fp], [fn, tp]],
    }


def predict(model_path: Path, x: np.ndarray) -> np.ndarray:
    model = tf.keras.models.load_model(model_path)
    probs = model.predict(x, verbose=0)
    probs = np.asarray(probs)
    if probs.ndim == 2 and probs.shape[1] == 1:
        probs = probs[:, 0]
    return probs.astype(np.float32)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_dir = root / "artifacts" / "analysis"
    out_dir.mkdir(parents=True, exist_ok=True)

    d = np.load(root / "artifacts" / "stage3" / "arrays" / "test.npz", allow_pickle=True)
    x = d["images"].astype(np.float32)
    labels = d["labels_text"].astype(str)
    source_paths = d["source_paths"].astype(str)
    y = np.asarray([1 if "fraud" in s.lower() else 0 for s in labels], dtype=np.int32)

    mask_non_ai = np.asarray(["ai_fraudulent" not in s.lower() for s in labels])

    models = {
        "old_pre_ai": {
            "path": root / "artifacts" / "analysis" / "pre_ai_model_237499f4.keras",
            "threshold": 0.16,
        },
        "new_ai_expansion": {
            "path": root / "artifacts" / "stage4" / "mobilenetv2_fraud_detector.keras",
            "threshold": 0.05,
        },
        "targeted_candidate": {
            "path": root / "artifacts" / "stage4_targeted" / "mobilenetv2_fraud_detector_targeted.keras",
            "threshold": 0.2149999999999999,
        },
    }

    report = {}

    probs_map: dict[str, np.ndarray] = {}
    for name, cfg in models.items():
        probs = predict(cfg["path"], x)
        probs_map[name] = probs
        report[name] = {
            "threshold": cfg["threshold"],
            "full_test": metrics(y, probs, cfg["threshold"]),
            "non_ai_subset": metrics(y[mask_non_ai], probs[mask_non_ai], cfg["threshold"]),
        }

    hard_paths = [
        "dataset/iOSGenuine/gI_388.jpg",
        "dataset/iOSGenuine/gI_390.jpg",
        "dataset/iOSGenuine/gI_391.jpg",
        "dataset/AndroidGenuine/gA_192.jpg",
        "dataset/AndroidGenuine/gA_272.jfif",
        "dataset/iOSGenuine/gI_014.PNG",
        "dataset/iOSGenuine/gI_059.jpg",
    ]

    rows = []
    idx_map = {p: i for i, p in enumerate(source_paths)}
    for p in hard_paths:
        i = idx_map[p]
        row = {
            "source_path": p,
            "label_text": str(labels[i]),
            "y_true": int(y[i]),
        }
        for model_name, cfg in models.items():
            s = float(probs_map[model_name][i])
            row[f"{model_name}_score"] = s
            row[f"{model_name}_pred"] = int(s >= cfg["threshold"])
        rows.append(row)

    hard_df = pd.DataFrame(rows)
    hard_csv = out_dir / "hard7_old_new_targeted_scores.csv"
    hard_df.to_csv(hard_csv, index=False)

    report["hard7_csv"] = str(hard_csv)

    report_path = out_dir / "candidate_side_by_side_report.json"
    with report_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(f"Saved: {report_path}")
    print(f"Saved: {hard_csv}")


if __name__ == "__main__":
    main()
