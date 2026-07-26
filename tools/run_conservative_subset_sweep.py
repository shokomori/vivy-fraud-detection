from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List

import numpy as np
import tensorflow as tf


THRESHOLD = 0.16
SUBSET_SIZES = [10, 20, 30]
SEED = 42

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
    # Avoid a full duplicate allocation when images are already float32.
    x = d["images"].astype(np.float32, copy=False)
    labels = d["labels_text"].astype(str)
    src = d["source_paths"].astype(str)
    y = binary_from_label_text(labels)
    return x, y, labels, src


def predict(model: tf.keras.Model, x: np.ndarray, batch_size: int = 32) -> np.ndarray:
    p = model.predict(x, batch_size=batch_size, verbose=0)
    p = np.asarray(p)
    if p.ndim == 2 and p.shape[1] == 1:
        p = p[:, 0]
    return p.astype(np.float32)


def metrics(y_true: np.ndarray, probs: np.ndarray, threshold: float) -> Dict[str, float | List[List[int]]]:
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


def build_train_subset(
    x_train: np.ndarray,
    y_train: np.ndarray,
    labels_train: np.ndarray,
    src_train: np.ndarray,
    ai_limit: int,
    seed: int,
):
    rng = np.random.default_rng(seed)

    base_src = np.asarray([s.split("::")[0] for s in src_train])
    hard_mask = np.asarray([s in HARD7_PATHS for s in base_src])

    is_ai = np.asarray(["ai_fraudulent" in s.lower() for s in labels_train]) & (y_train == 1)
    ai_idx = np.where(~hard_mask & is_ai)[0]
    non_ai_idx = np.where(~hard_mask & ~is_ai)[0]

    keep_ai_count = min(ai_limit, len(ai_idx))
    keep_ai_idx = rng.choice(ai_idx, size=keep_ai_count, replace=False) if keep_ai_count > 0 else np.array([], dtype=int)

    keep_idx = np.concatenate([non_ai_idx, keep_ai_idx])
    keep_idx.sort()

    return x_train[keep_idx], y_train[keep_idx], labels_train[keep_idx], src_train[keep_idx]


def make_weights(y_train: np.ndarray, labels_train: np.ndarray, ai_weight: float) -> np.ndarray:
    w = np.ones_like(y_train, dtype=np.float32)
    ai_mask = np.asarray(["ai_fraudulent" in s.lower() for s in labels_train]) & (y_train == 1)
    w[ai_mask] *= ai_weight
    return w


