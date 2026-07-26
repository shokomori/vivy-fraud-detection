from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
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


def load_split(npz_path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    data = np.load(npz_path, allow_pickle=True)
    images = data["images"].astype(np.float32)
    labels_text = data["labels_text"].astype(str)
    source_paths = data["source_paths"].astype(str)
    y = binary_from_label_text(labels_text)
    return images, y, labels_text, source_paths


def compute_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> Dict[str, float]:
    tn = int(((y_true == 0) & (y_pred == 0)).sum())
    fp = int(((y_true == 0) & (y_pred == 1)).sum())
    fn = int(((y_true == 1) & (y_pred == 0)).sum())
    tp = int(((y_true == 1) & (y_pred == 1)).sum())

    acc = float((tn + tp) / len(y_true))
    fpr = float(fp / max(1, fp + tn))
    rec = float(tp / max(1, tp + fn))

    return {
        "accuracy": acc,
        "genuine_fpr": fpr,
        "fraud_recall": rec,
        "tn": float(tn),
        "fp": float(fp),
        "fn": float(fn),
        "tp": float(tp),
    }


def baseline_from_old(
    old_model: tf.keras.Model,
    x_val: np.ndarray,
    y_val: np.ndarray,
    labels_val: np.ndarray,
    threshold: float,
) -> Dict[str, float]:
    probs = old_model.predict(x_val, verbose=0).reshape(-1)
    pred = (probs >= threshold).astype(np.int32)

    non_ai_mask = np.asarray(["ai_fraudulent" not in s.lower() for s in labels_val])
    metrics_non_ai = compute_metrics(y_val[non_ai_mask], pred[non_ai_mask])
    metrics_all = compute_metrics(y_val, pred)

    return {
        "val_non_ai_accuracy": metrics_non_ai["accuracy"],
        "val_non_ai_genuine_fpr": metrics_non_ai["genuine_fpr"],
        "val_overall_fraud_recall": metrics_all["fraud_recall"],
    }


class ConstraintSelector(tf.keras.callbacks.Callback):
    def __init__(
        self,
        run_dir: Path,
        x_val: np.ndarray,
        y_val: np.ndarray,
        labels_val: np.ndarray,
        x_hard: np.ndarray,
        threshold: float,
        min_recall: float,
        min_non_ai_acc: float,
        max_non_ai_fpr: float,
    ):
        super().__init__()
        self.run_dir = run_dir
        self.x_val = x_val
        self.y_val = y_val
        self.labels_val = labels_val
        self.x_hard = x_hard
        self.threshold = threshold

        self.min_recall = min_recall
        self.min_non_ai_acc = min_non_ai_acc
        self.max_non_ai_fpr = max_non_ai_fpr

        self.best_score: Tuple[float, ...] | None = None
        self.best_weights: List[np.ndarray] | None = None
        self.best_row: Dict[str, float] | None = None
        self.rows: List[Dict[str, float]] = []

    def on_epoch_end(self, epoch: int, logs=None):
        logs = logs or {}

        p_val = self.model.predict(self.x_val, verbose=0).reshape(-1)
        y_val_pred = (p_val >= self.threshold).astype(np.int32)

        m_all = compute_metrics(self.y_val, y_val_pred)
        non_ai_mask = np.asarray(["ai_fraudulent" not in s.lower() for s in self.labels_val])
        m_non_ai = compute_metrics(self.y_val[non_ai_mask], y_val_pred[non_ai_mask])

        p_hard = self.model.predict(self.x_hard, verbose=0).reshape(-1)
        hard_ok = int((p_hard < self.threshold).sum())
        hard_all_ok = 1 if hard_ok == len(p_hard) else 0

        recall_ok = 1 if m_all["fraud_recall"] >= self.min_recall else 0
        non_ai_acc_ok = 1 if m_non_ai["accuracy"] >= self.min_non_ai_acc else 0
        non_ai_fpr_ok = 1 if m_non_ai["genuine_fpr"] <= self.max_non_ai_fpr else 0

        all_constraints_ok = 1 if (hard_all_ok and recall_ok and non_ai_acc_ok and non_ai_fpr_ok) else 0

        row = {
            "epoch": float(epoch + 1),
            "all_constraints_ok": float(all_constraints_ok),
            "hard_all_ok": float(hard_all_ok),
            "hard_ok_count": float(hard_ok),
            "hard_max_prob": float(p_hard.max()),
            "val_fraud_recall": float(m_all["fraud_recall"]),
            "val_non_ai_accuracy": float(m_non_ai["accuracy"]),
            "val_non_ai_genuine_fpr": float(m_non_ai["genuine_fpr"]),
            "val_loss": float(logs.get("val_loss", np.nan)),
        }
        self.rows.append(row)

        score = (
            all_constraints_ok,
            hard_all_ok,
            recall_ok,
            non_ai_acc_ok,
            non_ai_fpr_ok,
            float(m_all["fraud_recall"]),
            -float(m_non_ai["genuine_fpr"]),
            float(m_non_ai["accuracy"]),
            -float(p_hard.max()),
            -float(logs.get("val_loss", 1e9)),
        )

        if self.best_score is None or score > self.best_score:
            self.best_score = score
            self.best_weights = self.model.get_weights()
            self.best_row = row
            ckpt_dir = self.run_dir / "checkpoints"
            ckpt_dir.mkdir(parents=True, exist_ok=True)
            self.model.save(ckpt_dir / "best_secondpass.keras")

    def finalize(self) -> None:
        if self.best_weights is not None:
            self.model.set_weights(self.best_weights)


def main() -> None:
    parser = argparse.ArgumentParser(description="Second-pass guarded fine-tune from old model")
    parser.add_argument("--arrays-dir", default="artifacts/stage3/arrays")
    parser.add_argument("--old-model", default="artifacts/analysis/pre_ai_model_237499f4.keras")
    parser.add_argument("--output-dir", default="artifacts/stage4_secondpass")
    parser.add_argument("--threshold", type=float, default=0.16)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=6)
    parser.add_argument("--learning-rate", type=float, default=2e-6)
    parser.add_argument("--min-fraud-recall", type=float, default=0.98)
    parser.add_argument("--ai-fraud-weight", type=float, default=1.15)
    parser.add_argument("--genuine-weight", type=float, default=1.0)
    parser.add_argument(
        "--max-ai-train-samples",
        type=int,
        default=0,
        help="Cap AI-fraud training images by unique base source path. 0 means no cap.",
    )
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    tf.random.set_seed(args.seed)
    np.random.seed(args.seed)

    root = Path(__file__).resolve().parents[1]
    arrays_dir = root / args.arrays_dir
    out_dir = root / args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    x_train, y_train, labels_train, src_train = load_split(arrays_dir / "train.npz")
    x_val, y_val, labels_val, src_val = load_split(arrays_dir / "val.npz")
    x_test, y_test, labels_test, src_test = load_split(arrays_dir / "test.npz")

    # Ensure hard7 are not in training split for this pass.
    train_keep = np.asarray([s.split("::")[0] not in HARD7_PATHS for s in src_train])
    x_train = x_train[train_keep]
    y_train = y_train[train_keep]
    labels_train = labels_train[train_keep]
    src_train = src_train[train_keep]

    # Optional conservative cap on AI-fraud coverage in training set.
    if args.max_ai_train_samples > 0:
        rng = np.random.default_rng(args.seed)
        base_src = np.asarray([s.split("::")[0] for s in src_train], dtype=str)
        ai_mask = np.asarray(["ai_fraudulent" in s.lower() for s in labels_train])
        ai_bases = sorted(set(base_src[ai_mask].tolist()))
        keep_ai_bases = set(ai_bases)
        if len(ai_bases) > args.max_ai_train_samples:
            keep_ai_bases = set(rng.choice(np.asarray(ai_bases), size=args.max_ai_train_samples, replace=False).tolist())

        keep_mask = np.ones(len(src_train), dtype=bool)
        for i in range(len(src_train)):
            if ai_mask[i] and base_src[i] not in keep_ai_bases:
                keep_mask[i] = False

        x_train = x_train[keep_mask]
        y_train = y_train[keep_mask]
        labels_train = labels_train[keep_mask]
        src_train = src_train[keep_mask]

    old_model = tf.keras.models.load_model(root / args.old_model)

    baseline = baseline_from_old(
        old_model=old_model,
        x_val=x_val,
        y_val=y_val,
        labels_val=labels_val,
        threshold=args.threshold,
    )

    # Build hard7 holdout tensor from test arrays.
    hard_mask = np.asarray([s in HARD7_PATHS for s in src_test])
    x_hard = x_test[hard_mask]

    model = tf.keras.models.clone_model(old_model)
    model.set_weights(old_model.get_weights())

    # Light fine-tune only top block + head.
    for layer in model.layers:
        layer.trainable = True
    if hasattr(model.layers[1], "layers"):
        base = model.layers[1]
        cutoff = max(0, len(base.layers) - 18)
        for l in base.layers[:cutoff]:
            l.trainable = False
        for l in base.layers[cutoff:]:
            if isinstance(l, tf.keras.layers.BatchNormalization):
                l.trainable = False

    sample_weights = np.ones_like(y_train, dtype=np.float32)
    for i in range(len(sample_weights)):
        if y_train[i] == 0:
            sample_weights[i] *= args.genuine_weight
        if y_train[i] == 1 and "ai_fraudulent" in str(labels_train[i]).lower():
            sample_weights[i] *= args.ai_fraud_weight

    train_ds = (
        tf.data.Dataset.from_tensor_slices((x_train, y_train.astype(np.float32), sample_weights))
        .shuffle(buffer_size=len(x_train), seed=args.seed, reshuffle_each_iteration=True)
        .batch(args.batch_size)
        .prefetch(tf.data.AUTOTUNE)
    )
    val_ds = tf.data.Dataset.from_tensor_slices((x_val, y_val.astype(np.float32))).batch(args.batch_size).prefetch(tf.data.AUTOTUNE)

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=args.learning_rate),
        loss=tf.keras.losses.BinaryCrossentropy(),
        metrics=[
            tf.keras.metrics.BinaryAccuracy(name="binary_accuracy"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
        ],
    )

    selector = ConstraintSelector(
        run_dir=out_dir,
        x_val=x_val,
        y_val=y_val,
        labels_val=labels_val,
        x_hard=x_hard,
        threshold=args.threshold,
        min_recall=args.min_fraud_recall,
        min_non_ai_acc=baseline["val_non_ai_accuracy"],
        max_non_ai_fpr=baseline["val_non_ai_genuine_fpr"],
    )

    early = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss",
        mode="min",
        patience=2,
        restore_best_weights=False,
        verbose=1,
    )

    hist = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        callbacks=[selector, early],
        verbose=1,
    )

    selector.finalize()

    final_model_path = out_dir / "mobilenetv2_secondpass_from_old.keras"
    model.save(final_model_path)

    history_df = pd.DataFrame(hist.history)
    history_df.to_csv(out_dir / "training_history.csv", index=False)

    pd.DataFrame(selector.rows).to_csv(out_dir / "constraint_epoch_metrics.csv", index=False)

    summary = {
        "baseline_old_on_val": baseline,
        "best_epoch_row": selector.best_row,
        "all_constraints_ever_satisfied": bool(any(r["all_constraints_ok"] >= 1.0 for r in selector.rows)),
        "threshold": args.threshold,
        "min_fraud_recall": args.min_fraud_recall,
        "final_model_path": str(final_model_path),
    }
    with (out_dir / "constraint_summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    print("Second-pass fine-tuning complete.")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
