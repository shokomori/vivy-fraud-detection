from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import tensorflow as tf

from image_pipeline import preprocess_image


HARD_GENUINE_PATHS = [
    "dataset/iOSGenuine/gI_388.jpg",
    "dataset/iOSGenuine/gI_390.jpg",
    "dataset/iOSGenuine/gI_391.jpg",
]


def binary_from_label_text(labels: np.ndarray) -> np.ndarray:
    return np.asarray([1 if "fraud" in str(x).lower() else 0 for x in labels], dtype=np.float32)


def load_split_npz(npz_path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    if not npz_path.exists():
        raise FileNotFoundError(f"Split file not found: {npz_path}")

    data = np.load(npz_path, allow_pickle=True)
    images = data["images"].astype(np.float32)
    labels_text = data["labels_text"].astype(str)
    labels_binary = binary_from_label_text(labels_text)
    source_paths = data["source_paths"].astype(str)
    return images, labels_binary, labels_text, source_paths


def cap_ai_fraud_share(
    x: np.ndarray,
    y: np.ndarray,
    labels_text: np.ndarray,
    source_paths: np.ndarray,
    max_ai_ratio_within_fraud: float,
    seed: int,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)

    is_fraud = y == 1
    is_ai_fraud = np.asarray(["ai_fraudulent" in s.lower() for s in labels_text])

    ai_idx = np.where(is_fraud & is_ai_fraud)[0]
    non_ai_fraud_idx = np.where(is_fraud & ~is_ai_fraud)[0]
    genuine_idx = np.where(~is_fraud)[0]

    if len(ai_idx) == 0:
        keep_idx = np.concatenate([genuine_idx, non_ai_fraud_idx])
        keep_idx.sort()
        return x[keep_idx], y[keep_idx], labels_text[keep_idx], source_paths[keep_idx]

    allowed_ai = int((max_ai_ratio_within_fraud / max(1e-9, 1.0 - max_ai_ratio_within_fraud)) * len(non_ai_fraud_idx))
    allowed_ai = max(1, min(len(ai_idx), allowed_ai))

    keep_ai_idx = rng.choice(ai_idx, size=allowed_ai, replace=False)

    keep_idx = np.concatenate([genuine_idx, non_ai_fraud_idx, keep_ai_idx])
    keep_idx.sort()

    return x[keep_idx], y[keep_idx], labels_text[keep_idx], source_paths[keep_idx]


def strong_augment(img: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    out = img.copy()

    brightness_delta = rng.uniform(-0.2, 0.2)
    contrast_scale = rng.uniform(0.75, 1.25)
    out = (out - 0.5) * contrast_scale + 0.5 + brightness_delta

    if rng.random() < 0.7:
        noise_std = rng.uniform(0.005, 0.02)
        out = out + rng.normal(0.0, noise_std, size=out.shape)

    out = np.clip(out, 0.0, 1.0)
    return out.astype(np.float32)


def append_hard_negatives(
    root: Path,
    x_train: np.ndarray,
    y_train: np.ndarray,
    labels_text: np.ndarray,
    source_paths: np.ndarray,
    hard_paths: List[str],
    augment_copies: int,
    seed: int,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)

    extra_images: List[np.ndarray] = []
    extra_y: List[float] = []
    extra_labels: List[str] = []
    extra_sources: List[str] = []

    for rel in hard_paths:
        src = root / rel
        base = preprocess_image(src)

        extra_images.append(base)
        extra_y.append(0.0)
        extra_labels.append("ios_genuine")
        extra_sources.append(f"{rel}::hardneg_base")

        for i in range(augment_copies):
            aug = strong_augment(base, rng)
            extra_images.append(aug)
            extra_y.append(0.0)
            extra_labels.append("ios_genuine")
            extra_sources.append(f"{rel}::hardneg_aug{i + 1}")

    if not extra_images:
        return x_train, y_train, labels_text, source_paths

    x_extra = np.stack(extra_images, axis=0).astype(np.float32)
    y_extra = np.asarray(extra_y, dtype=np.float32)
    labels_extra = np.asarray(extra_labels, dtype=str)
    src_extra = np.asarray(extra_sources, dtype=str)

    x_out = np.concatenate([x_train, x_extra], axis=0)
    y_out = np.concatenate([y_train, y_extra], axis=0)
    labels_out = np.concatenate([labels_text, labels_extra], axis=0)
    src_out = np.concatenate([source_paths, src_extra], axis=0)

    return x_out, y_out, labels_out, src_out


def make_sample_weights(
    y_train: np.ndarray,
    labels_text: np.ndarray,
    source_paths: np.ndarray,
    genuine_weight: float,
    ai_fraud_weight: float,
    hard_negative_weight: float,
) -> np.ndarray:
    weights = np.ones_like(y_train, dtype=np.float32)

    for i in range(len(weights)):
        label = str(labels_text[i]).lower()
        src = str(source_paths[i]).lower()
        yi = int(y_train[i])

        if yi == 0:
            weights[i] = genuine_weight
        else:
            weights[i] = 1.0

        if yi == 1 and "ai_fraudulent" in label:
            weights[i] *= ai_fraud_weight

        if "::hardneg_" in src:
            weights[i] = hard_negative_weight

    return weights


def build_datasets(
    x_train: np.ndarray,
    y_train: np.ndarray,
    sample_weights: np.ndarray,
    x_val: np.ndarray,
    y_val: np.ndarray,
    x_test: np.ndarray,
    y_test: np.ndarray,
    batch_size: int,
    seed: int,
):
    train_ds = (
        tf.data.Dataset.from_tensor_slices((x_train, y_train, sample_weights))
        .shuffle(buffer_size=len(x_train), seed=seed, reshuffle_each_iteration=True)
        .batch(batch_size)
        .prefetch(tf.data.AUTOTUNE)
    )

    val_ds = tf.data.Dataset.from_tensor_slices((x_val, y_val)).batch(batch_size).prefetch(tf.data.AUTOTUNE)
    test_ds = tf.data.Dataset.from_tensor_slices((x_test, y_test)).batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return train_ds, val_ds, test_ds


def build_model(input_shape: Tuple[int, int, int], dense_units: int, dropout: float):
    base_model = tf.keras.applications.MobileNetV2(
        input_shape=input_shape,
        include_top=False,
        weights="imagenet",
    )
    base_model.trainable = False

    augmentation = tf.keras.Sequential(
        [
            tf.keras.layers.RandomBrightness(0.08),
            tf.keras.layers.RandomContrast(0.12),
        ],
        name="light_aug",
    )

    inputs = tf.keras.Input(shape=input_shape)
    x = augmentation(inputs)
    x = base_model(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dense(dense_units, activation="relu")(x)
    x = tf.keras.layers.Dropout(dropout)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid")(x)

    model = tf.keras.Model(inputs, outputs)
    return model, base_model


def compile_model(model: tf.keras.Model, learning_rate: float, focal_alpha: float, focal_gamma: float) -> None:
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss=tf.keras.losses.BinaryFocalCrossentropy(alpha=focal_alpha, gamma=focal_gamma),
        metrics=[
            tf.keras.metrics.BinaryAccuracy(name="binary_accuracy"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
        ],
    )


def merge_histories(history_a: tf.keras.callbacks.History, history_b: tf.keras.callbacks.History) -> Dict[str, List[float]]:
    merged: Dict[str, List[float]] = {}
    keys = set(history_a.history.keys()).union(set(history_b.history.keys()))
    for key in keys:
        merged[key] = list(history_a.history.get(key, [])) + list(history_b.history.get(key, []))
    return merged


def plot_history(history: Dict[str, List[float]], output_path: Path, head_epochs_run: int) -> None:
    epochs = range(1, len(history["loss"]) + 1)

    plt.figure(figsize=(12, 5))

    plt.subplot(1, 2, 1)
    plt.plot(epochs, history["loss"], label="Train Loss")
    plt.plot(epochs, history["val_loss"], label="Val Loss")
    if head_epochs_run > 0:
        plt.axvline(head_epochs_run + 0.5, linestyle="--", linewidth=1, color="gray", label="Fine-tune start")
    plt.xlabel("Epoch")
    plt.ylabel("Loss")
    plt.title("Training vs Validation Loss")
    plt.legend()

    plt.subplot(1, 2, 2)
    plt.plot(epochs, history["binary_accuracy"], label="Train Accuracy")
    plt.plot(epochs, history["val_binary_accuracy"], label="Val Accuracy")
    if head_epochs_run > 0:
        plt.axvline(head_epochs_run + 0.5, linestyle="--", linewidth=1, color="gray", label="Fine-tune start")
    plt.xlabel("Epoch")
    plt.ylabel("Accuracy")
    plt.title("Training vs Validation Accuracy")
    plt.legend()

    plt.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(output_path, dpi=160)
    plt.close()


class GuardrailModelSelector(tf.keras.callbacks.Callback):
    def __init__(
        self,
        run_dir: Path,
        x_val: np.ndarray,
        y_val: np.ndarray,
        x_hard: np.ndarray,
        threshold_eval: float,
        val_genuine_fpr_ceiling: float,
    ):
        super().__init__()
        self.run_dir = run_dir
        self.x_val = x_val
        self.y_val = y_val.astype(np.int32)
        self.x_hard = x_hard
        self.threshold_eval = threshold_eval
        self.val_genuine_fpr_ceiling = val_genuine_fpr_ceiling

        self.best_score: Tuple[float, ...] | None = None
        self.best_weights: List[np.ndarray] | None = None
        self.best_summary: Dict[str, float] | None = None
        self.logs_rows: List[Dict[str, float]] = []

    def on_epoch_end(self, epoch: int, logs=None):
        logs = logs or {}
        p_val = self.model.predict(self.x_val, verbose=0).reshape(-1)
        p_hard = self.model.predict(self.x_hard, verbose=0).reshape(-1)

        y_pred = (p_val >= self.threshold_eval).astype(np.int32)

        genuine_mask = self.y_val == 0
        fraud_mask = self.y_val == 1

        fp = int(((y_pred == 1) & genuine_mask).sum())
        tn = int(((y_pred == 0) & genuine_mask).sum())
        tp = int(((y_pred == 1) & fraud_mask).sum())
        fn = int(((y_pred == 0) & fraud_mask).sum())

        val_genuine_fpr = float(fp / max(1, fp + tn))
        val_fraud_recall = float(tp / max(1, tp + fn))

        hard_ok_count = int((p_hard < self.threshold_eval).sum())
        hard_total = int(len(p_hard))
        hard_max_prob = float(p_hard.max())

        feasible = 1.0 if val_genuine_fpr <= self.val_genuine_fpr_ceiling else 0.0

        # Lexicographic objective under guardrails.
        score = (
            feasible,
            float(hard_ok_count / max(1, hard_total)),
            val_fraud_recall,
            -val_genuine_fpr,
            -hard_max_prob,
            -float(logs.get("val_loss", 1e9)),
        )

        row = {
            "epoch": float(epoch + 1),
            "val_genuine_fpr_at_eval_threshold": val_genuine_fpr,
            "val_fraud_recall_at_eval_threshold": val_fraud_recall,
            "hard_genuine_ok_count": float(hard_ok_count),
            "hard_genuine_total": float(hard_total),
            "hard_genuine_max_prob": hard_max_prob,
            "feasible": feasible,
            "val_loss": float(logs.get("val_loss", np.nan)),
        }
        self.logs_rows.append(row)

        if self.best_score is None or score > self.best_score:
            self.best_score = score
            self.best_weights = self.model.get_weights()
            self.best_summary = row

            ckpt_dir = self.run_dir / "checkpoints"
            ckpt_dir.mkdir(parents=True, exist_ok=True)
            self.model.save(ckpt_dir / "best_guardrail.keras")

    def finalize(self) -> None:
        if self.best_weights is not None:
            self.model.set_weights(self.best_weights)


def main() -> None:
    parser = argparse.ArgumentParser(description="Targeted Stage 4 retraining with guardrails")
    parser.add_argument("--arrays-dir", default="artifacts/stage3/arrays", help="Directory containing train/val/test NPZ")
    parser.add_argument("--output-dir", default="artifacts/stage4_targeted", help="Directory for Stage 4 outputs")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--head-epochs", type=int, default=10)
    parser.add_argument("--fine-tune-epochs", type=int, default=8)
    parser.add_argument("--head-lr", type=float, default=1e-3)
    parser.add_argument("--fine-tune-lr", type=float, default=8e-6)
    parser.add_argument("--fine-tune-last-layers", type=int, default=30)
    parser.add_argument("--patience", type=int, default=3)
    parser.add_argument("--dense-units", type=int, default=128)
    parser.add_argument("--dropout", type=float, default=0.35)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--max-ai-ratio-within-fraud", type=float, default=0.04)
    parser.add_argument("--hard-augment-copies", type=int, default=6)
    parser.add_argument("--genuine-weight", type=float, default=1.2)
    parser.add_argument("--ai-fraud-weight", type=float, default=0.7)
    parser.add_argument("--hard-negative-weight", type=float, default=3.0)
    parser.add_argument("--focal-alpha", type=float, default=0.35)
    parser.add_argument("--focal-gamma", type=float, default=2.0)
    parser.add_argument("--eval-threshold", type=float, default=0.16)
    parser.add_argument("--val-genuine-fpr-ceiling", type=float, default=0.03)
    args = parser.parse_args()

    tf.random.set_seed(args.seed)
    np.random.seed(args.seed)

    root = Path(__file__).resolve().parents[1]
    arrays_dir = root / args.arrays_dir
    run_dir = root / args.output_dir
    run_dir.mkdir(parents=True, exist_ok=True)

    x_train, y_train, train_labels_text, train_source_paths = load_split_npz(arrays_dir / "train.npz")
    x_val, y_val, val_labels_text, _ = load_split_npz(arrays_dir / "val.npz")
    x_test, y_test, _, _ = load_split_npz(arrays_dir / "test.npz")

    print(f"Original train set: X={x_train.shape}, y={y_train.shape}")

    x_train, y_train, train_labels_text, train_source_paths = cap_ai_fraud_share(
        x_train,
        y_train,
        train_labels_text,
        train_source_paths,
        max_ai_ratio_within_fraud=args.max_ai_ratio_within_fraud,
        seed=args.seed,
    )

    x_train, y_train, train_labels_text, train_source_paths = append_hard_negatives(
        root,
        x_train,
        y_train,
        train_labels_text,
        train_source_paths,
        hard_paths=HARD_GENUINE_PATHS,
        augment_copies=args.hard_augment_copies,
        seed=args.seed,
    )

    sample_weights = make_sample_weights(
        y_train=y_train,
        labels_text=train_labels_text,
        source_paths=train_source_paths,
        genuine_weight=args.genuine_weight,
        ai_fraud_weight=args.ai_fraud_weight,
        hard_negative_weight=args.hard_negative_weight,
    )

    print(f"Targeted train set: X={x_train.shape}, y={y_train.shape}")
    print(
        "Train class counts: "
        f"genuine={(y_train == 0).sum()}, fraud={(y_train == 1).sum()}, "
        f"ai_fraud={(np.asarray(['ai_fraudulent' in s.lower() for s in train_labels_text]) & (y_train == 1)).sum()}"
    )

    hard_images = []
    for rel in HARD_GENUINE_PATHS:
        hard_images.append(preprocess_image(root / rel))
    x_hard = np.stack(hard_images, axis=0).astype(np.float32)

    train_ds, val_ds, test_ds = build_datasets(
        x_train,
        y_train,
        sample_weights,
        x_val,
        y_val,
        x_test,
        y_test,
        batch_size=args.batch_size,
        seed=args.seed,
    )

    model, base_model = build_model(
        input_shape=(x_train.shape[1], x_train.shape[2], x_train.shape[3]),
        dense_units=args.dense_units,
        dropout=args.dropout,
    )

    selector = GuardrailModelSelector(
        run_dir=run_dir,
        x_val=x_val,
        y_val=y_val,
        x_hard=x_hard,
        threshold_eval=args.eval_threshold,
        val_genuine_fpr_ceiling=args.val_genuine_fpr_ceiling,
    )

    early_stop = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss",
        mode="min",
        patience=args.patience,
        restore_best_weights=False,
        verbose=1,
    )

    print("\nStage 1/2: Train head (targeted objective)")
    compile_model(model, learning_rate=args.head_lr, focal_alpha=args.focal_alpha, focal_gamma=args.focal_gamma)
    history_head = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.head_epochs,
        callbacks=[selector, early_stop],
        verbose=1,
    )

    print("\nStage 2/2: Fine-tune top layers (targeted objective)")
    base_model.trainable = True
    if args.fine_tune_last_layers > 0:
        cutoff = max(0, len(base_model.layers) - args.fine_tune_last_layers)
        for layer in base_model.layers[:cutoff]:
            layer.trainable = False
        for layer in base_model.layers[cutoff:]:
            if isinstance(layer, tf.keras.layers.BatchNormalization):
                layer.trainable = False

    compile_model(model, learning_rate=args.fine_tune_lr, focal_alpha=args.focal_alpha, focal_gamma=args.focal_gamma)
    history_fine = model.fit(
        train_ds,
        validation_data=val_ds,
        initial_epoch=len(history_head.history.get("loss", [])),
        epochs=len(history_head.history.get("loss", [])) + args.fine_tune_epochs,
        callbacks=[selector, early_stop],
        verbose=1,
    )

    selector.finalize()

    merged = merge_histories(history_head, history_fine)
    history_csv_path = run_dir / "training_history.csv"
    pd.DataFrame(merged).to_csv(history_csv_path, index=False)

    guardrail_csv = run_dir / "guardrail_epoch_metrics.csv"
    pd.DataFrame(selector.logs_rows).to_csv(guardrail_csv, index=False)

    if selector.best_summary is not None:
        with (run_dir / "guardrail_best_summary.json").open("w", encoding="utf-8") as f:
            json.dump(selector.best_summary, f, indent=2)

    plot_path = run_dir / "training_curves.png"
    plot_history(merged, output_path=plot_path, head_epochs_run=len(history_head.history.get("loss", [])))

    final_model_path = run_dir / "mobilenetv2_fraud_detector_targeted.keras"
    model.save(final_model_path)

    test_metrics = model.evaluate(test_ds, verbose=0)
    metric_names = model.metrics_names
    test_summary = {name: float(value) for name, value in zip(metric_names, test_metrics)}

    final_train_acc = float(merged["binary_accuracy"][-1])
    final_val_acc = float(merged["val_binary_accuracy"][-1])
    total_epochs_run = len(merged["loss"])

    print("\nTargeted training complete.")
    print(f"Final train accuracy: {final_train_acc:.4f}")
    print(f"Final val accuracy:   {final_val_acc:.4f}")
    print(f"Epochs actually run:  {total_epochs_run}")
    print(f"Final model saved:    {final_model_path}")
    print(f"History CSV saved:    {history_csv_path}")
    print(f"Guardrail CSV saved:  {guardrail_csv}")
    print(f"Curves plot saved:    {plot_path}")
    print(f"Test metrics:         {test_summary}")


if __name__ == "__main__":
    main()
