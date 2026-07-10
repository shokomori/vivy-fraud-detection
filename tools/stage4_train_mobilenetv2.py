from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict, List, Tuple

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import tensorflow as tf


def binary_from_label_text(labels: np.ndarray) -> np.ndarray:
    return np.asarray([1 if "fraud" in str(x).lower() else 0 for x in labels], dtype=np.float32)


def load_split_npz(npz_path: Path, max_samples: int = 0) -> Tuple[np.ndarray, np.ndarray]:
    if not npz_path.exists():
        raise FileNotFoundError(f"Split file not found: {npz_path}")

    data = np.load(npz_path, allow_pickle=True)
    images = data["images"].astype(np.float32)

    if "labels_text" in data:
        labels_binary = binary_from_label_text(data["labels_text"])
    else:
        if "labels_int" not in data or "label_names" not in data:
            raise ValueError(f"{npz_path} must include labels_text or labels_int+label_names")
        label_names = [str(x) for x in data["label_names"]]
        labels_int = data["labels_int"].astype(int)
        text = np.asarray([label_names[i] for i in labels_int])
        labels_binary = binary_from_label_text(text)

    if max_samples > 0:
        images = images[:max_samples]
        labels_binary = labels_binary[:max_samples]

    return images, labels_binary


def build_datasets(
    x_train: np.ndarray,
    y_train: np.ndarray,
    x_val: np.ndarray,
    y_val: np.ndarray,
    x_test: np.ndarray,
    y_test: np.ndarray,
    batch_size: int,
    seed: int,
):
    train_ds = (
        tf.data.Dataset.from_tensor_slices((x_train, y_train))
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

    inputs = tf.keras.Input(shape=input_shape)
    x = base_model(inputs, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dense(dense_units, activation="relu")(x)
    x = tf.keras.layers.Dropout(dropout)(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid")(x)

    model = tf.keras.Model(inputs, outputs)
    return model, base_model


def compile_model(model: tf.keras.Model, learning_rate: float) -> None:
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss=tf.keras.losses.BinaryCrossentropy(),
        metrics=[tf.keras.metrics.BinaryAccuracy(name="binary_accuracy")],
    )


def make_callbacks(run_dir: Path, stage_name: str, patience: int) -> List[tf.keras.callbacks.Callback]:
    ckpt_dir = run_dir / "checkpoints"
    ckpt_dir.mkdir(parents=True, exist_ok=True)

    callbacks: List[tf.keras.callbacks.Callback] = [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(ckpt_dir / f"best_{stage_name}.keras"),
            monitor="val_loss",
            mode="min",
            save_best_only=True,
            verbose=1,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss",
            mode="min",
            patience=patience,
            restore_best_weights=True,
            verbose=1,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_binary_accuracy",
            mode="max",
            patience=patience,
            min_delta=1e-4,
            restore_best_weights=True,
            verbose=1,
        ),
    ]
    return callbacks


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


def main() -> None:
    parser = argparse.ArgumentParser(description="Stage 4 MobileNetV2 training (freeze then fine-tune)")
    parser.add_argument("--arrays-dir", default="artifacts/stage3/arrays", help="Directory containing train/val/test NPZ")
    parser.add_argument("--splits-dir", default="artifacts/stage3/splits", help="Directory containing split CSV files")
    parser.add_argument("--output-dir", default="artifacts/stage4", help="Directory for Stage 4 outputs")
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--head-epochs", type=int, default=12)
    parser.add_argument("--fine-tune-epochs", type=int, default=10)
    parser.add_argument("--head-lr", type=float, default=1e-3)
    parser.add_argument("--fine-tune-lr", type=float, default=1e-5)
    parser.add_argument("--fine-tune-last-layers", type=int, default=30)
    parser.add_argument("--patience", type=int, default=4, help="Early stopping patience")
    parser.add_argument("--dense-units", type=int, default=128)
    parser.add_argument("--dropout", type=float, default=0.3)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--max-samples", type=int, default=0, help="Optional cap per split for quick smoke tests")
    args = parser.parse_args()

    tf.random.set_seed(args.seed)
    np.random.seed(args.seed)

    root = Path(__file__).resolve().parents[1]
    arrays_dir = root / args.arrays_dir
    splits_dir = root / args.splits_dir
    run_dir = root / args.output_dir
    run_dir.mkdir(parents=True, exist_ok=True)

    label_contract = {
        "0": "Genuine",
        "1": "Fraudulent",
        "positive_class_for_metrics_and_threshold": 1,
    }
    print("Binary label encoding contract: 0=Genuine, 1=Fraudulent")
    pd.Series(label_contract).to_json(run_dir / "label_mapping.json", indent=2)

    for split_csv in ["train.csv", "val.csv", "test.csv"]:
        p = splits_dir / split_csv
        if p.exists():
            df = pd.read_csv(p)
            print(f"Found split metadata: {p} ({len(df)} rows)")

    x_train, y_train = load_split_npz(arrays_dir / "train.npz", max_samples=args.max_samples)
    x_val, y_val = load_split_npz(arrays_dir / "val.npz", max_samples=args.max_samples)
    x_test, y_test = load_split_npz(arrays_dir / "test.npz", max_samples=args.max_samples)

    print(f"Train set: X={x_train.shape}, y={y_train.shape}")
    print(f"Val set:   X={x_val.shape}, y={y_val.shape}")
    print(f"Test set:  X={x_test.shape}, y={y_test.shape}")

    train_ds, val_ds, test_ds = build_datasets(
        x_train,
        y_train,
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

    print("\nStage 1/2: Train classification head with MobileNetV2 base frozen")
    compile_model(model, learning_rate=args.head_lr)
    head_callbacks = make_callbacks(run_dir, "head", patience=args.patience)
    history_head = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.head_epochs,
        callbacks=head_callbacks,
        verbose=1,
    )

    print("\nStage 2/2: Fine-tune top MobileNetV2 layers with lower learning rate")
    base_model.trainable = True

    if args.fine_tune_last_layers > 0:
        cutoff = max(0, len(base_model.layers) - args.fine_tune_last_layers)
        for layer in base_model.layers[:cutoff]:
            layer.trainable = False
        for layer in base_model.layers[cutoff:]:
            if isinstance(layer, tf.keras.layers.BatchNormalization):
                layer.trainable = False

    compile_model(model, learning_rate=args.fine_tune_lr)
    fine_callbacks = make_callbacks(run_dir, "finetune", patience=args.patience)
    history_fine = model.fit(
        train_ds,
        validation_data=val_ds,
        initial_epoch=len(history_head.history.get("loss", [])),
        epochs=len(history_head.history.get("loss", [])) + args.fine_tune_epochs,
        callbacks=fine_callbacks,
        verbose=1,
    )

    merged = merge_histories(history_head, history_fine)

    history_csv_path = run_dir / "training_history.csv"
    pd.DataFrame(merged).to_csv(history_csv_path, index=False)

    plot_path = run_dir / "training_curves.png"
    plot_history(merged, output_path=plot_path, head_epochs_run=len(history_head.history.get("loss", [])))

    checkpoints_dir = run_dir / "checkpoints"
    best_finetune_path = checkpoints_dir / "best_finetune.keras"
    best_head_path = checkpoints_dir / "best_head.keras"

    export_source = best_finetune_path if best_finetune_path.exists() else best_head_path
    if not export_source.exists():
        raise FileNotFoundError(
            "No checkpoint was found to export final model. "
            f"Expected one of: {best_finetune_path} or {best_head_path}"
        )

    print(f"Exporting final model from best checkpoint: {export_source}")
    export_model = tf.keras.models.load_model(export_source)
    final_model_path = run_dir / "mobilenetv2_fraud_detector.keras"
    export_model.save(final_model_path)

    test_metrics = export_model.evaluate(test_ds, verbose=0)
    metric_names = export_model.metrics_names
    test_summary = {name: float(value) for name, value in zip(metric_names, test_metrics)}

    final_train_acc = float(merged["binary_accuracy"][-1])
    final_val_acc = float(merged["val_binary_accuracy"][-1])
    total_epochs_run = len(merged["loss"])

    print("\nTraining complete.")
    print(f"Final train accuracy: {final_train_acc:.4f}")
    print(f"Final val accuracy:   {final_val_acc:.4f}")
    print(f"Epochs actually run:  {total_epochs_run}")
    print(f"Final model saved:    {final_model_path}")
    print(f"History CSV saved:    {history_csv_path}")
    print(f"Curves plot saved:    {plot_path}")
    print(f"Label mapping saved:  {run_dir / 'label_mapping.json'}")
    print(f"Test metrics:         {test_summary}")


if __name__ == "__main__":
    main()
