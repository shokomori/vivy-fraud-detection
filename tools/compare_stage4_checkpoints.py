from pathlib import Path
import gc

import numpy as np
import tensorflow as tf


def binary_from_label_text(labels):
    return np.asarray([1 if "fraud" in str(x).lower() else 0 for x in labels], dtype=np.float32)


def load_val():
    data = np.load("artifacts/stage3/arrays/val.npz", allow_pickle=True)
    x = data["images"].astype(np.float32)
    y = binary_from_label_text(data["labels_text"])
    return x, y


def evaluate_model(model_path: Path, x: np.ndarray, y: np.ndarray):
    tf.keras.backend.clear_session()
    model = tf.keras.models.load_model(model_path)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss=tf.keras.losses.BinaryCrossentropy(),
        metrics=[tf.keras.metrics.BinaryAccuracy(name="binary_accuracy")],
    )
    loss, acc = model.evaluate(x, y, verbose=0)
    del model
    tf.keras.backend.clear_session()
    gc.collect()
    return float(loss), float(acc)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    x, y = load_val()

    candidates = [
        root / "artifacts" / "stage4" / "checkpoints" / "best_head.keras",
        root / "artifacts" / "stage4" / "checkpoints" / "best_finetune.keras",
        root / "artifacts" / "stage4" / "mobilenetv2_fraud_detector.keras",
    ]

    for p in candidates:
        if not p.exists():
            print(f"MISSING: {p}")
            continue
        loss, acc = evaluate_model(p, x, y)
        print(f"{p.name}: val_loss={loss:.6f}, val_acc={acc:.6f}")


if __name__ == "__main__":
    main()
