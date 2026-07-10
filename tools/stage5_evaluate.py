from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_score, recall_score


def binary_from_label_text(labels: np.ndarray) -> np.ndarray:
    # Project label contract: 0 = Genuine, 1 = Fraudulent.
    return np.asarray([1 if "fraud" in str(x).lower() else 0 for x in labels], dtype=np.int32)


def load_split(npz_path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    if not npz_path.exists():
        raise FileNotFoundError(f"Split file not found: {npz_path}")

    data = np.load(npz_path, allow_pickle=True)
    images = data["images"].astype(np.float32)

    if "labels_text" in data:
        labels_text = np.asarray(data["labels_text"]).astype(str)
    else:
        label_names = [str(x) for x in data["label_names"]]
        labels_text = np.asarray([label_names[i] for i in data["labels_int"].astype(int)], dtype=str)

    labels_bin = binary_from_label_text(labels_text)
    return images, labels_bin, labels_text


def predict_probabilities(model: tf.keras.Model, images: np.ndarray, batch_size: int) -> np.ndarray:
    probs = model.predict(images, batch_size=batch_size, verbose=0)
    probs = np.asarray(probs)
    if probs.ndim == 2 and probs.shape[1] == 1:
        return probs[:, 0].astype(np.float32)
    if probs.ndim == 1:
        return probs.astype(np.float32)
    raise ValueError(f"Unexpected model output shape for binary classification: {probs.shape}")


def compute_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
    return {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "precision_fraudulent": float(precision_score(y_true, y_pred, pos_label=1, zero_division=0)),
        "recall_fraudulent": float(recall_score(y_true, y_pred, pos_label=1, zero_division=0)),
        "f1_fraudulent": float(f1_score(y_true, y_pred, pos_label=1, zero_division=0)),
    }


def f2_score(precision: float, recall: float) -> float:
    denom = 4.0 * precision + recall
    if denom == 0:
        return 0.0
    return (5.0 * precision * recall) / denom


def search_threshold(
    y_val: np.ndarray,
    p_val: np.ndarray,
    min_fraud_recall: float,
    start: float,
    end: float,
    step: float,
) -> Tuple[float, pd.DataFrame, str]:
    thresholds = np.arange(start, end + 1e-9, step)
    rows: List[Dict[str, float]] = []

    for t in thresholds:
        y_pred = (p_val >= t).astype(np.int32)
        metrics = compute_metrics(y_val, y_pred)
        f2 = f2_score(metrics["precision_fraudulent"], metrics["recall_fraudulent"])
        rows.append(
            {
                "threshold": float(t),
                **metrics,
                "f2_fraudulent": float(f2),
                "meets_min_recall": int(metrics["recall_fraudulent"] >= min_fraud_recall),
            }
        )

    df = pd.DataFrame(rows)

    eligible = df[df["meets_min_recall"] == 1].copy()
    if not eligible.empty:
        # Recall-biased selection: constrain by minimum recall first, then optimize F2 (recall-weighted).
        best_row = eligible.sort_values(
            by=["f2_fraudulent", "precision_fraudulent", "accuracy", "threshold"],
            ascending=[False, False, False, False],
        ).iloc[0]
        rationale = "Selected from thresholds meeting minimum fraudulent recall; best F2 (recall-weighted)."
    else:
        best_row = df.sort_values(
            by=["recall_fraudulent", "f2_fraudulent", "precision_fraudulent", "accuracy"],
            ascending=[False, False, False, False],
        ).iloc[0]
        rationale = "No threshold met minimum fraudulent recall; selected highest recall fallback."

    return float(best_row["threshold"]), df, rationale


def save_confusion_matrix(cm: np.ndarray, output_path: Path, labels: List[str]) -> None:
    fig, ax = plt.subplots(figsize=(5, 4), dpi=150)
    im = ax.imshow(cm, cmap="Blues")
    ax.set_xticks(np.arange(len(labels)))
    ax.set_yticks(np.arange(len(labels)))
    ax.set_xticklabels(labels)
    ax.set_yticklabels(labels)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    ax.set_title("Confusion Matrix (Test)")

    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            ax.text(j, i, str(cm[i, j]), ha="center", va="center", color="black")

    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(output_path)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Stage 5 evaluation with recall-biased threshold tuning")
    parser.add_argument("--model", default="artifacts/stage4/mobilenetv2_fraud_detector.keras", help="Trained Keras model path")
    parser.add_argument("--arrays-dir", default="artifacts/stage3/arrays", help="Directory containing val/test NPZ")
    parser.add_argument("--output-dir", default="artifacts/stage5", help="Directory for evaluation outputs")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--min-fraud-recall", type=float, default=0.90, help="Minimum recall target for fraudulent class")
    parser.add_argument("--threshold-start", type=float, default=0.05)
    parser.add_argument("--threshold-end", type=float, default=0.95)
    parser.add_argument("--threshold-step", type=float, default=0.005)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    model_path = root / args.model
    arrays_dir = root / args.arrays_dir
    out_dir = root / args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")

    x_val, y_val, val_labels_text = load_split(arrays_dir / "val.npz")
    x_test, y_test, test_labels_text = load_split(arrays_dir / "test.npz")

    print("Binary label encoding contract: 0=Genuine, 1=Fraudulent")
    print(f"Loaded val:  X={x_val.shape}, y={y_val.shape}")
    print(f"Loaded test: X={x_test.shape}, y={y_test.shape}")

    model = tf.keras.models.load_model(model_path)

    p_val = predict_probabilities(model, x_val, batch_size=args.batch_size)
    best_threshold, threshold_df, rationale = search_threshold(
        y_val=y_val,
        p_val=p_val,
        min_fraud_recall=args.min_fraud_recall,
        start=args.threshold_start,
        end=args.threshold_end,
        step=args.threshold_step,
    )

    threshold_csv = out_dir / "threshold_search_val.csv"
    threshold_df.to_csv(threshold_csv, index=False)

    p_test = predict_probabilities(model, x_test, batch_size=args.batch_size)
    y_test_pred = (p_test >= best_threshold).astype(np.int32)

    test_metrics = compute_metrics(y_test, y_test_pred)
    cm = confusion_matrix(y_test, y_test_pred, labels=[0, 1])

    cm_path = out_dir / "confusion_matrix_test.png"
    save_confusion_matrix(cm, cm_path, labels=["Genuine (0)", "Fraudulent (1)"])

    pred_csv = out_dir / "test_predictions.csv"
    pd.DataFrame(
        {
            "label_text": test_labels_text,
            "y_true": y_test,
            "fraud_probability": p_test,
            "threshold": best_threshold,
            "y_pred": y_test_pred,
        }
    ).to_csv(pred_csv, index=False)

    report = {
        "label_mapping": {
            "0": "Genuine",
            "1": "Fraudulent",
            "positive_class_for_metrics_and_threshold": 1,
        },
        "model_path": str(model_path),
        "threshold_tuning": {
            "selected_threshold": best_threshold,
            "min_fraud_recall_target": args.min_fraud_recall,
            "selection_rationale": rationale,
            "search_range": [args.threshold_start, args.threshold_end, args.threshold_step],
        },
        "test_metrics": test_metrics,
        "confusion_matrix_test": {
            "labels_order": ["Genuine (0)", "Fraudulent (1)"],
            "matrix": cm.tolist(),
        },
        "artifacts": {
            "threshold_search_csv": str(threshold_csv),
            "confusion_matrix_png": str(cm_path),
            "test_predictions_csv": str(pred_csv),
        },
    }

    report_path = out_dir / "evaluation_report.json"
    with report_path.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    print("\nStage 5 evaluation complete.")
    print(f"Selected threshold: {best_threshold:.4f}")
    print(f"Test accuracy: {test_metrics['accuracy']:.4f}")
    print(f"Test precision (Fraudulent=1): {test_metrics['precision_fraudulent']:.4f}")
    print(f"Test recall (Fraudulent=1):    {test_metrics['recall_fraudulent']:.4f}")
    print(f"Test F1 (Fraudulent=1):        {test_metrics['f1_fraudulent']:.4f}")
    print(f"Report saved: {report_path}")
    print(f"Confusion matrix image: {cm_path}")


if __name__ == "__main__":
    main()
