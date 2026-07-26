from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf


HARD7_PATHS = {
    "dataset/iOSGenuine/gI_388.jpg",
    "dataset/iOSGenuine/gI_390.jpg",
    "dataset/iOSGenuine/gI_391.jpg",
    "dataset/AndroidGenuine/gA_192.jpg",
    "dataset/AndroidGenuine/gA_272.jfif",
    "dataset/iOSGenuine/gI_014.PNG",
    "dataset/iOSGenuine/gI_059.jpg",
}


def binary_from_label_text(labels: np.ndarray) -> np.ndarray:
    return np.asarray([1 if "fraud" in str(x).lower() else 0 for x in labels], dtype=np.int32)


def load_split(npz_path: Path):
    d = np.load(npz_path, allow_pickle=True)
    x = d["images"].astype(np.float32, copy=False)
    labels = d["labels_text"].astype(str)
    src = d["source_paths"].astype(str)
    y = binary_from_label_text(labels)
    return x, y, labels, src


def predict(model: tf.keras.Model, x: np.ndarray) -> np.ndarray:
    p = model.predict(x, batch_size=32, verbose=0)
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
    fpr = float(fp / max(1, fp + tn))
    return {
        "accuracy": acc,
        "precision_fraudulent": prec,
        "recall_fraudulent": rec,
        "f1_fraudulent": f1,
        "genuine_fpr": fpr,
        "confusion_matrix": [[tn, fp], [fn, tp]],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-model", required=True)
    parser.add_argument("--old-model", default="artifacts/analysis/pre_ai_model_237499f4.keras")
    parser.add_argument("--arrays-dir", default="artifacts/stage3/arrays")
    parser.add_argument("--threshold", type=float, default=0.16)
    parser.add_argument("--out-json", default="artifacts/subset_sweep/ai_10/checkpoint_gate_eval.json")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    arrays_dir = root / args.arrays_dir

    x_test, y_test, labels_test, src_test = load_split(arrays_dir / "test.npz")

    old_model = tf.keras.models.load_model(root / args.old_model)
    cand_model = tf.keras.models.load_model(root / args.candidate_model)

    old_probs = predict(old_model, x_test)
    cand_probs = predict(cand_model, x_test)

    non_ai_mask = np.asarray(["ai_fraudulent" not in s.lower() for s in labels_test])

    old_non_ai = metrics(y_test[non_ai_mask], old_probs[non_ai_mask], args.threshold)
    cand_non_ai = metrics(y_test[non_ai_mask], cand_probs[non_ai_mask], args.threshold)
    cand_full = metrics(y_test, cand_probs, args.threshold)

    hard7_mask = np.asarray([s in HARD7_PATHS for s in src_test])
    hard_src = src_test[hard7_mask]
    hard_scores = cand_probs[hard7_mask]
    hard_rows = [
        {
            "source_path": str(p),
            "score": float(s),
            "pred": int(s >= args.threshold),
        }
        for p, s in sorted(zip(hard_src.tolist(), hard_scores.tolist()), key=lambda t: t[0])
    ]

    gate_hard7 = all(r["pred"] == 0 for r in hard_rows)
    gate_non_ai = (
        cand_non_ai["accuracy"] >= old_non_ai["accuracy"]
        and cand_non_ai["genuine_fpr"] <= old_non_ai["genuine_fpr"]
    )
    gate_recall = cand_full["recall_fraudulent"] >= 0.98

    out = {
        "threshold": args.threshold,
        "candidate_model": args.candidate_model,
        "old_non_ai_reference": old_non_ai,
        "candidate_non_ai": cand_non_ai,
        "candidate_full": cand_full,
        "hard7": hard_rows,
        "gates": {
            "hard7_all_genuine_at_0_16": bool(gate_hard7),
            "non_ai_match_or_beat_old": bool(gate_non_ai),
            "fraud_recall_ge_0_98": bool(gate_recall),
            "all_gates_pass": bool(gate_hard7 and gate_non_ai and gate_recall),
        },
    }

    out_path = root / args.out_json
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)

    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
