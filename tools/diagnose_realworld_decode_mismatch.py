from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from bytelevel_diff_stage3_vs_app_semantics import (
    preprocess_android_opencv_semantics_with_meta,
)
from image_pipeline import preprocess_image


def _find_app_row(csv_path: Path, filename: str) -> dict[str, str] | None:
    if not csv_path.exists():
        return None
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if (row.get("filename") or "") == filename:
                return row
    return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Diagnose real-world image decode metadata and tensor alignment."
    )
    parser.add_argument("--image", required=True, help="Target image path")
    parser.add_argument(
        "--app-csv",
        default="",
        help="Optional app CSV path to attach app raw score and decoded size",
    )
    parser.add_argument(
        "--out-json",
        default="artifacts/debug_compare/proof5/realworld_decode_diagnostics.json",
        help="Output report JSON path",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    image_path = (root / args.image).resolve() if not Path(args.image).is_absolute() else Path(args.image)
    out_json = (root / args.out_json).resolve() if not Path(args.out_json).is_absolute() else Path(args.out_json)

    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    raw = image_path.read_bytes()
    file_sha256 = hashlib.sha256(raw).hexdigest()

    pil = Image.open(image_path)
    exif = pil.getexif()
    orientation = exif.get(274, 1) if exif else 1
    icc = pil.info.get("icc_profile")

    cv_color = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
    cv_unch = cv2.imread(str(image_path), cv2.IMREAD_UNCHANGED)
    cv_dec_color = cv2.imdecode(np.frombuffer(raw, dtype=np.uint8), cv2.IMREAD_COLOR)
    cv_dec_unch = cv2.imdecode(np.frombuffer(raw, dtype=np.uint8), cv2.IMREAD_UNCHANGED)

    if cv_color is None:
        raise ValueError(f"cv2.imread failed for: {image_path}")

    stage3 = preprocess_image(image_path).astype(np.float32)
    app_sem, app_sem_meta = preprocess_android_opencv_semantics_with_meta(image_path)
    app_sem = app_sem.astype(np.float32)

    diff = np.abs(stage3 - app_sem)

    app_row = None
    app_csv_path = None
    if args.app_csv:
        app_csv_path = (root / args.app_csv).resolve() if not Path(args.app_csv).is_absolute() else Path(args.app_csv)
        app_row = _find_app_row(app_csv_path, image_path.name)

    report = {
        "image": str(image_path),
        "filename": image_path.name,
        "file_sha256": file_sha256,
        "metadata": {
            "pil": {
                "format": pil.format,
                "mode": pil.mode,
                "size_wh": [pil.size[0], pil.size[1]],
                "bands": list(pil.getbands()),
                "has_alpha": "A" in pil.getbands(),
                "exif_orientation": int(orientation) if orientation is not None else None,
                "icc_profile_present": icc is not None,
                "icc_profile_bytes": len(icc) if icc is not None else 0,
            },
            "opencv": {
                "imread_color_shape": list(cv_color.shape),
                "imread_color_channels": int(cv_color.shape[2]) if len(cv_color.shape) == 3 else 1,
                "imread_unchanged_shape": list(cv_unch.shape) if cv_unch is not None else None,
                "imread_unchanged_channels": int(cv_unch.shape[2]) if cv_unch is not None and len(cv_unch.shape) == 3 else (1 if cv_unch is not None else None),
                "imdecode_color_shape": list(cv_dec_color.shape) if cv_dec_color is not None else None,
                "imdecode_unchanged_shape": list(cv_dec_unch.shape) if cv_dec_unch is not None else None,
            },
        },
        "tensor_compare_stage3_vs_app_semantics": {
            "shape_match": list(stage3.shape) == list(app_sem.shape),
            "byte_for_byte_equal": bool(np.array_equal(stage3, app_sem)),
            "allclose_atol_1e-6": bool(np.allclose(stage3, app_sem, atol=1e-6)),
            "mean_abs_diff": float(diff.mean()),
            "max_abs_diff": float(diff.max()),
        },
        "app_semantics_meta": app_sem_meta,
        "app_csv_context": {
            "app_csv": str(app_csv_path) if app_csv_path is not None else None,
            "matched_row": app_row,
        },
    }

    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"Saved report: {out_json}")


if __name__ == "__main__":
    main()
