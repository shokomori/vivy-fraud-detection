from __future__ import annotations

import argparse
from pathlib import Path

import tensorflow as tf


def convert_to_tflite(model_path: Path, output_path: Path, quantization: str) -> Path:
    model = tf.keras.models.load_model(model_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Always enable default optimization for mobile.
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    if quantization == "float16":
        converter.target_spec.supported_types = [tf.float16]
    elif quantization == "dynamic":
        # Dynamic range quantization uses default optimization without calibration data.
        pass
    elif quantization == "none":
        converter.optimizations = []
    else:
        raise ValueError(f"Unsupported quantization mode: {quantization}")

    tflite_model = converter.convert()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(tflite_model)
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Stage 6 TFLite conversion")
    parser.add_argument(
        "--keras-model",
        default="artifacts/stage4/mobilenetv2_fraud_detector.keras",
        help="Path to trained Keras model",
    )
    parser.add_argument(
        "--output-dir",
        default="artifacts/stage6",
        help="Directory to save converted TFLite model",
    )
    parser.add_argument(
        "--quantization",
        choices=["dynamic", "float16", "none"],
        default="float16",
        help="Quantization mode for TFLite conversion",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    keras_model = root / args.keras_model
    if not keras_model.exists():
        raise FileNotFoundError(f"Keras model not found: {keras_model}")

    out_dir = root / args.output_dir
    output_name = f"mobilenetv2_fraud_detector_{args.quantization}.tflite"
    output_path = out_dir / output_name

    saved = convert_to_tflite(keras_model, output_path, quantization=args.quantization)
    size_mb = saved.stat().st_size / (1024 * 1024)

    print("Stage 6 conversion complete.")
    print(f"Keras source model: {keras_model}")
    print(f"TFLite model path:  {saved}")
    print(f"TFLite size (MB):   {size_mb:.3f}")
    print(f"Quantization mode:  {args.quantization}")


if __name__ == "__main__":
    main()
