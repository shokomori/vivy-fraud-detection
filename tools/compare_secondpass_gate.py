from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf


def predict(model_path: Path, x: np.ndarray) -> np.ndarray:
    model = tf.keras.models.load_model(model_path)
    p = model.predict(x, verbose=0)
    p = np.asarray(p)
    if p.ndim == 2 and p.shape[1] == 1:
        p = p[:, 0]
    return p.astype(np.float32)


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


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_dir = root / "artifacts" / "analysis"
    out_dir.mkdir(parents=True, exist_ok=True)

    d = np.load(root / "artifacts" / "stage3" / "arrays" / "test.npz", allow_pickle=True)
    x = d["images"].astype(np.float32)
    labels = d["labels_text"].astype(str)
    source_paths = d["source_paths"].astype(str)
    y = np.asarray([1 if "fraud" in s.lower() else 0 for s in labels], dtype=np.int32)

    non_ai_mask = np.asarray(["ai_fraudulent" not in s.lower() for s in labels])

    models = {
        "old_pre_ai": {
            "path": root / "artifacts" / "analysis" / "pre_ai_model_237499f4.keras",
            "threshold": 0.16,
        },
        "new_ai_expansion": {
            "path": root / "artifacts" / "stage4" / "mobilenetv2_fraud_detector.keras",
            "threshold": 0.05,
        },
        "secondpass_candidate": {
            "path": root / "artifacts" / "stage4_secondpass" / "checkpoints" / "best_secondpass.keras",
            "threshold": 0.17,
        },
    }

    probs_map = {name: predict(cfg["path"], x) for name, cfg in models.items()}

    report = {}
    for name, cfg in models.items():
        probs = probs_map[name]
        report[name] = {
            "threshold": cfg["threshold"],
            "full_test": metrics(y, probs, cfg["threshold"]),
            "non_ai_subset": metrics(y[non_ai_mask], probs[non_ai_mask], cfg["threshold"]),
        }

    hard7 = [
        "dataset/iOSGenuine/gI_388.jpg",
        "dataset/iOSGenuine/gI_390.jpg",
        "dataset/iOSGenuine/gI_391.jpg",
        "dataset/AndroidGenuine/gA_192.jpg",
        "dataset/AndroidGenuine/gA_272.jfif",
        "dataset/iOSGenuine/gI_014.PNG",
        "dataset/iOSGenuine/gI_059.jpg",
    ]
    idx = {p: i for i, p in enumerate(source_paths)}

    rows = []
    for p in hard7:
        i = idx[p]
        row = {"source_path": p, "y_true": int(y[i]), "label_text": str(labels[i])}
        for name, cfg in models.items():
            s = float(probs_map[name][i])
            row[f"{name}_score"] = s
            row[f"{name}_pred"] = int(s >= cfg["threshold"])
        rows.append(row)

    hard_df = pd.DataFrame(rows)
    hard_csv = out_dir / "hard7_secondpass_old_new_scores.csv"
    hard_df.to_csv(hard_csv, index=False)

    # Gate checks relative to old model on non-AI subset + hard7 + recall floor.
    old_non_ai = report["old_pre_ai"]["non_ai_subset"]
    cand_non_ai = report["secondpass_candidate"]["non_ai_subset"]
    cand_full = report["secondpass_candidate"]["full_test"]

    hard_all_genuine = bool((hard_df["secondpass_candidate_pred"] == 0).all())
    non_ai_acc_ok = cand_non_ai["accuracy"] >= old_non_ai["accuracy"]
    non_ai_fpr_ok = cand_non_ai["confusion_matrix"][0][1] <= old_non_ai["confusion_matrix"][0][1]
    recall_ok = cand_full["recall_fraudulent"] >= 0.98

    gates = {
        "hard7_all_genuine": hard_all_genuine,
        "non_ai_accuracy_meets_or_beats_old": bool(non_ai_acc_ok),
        "non_ai_fp_count_meets_or_beats_old": bool(non_ai_fpr_ok),
        "overall_fraud_recall_ge_0_98": bool(recall_ok),
        "all_pass": bool(hard_all_genuine and non_ai_acc_ok and non_ai_fpr_ok and recall_ok),
    }

    report["gate_checks"] = gates
    report["hard7_csv"] = str(hard_csv)

    report_path = out_dir / "secondpass_side_by_side_report.json"
    with report_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print(f"Saved {report_path}")
    print(f"Saved {hard_csv}")


if __name__ == "__main__":
    main()
