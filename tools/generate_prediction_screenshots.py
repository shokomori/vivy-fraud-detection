from __future__ import annotations

import argparse
from pathlib import Path
from typing import List, Sequence, Tuple

import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf

from image_pipeline import preprocess_image


def collect_images(input_dir: Path, extensions: Sequence[str]) -> List[Path]:
    exts = {e.lower() for e in extensions}
    return sorted([p for p in input_dir.rglob("*") if p.is_file() and p.suffix.lower() in exts])


def load_model(model_path: Path):
    suffix = model_path.suffix.lower()
    if suffix in {".keras", ".h5"}:
        model = tf.keras.models.load_model(model_path)
        return ("keras", model)
    if suffix == ".tflite":
        interpreter = tf.lite.Interpreter(model_path=str(model_path))
        interpreter.allocate_tensors()
        return ("tflite", interpreter)
    raise ValueError("Unsupported model format. Use .keras, .h5, or .tflite")


def run_inference(model_kind: str, model_obj, image_batch: np.ndarray) -> np.ndarray:
    if model_kind == "keras":
        preds = model_obj.predict(image_batch, verbose=0)
        return np.asarray(preds)

    input_details = model_obj.get_input_details()[0]
    output_details = model_obj.get_output_details()[0]

    input_data = image_batch.astype(input_details["dtype"])
    model_obj.set_tensor(input_details["index"], input_data)
    model_obj.invoke()
    preds = model_obj.get_tensor(output_details["index"])
    return np.asarray(preds)


def fraud_probability(raw_pred: np.ndarray, class_names: List[str], fraud_index: int) -> float:
    pred = np.squeeze(raw_pred)

    if pred.ndim == 0:
        return float(pred)

    if pred.ndim == 1 and pred.shape[0] == 1:
        return float(pred[0])

    if pred.ndim == 1 and pred.shape[0] == 2:
        probs = pred if np.isclose(np.sum(pred), 1.0, atol=1e-3) else tf.nn.softmax(pred).numpy()
        return float(probs[fraud_index])

    if pred.ndim == 1 and pred.shape[0] > 2:
        probs = pred if np.isclose(np.sum(pred), 1.0, atol=1e-3) else tf.nn.softmax(pred).numpy()
        if class_names:
            fraud_idxs = [i for i, name in enumerate(class_names) if "fraud" in name.lower()]
            if fraud_idxs:
                return float(np.sum(probs[fraud_idxs]))
        return float(probs[fraud_index])

    raise ValueError(f"Unexpected prediction shape: {raw_pred.shape}")


def save_annotated(image_rgb: np.ndarray, title: str, subtitle: str, output_path: Path) -> None:
    fig = plt.figure(figsize=(6, 8), dpi=150)
    ax = fig.add_subplot(111)
    ax.imshow(np.clip(image_rgb, 0.0, 1.0))
    ax.axis("off")
    ax.set_title(title, fontsize=14, pad=12)
    fig.text(0.5, 0.03, subtitle, ha="center", fontsize=12)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate screenshot-style prediction images")
    parser.add_argument("--model", required=True, help="Path to trained model (.keras/.h5/.tflite)")
    parser.add_argument("--input-dir", required=True, help="Directory of images to score")
    parser.add_argument("--output-dir", default="artifacts/prediction_screenshots", help="Directory to save PNG outputs")
    parser.add_argument("--threshold", type=float, default=0.5, help="Fraud threshold")
    parser.add_argument("--limit", type=int, default=20, help="Max images to process")
    parser.add_argument("--img-size", type=int, default=224, help="Input image width/height")
    parser.add_argument(
        "--class-names",
        default="",
        help="Comma-separated class names for multi-class models (e.g. android_fraudulent,android_genuine,ios_fraudulent,ios_genuine)",
    )
    parser.add_argument("--fraud-index", type=int, default=1, help="Fraud index fallback for 2+ class outputs")
    args = parser.parse_args()

    model_path = Path(args.model)
    input_dir = Path(args.input_dir)
    output_dir = Path(args.output_dir)

    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")
    if not input_dir.exists():
        raise FileNotFoundError(f"Input dir not found: {input_dir}")

    class_names = [c.strip() for c in args.class_names.split(",") if c.strip()]

    image_paths = collect_images(input_dir, extensions=[".jpg", ".jpeg", ".png", ".jfif", ".bmp", ".webp", ".tif", ".tiff"])
    if not image_paths:
        raise ValueError(f"No images found in {input_dir}")

    model_kind, model_obj = load_model(model_path)
    print(f"Loaded {model_kind} model: {model_path}")

    for idx, image_path in enumerate(image_paths[: args.limit], start=1):
        rgb_norm = preprocess_image(image_path, image_size=(args.img_size, args.img_size))
        pred = run_inference(model_kind, model_obj, np.expand_dims(rgb_norm, axis=0))
        p_fraud = fraud_probability(pred[0], class_names=class_names, fraud_index=args.fraud_index)

        predicted = "Fraudulent" if p_fraud >= args.threshold else "Genuine"
        confidence = p_fraud if predicted == "Fraudulent" else (1.0 - p_fraud)

        safe_name = image_path.stem.replace(" ", "_")
        out_path = output_dir / f"{safe_name}_pred.png"
        title = f"Prediction: {predicted}"
        subtitle = f"Confidence: {confidence * 100:.1f}% | Fraud probability: {p_fraud * 100:.1f}%"

        save_annotated(rgb_norm, title=title, subtitle=subtitle, output_path=out_path)
        print(f"[{idx}] {image_path.name} -> {predicted} ({confidence * 100:.1f}%) | saved {out_path}")

    print("Done generating screenshot-style prediction images.")


if __name__ == "__main__":
    main()