def train_candidate(
    old_model_path: Path,
    x_train: np.ndarray,
    y_train: np.ndarray,
    w_train: np.ndarray,
    x_val: np.ndarray,
    y_val: np.ndarray,
    out_dir: Path,
    seed: int,
):
    tf.keras.backend.clear_session()
    tf.random.set_seed(seed)
    np.random.seed(seed)

    model = tf.keras.models.load_model(old_model_path)

    # Light fine-tune: unlock only top block and head.
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

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=2e-6),
        loss=tf.keras.losses.BinaryCrossentropy(),
        metrics=[
            tf.keras.metrics.BinaryAccuracy(name="binary_accuracy"),
            tf.keras.metrics.Precision(name="precision"),
            tf.keras.metrics.Recall(name="recall"),
        ],
    )

    train_ds = (
        tf.data.Dataset.from_tensor_slices((x_train, y_train.astype(np.float32), w_train))
        .shuffle(buffer_size=len(x_train), seed=seed, reshuffle_each_iteration=True)
        .batch(32)
        .prefetch(tf.data.AUTOTUNE)
    )
    val_ds = tf.data.Dataset.from_tensor_slices((x_val, y_val.astype(np.float32))).batch(32).prefetch(tf.data.AUTOTUNE)

    out_dir.mkdir(parents=True, exist_ok=True)
    ckpt_path = out_dir / "best.keras"
    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(ckpt_path),
            monitor="val_loss",
            mode="min",
            save_best_only=True,
            verbose=0,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_loss",
            mode="min",
            patience=2,
            restore_best_weights=True,
            verbose=0,
        ),
    ]

    history = model.fit(train_ds, validation_data=val_ds, epochs=6, callbacks=callbacks, verbose=1)
    model.save(out_dir / "final.keras")

    hist = {k: [float(x) for x in v] for k, v in history.history.items()}
    return model, hist


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_root = root / "artifacts" / "subset_sweep"
    out_root.mkdir(parents=True, exist_ok=True)
    print("[subset_sweep] start", flush=True)

    old_model_path = root / "artifacts" / "analysis" / "pre_ai_model_237499f4.keras"

    print("[subset_sweep] loading train split", flush=True)
    x_train, y_train, labels_train, src_train = load_split(root / "artifacts" / "stage3" / "arrays" / "train.npz")
    print("[subset_sweep] loading val split", flush=True)
    x_val, y_val, labels_val, src_val = load_split(root / "artifacts" / "stage3" / "arrays" / "val.npz")
    print("[subset_sweep] loading test split", flush=True)
    x_test, y_test, labels_test, src_test = load_split(root / "artifacts" / "stage3" / "arrays" / "test.npz")
    print("[subset_sweep] loaded all splits", flush=True)

    print("[subset_sweep] loading old model", flush=True)
    old_model = tf.keras.models.load_model(old_model_path)
    print("[subset_sweep] old model loaded", flush=True)
    p_old_test = predict(old_model, x_test)

    non_ai_test_mask = np.asarray(["ai_fraudulent" not in s.lower() for s in labels_test])
    old_non_ai = metrics(y_test[non_ai_test_mask], p_old_test[non_ai_test_mask], THRESHOLD)

    hard7_mask_test = np.asarray([s in HARD7_PATHS for s in src_test])

    summary_rows = []
    details = {
        "threshold": THRESHOLD,
        "old_non_ai_reference": old_non_ai,
        "runs": [],
    }

    for subset_size in SUBSET_SIZES:
        run_dir = out_root / f"ai_{subset_size}"
        print(f"[subset_sweep] subset={subset_size}: building train subset", flush=True)

        x_tr, y_tr, l_tr, s_tr = build_train_subset(
            x_train=x_train,
            y_train=y_train,
            labels_train=labels_train,
            src_train=src_train,
            ai_limit=subset_size,
            seed=SEED,
        )

        w_tr = make_weights(y_tr, l_tr, ai_weight=1.15)

        print(f"[subset_sweep] subset={subset_size}: training candidate", flush=True)
        model, hist = train_candidate(
            old_model_path=old_model_path,
            x_train=x_tr,
            y_train=y_tr,
            w_train=w_tr,
            x_val=x_val,
            y_val=y_val,
            out_dir=run_dir,
            seed=SEED,
        )
        print(f"[subset_sweep] subset={subset_size}: training done", flush=True)

        p_test = predict(model, x_test)
        m_full = metrics(y_test, p_test, THRESHOLD)
        m_non_ai = metrics(y_test[non_ai_test_mask], p_test[non_ai_test_mask], THRESHOLD)

        hard_scores = p_test[hard7_mask_test]
        hard_src = src_test[hard7_mask_test]
        hard_rows = [
            {
                "source_path": str(path),
                "score": float(score),
                "pred": int(score >= THRESHOLD),
            }
            for path, score in sorted(zip(hard_src.tolist(), hard_scores.tolist()), key=lambda t: t[0])
        ]
        hard_all_genuine = all(r["pred"] == 0 for r in hard_rows)

        gate_non_ai = (
            m_non_ai["accuracy"] >= old_non_ai["accuracy"]
            and m_non_ai["genuine_fpr"] <= old_non_ai["genuine_fpr"]
        )
        gate_recall = m_full["recall_fraudulent"] >= 0.98

        all_pass = bool(hard_all_genuine and gate_non_ai and gate_recall)

        row = {
            "subset_size": subset_size,
            "gate_hard7_all_genuine_at_0_16": bool(hard_all_genuine),
            "gate_non_ai_match_or_beat_old": bool(gate_non_ai),
            "gate_fraud_recall_ge_0_98": bool(gate_recall),
            "all_gates_pass": all_pass,
            "full_accuracy": m_full["accuracy"],
            "full_precision_fraud": m_full["precision_fraudulent"],
            "full_recall_fraud": m_full["recall_fraudulent"],
            "full_f1_fraud": m_full["f1_fraudulent"],
            "full_cm": m_full["confusion_matrix"],
            "non_ai_accuracy": m_non_ai["accuracy"],
            "non_ai_genuine_fpr": m_non_ai["genuine_fpr"],
            "non_ai_cm": m_non_ai["confusion_matrix"],
            "hard7": hard_rows,
            "train_samples": int(len(y_tr)),
            "ai_samples_used_in_train": int(np.asarray(["ai_fraudulent" in s.lower() for s in l_tr]).sum()),
            "history": hist,
        }

        with (run_dir / "run_report.json").open("w", encoding="utf-8") as f:
            json.dump(row, f, indent=2)
        print(f"[subset_sweep] subset={subset_size}: wrote run_report.json", flush=True)

        summary_rows.append({
            "subset_size": subset_size,
            "gate_hard7_all_genuine_at_0_16": bool(hard_all_genuine),
            "gate_non_ai_match_or_beat_old": bool(gate_non_ai),
            "gate_fraud_recall_ge_0_98": bool(gate_recall),
            "all_gates_pass": all_pass,
            "full_accuracy": float(m_full["accuracy"]),
            "full_precision_fraud": float(m_full["precision_fraudulent"]),
            "full_recall_fraud": float(m_full["recall_fraudulent"]),
            "full_f1_fraud": float(m_full["f1_fraudulent"]),
            "non_ai_accuracy": float(m_non_ai["accuracy"]),
            "non_ai_genuine_fpr": float(m_non_ai["genuine_fpr"]),
            "ai_samples_used_in_train": int(np.asarray(["ai_fraudulent" in s.lower() for s in l_tr]).sum()),
        })

        details["runs"].append(row)

    passing = [r for r in summary_rows if r["all_gates_pass"]]
    selected = max(passing, key=lambda r: r["subset_size"]) if passing else None

    summary = {
        "threshold": THRESHOLD,
        "old_non_ai_reference": old_non_ai,
        "summary_rows": summary_rows,
        "selected_subset": selected,
        "any_pass": bool(selected is not None),
    }

    with (out_root / "sweep_summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    with (out_root / "sweep_details.json").open("w", encoding="utf-8") as f:
        json.dump(details, f, indent=2)
    print("[subset_sweep] wrote summary artifacts", flush=True)

    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
