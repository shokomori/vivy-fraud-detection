from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    export_dir = root / "artifacts/debug_compare/gA_145_flutter"
    tensor = np.fromfile(export_dir / "flutter_tensor_f32.bin", dtype=np.float32).reshape(224, 224, 3)

    with (export_dir / "flutter_preprocess_metadata.json").open("r", encoding="utf-8") as f:
        meta = json.load(f)

    x0 = int(meta["crop_box_with_padding"]["x0"])
    y0 = int(meta["crop_box_with_padding"]["y0"])
    x1 = int(meta["crop_box_with_padding"]["x1"])
    y1 = int(meta["crop_box_with_padding"]["y1"])

    bgr = cv2.imread(str(root / "dataset/AndroidGenuine/gA_145.jfif"))
    roi = bgr[y0 : y1 + 1, x0 : x1 + 1]
    flutter_roi_png = cv2.imread(str(export_dir / "flutter_roi.png"))

    if flutter_roi_png is not None and flutter_roi_png.shape == roi.shape:
        roi_cv2_rgb = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
        roi_flutter_rgb = cv2.cvtColor(flutter_roi_png, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
        roi_diff = np.abs(roi_cv2_rgb - roi_flutter_rgb)
        roi_diff_swapped = np.abs(roi_cv2_rgb[..., ::-1] - roi_flutter_rgb)
        print(
            "ROI pixel diff before resize: "
            f"mean_abs_diff={roi_diff.mean():.8f}, max_abs_diff={roi_diff.max():.8f}"
        )
        print(
            "ROI channel-swap check: "
            f"mean_abs_diff_if_cv2_rgb_reversed={roi_diff_swapped.mean():.8f}"
        )
    else:
        print("ROI comparison skipped (missing file or shape mismatch).")

    candidates = {
        "INTER_AREA": cv2.INTER_AREA,
        "INTER_LINEAR": cv2.INTER_LINEAR,
        "INTER_CUBIC": cv2.INTER_CUBIC,
        "INTER_NEAREST": cv2.INTER_NEAREST,
        "INTER_LANCZOS4": cv2.INTER_LANCZOS4,
    }

    print("Comparison against Flutter export tensor:")
    for name, mode in candidates.items():
        resized = cv2.resize(roi, (224, 224), interpolation=mode)
        rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
        d = np.abs(tensor - rgb)
        print(f"{name}: mean_abs_diff={d.mean():.8f}, max_abs_diff={d.max():.8f}")


if __name__ == "__main__":
    main()
