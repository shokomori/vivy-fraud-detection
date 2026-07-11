from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

try:
    import cv2
except ModuleNotFoundError:
    cv2 = None  # type: ignore[assignment]

try:
    import tensorflow as tf
except ModuleNotFoundError:
    tf = None  # type: ignore[assignment]


def _require_runtime_deps() -> None:
    missing: list[str] = []
    if cv2 is None:
        missing.append("opencv-python")
    if tf is None:
        missing.append("tensorflow")
    if missing:
        joined = ", ".join(missing)
        raise ModuleNotFoundError(
            f"Missing required package(s): {joined}. Install dependencies in the active Python environment first."
        )


def _preprocess_image(image_path: Path) -> np.ndarray:
    from image_pipeline import preprocess_image

    return preprocess_image(image_path)


@dataclass
class ScoredRow:
    filename: str
    app_result_type: str
    app_raw_score: float
    threshold: float
    image_path: str
    image_ext: str
    width: int
    height: int
    aspect_ratio: float
    long_edge: int
    file_size_kb: float
    python_stage3_score: float
    abs_delta: float
    expected_file_sha256: str | None
    matched_file_sha256: str
    hash_match: bool | None
    app_label_from_score: str
    python_label_from_score: str
    verdict: str


def _file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _normalize_hash(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip().lower()
    if not text:
        return None
    if len(text) != 64:
        return None
    try:
        int(text, 16)
    except ValueError:
        return None
    return text


def _find_image_by_filename(images_root: Path, filename: str, expected_hash: str | None) -> Path | None:
    matches = list(images_root.rglob(filename))
    if not matches:
        return None

    if expected_hash is not None:
        for p in matches:
            if _file_sha256(p) == expected_hash:
                return p
        return None

    # Prefer shortest relative path if duplicates exist.
    matches.sort(key=lambda p: len(str(p.relative_to(images_root))))
    return matches[0]


def _read_dims(path: Path) -> tuple[int, int]:
    img = cv2.imread(str(path))
    if img is None:
        raise ValueError(f"Unable to read image: {path}")
    h, w = img.shape[:2]
    return w, h


def _score_with_tflite(interpreter: tf.lite.Interpreter, arr_hwc: np.ndarray) -> float:
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    x = arr_hwc[np.newaxis, ...].astype(np.float32)
    interpreter.set_tensor(input_details["index"], x)
    interpreter.invoke()
    out = interpreter.get_tensor(output_details["index"]).reshape(-1)
    return float(out[0])


def _label_from_score(score: float, threshold: float) -> str:
    return "fraudulent" if score >= threshold else "genuine"


def _verdict(abs_delta: float, tolerance: float) -> str:
    if abs_delta > tolerance:
        return "possible_app_preprocess_mismatch"
    return "model_gap_or_data_shift"


def _safe_float(value: Any, fallback: float) -> float:
    try:
        return float(value)
    except Exception:
        return fallback


def _dataset_profile(dataset_root: Path) -> dict[str, Any]:
    exts = {".jpg", ".jpeg", ".jfif", ".png", ".webp"}
    paths = [p for p in dataset_root.rglob("*") if p.suffix.lower() in exts]
    rows: list[dict[str, float]] = []

    for p in paths:
        try:
            w, h = _read_dims(p)
        except Exception:
            continue
        rows.append(
            {
                "width": float(w),
                "height": float(h),
                "aspect_ratio": float(w / max(h, 1)),
                "long_edge": float(max(w, h)),
                "size_kb": float(p.stat().st_size / 1024.0),
            }
        )

    if not rows:
        return {
            "count": 0,
            "note": "No dataset images readable for profile.",
        }

    df = pd.DataFrame(rows)
    return {
        "count": int(len(df)),
        "aspect_ratio_mean": float(df["aspect_ratio"].mean()),
        "aspect_ratio_p10": float(df["aspect_ratio"].quantile(0.10)),
        "aspect_ratio_p90": float(df["aspect_ratio"].quantile(0.90)),
        "long_edge_mean": float(df["long_edge"].mean()),
        "long_edge_p10": float(df["long_edge"].quantile(0.10)),
        "long_edge_p90": float(df["long_edge"].quantile(0.90)),
        "size_kb_mean": float(df["size_kb"].mean()),
        "size_kb_p10": float(df["size_kb"].quantile(0.10)),
        "size_kb_p90": float(df["size_kb"].quantile(0.90)),
    }


def _realworld_profile(rows: list[ScoredRow]) -> dict[str, Any]:
    if not rows:
        return {
            "count": 0,
            "note": "No real-world rows scored.",
        }

    df = pd.DataFrame([asdict(r) for r in rows])
    lower_names = df["filename"].str.lower()

    screenshot_hits = lower_names.str.contains("screenshot|screen|capture").sum()
    forwarded_hits = lower_names.str.contains("forward|received|whatsapp|messenger|telegram").sum()

    return {
        "count": int(len(df)),
        "extensions": df["image_ext"].value_counts().to_dict(),
        "aspect_ratio_mean": float(df["aspect_ratio"].mean()),
        "aspect_ratio_p10": float(df["aspect_ratio"].quantile(0.10)),
        "aspect_ratio_p90": float(df["aspect_ratio"].quantile(0.90)),
        "long_edge_mean": float(df["long_edge"].mean()),
        "long_edge_p10": float(df["long_edge"].quantile(0.10)),
        "long_edge_p90": float(df["long_edge"].quantile(0.90)),
        "size_kb_mean": float(df["file_size_kb"].mean()),
        "size_kb_p10": float(df["file_size_kb"].quantile(0.10)),
        "size_kb_p90": float(df["file_size_kb"].quantile(0.90)),
        "heuristic_direct_screenshot_name_hits": int(screenshot_hits),
        "heuristic_forwarded_or_reshared_name_hits": int(forwarded_hits),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare app raw scores vs Python Stage 3+TFLite scores for real-world images."
    )
    parser.add_argument(
        "--app-csv",
        required=True,
        help="CSV exported from app clipboard. Supports hash columns like file_sha256 for strict matching.",
    )
    parser.add_argument(
        "--images-dir",
        required=True,
        help="Directory containing the real-world images referenced by filename.",
    )
    parser.add_argument(
        "--model",
        default="artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite",
        help="Relative path to TFLite model.",
    )
    parser.add_argument(
        "--dataset-root",
        default="dataset",
        help="Dataset root used to profile train/test data distribution for context.",
    )
    parser.add_argument(
        "--delta-tolerance",
        type=float,
        default=0.01,
        help="Absolute score delta tolerance before flagging app-side mismatch.",
    )
    parser.add_argument(
        "--out-json",
        default="artifacts/debug_compare/realworld_score_comparison.json",
        help="Output report path.",
    )
    args = parser.parse_args()
    _require_runtime_deps()

    root = Path(__file__).resolve().parents[1]
    app_csv_path = (root / args.app_csv).resolve() if not Path(args.app_csv).is_absolute() else Path(args.app_csv)
    images_dir = (root / args.images_dir).resolve() if not Path(args.images_dir).is_absolute() else Path(args.images_dir)
    model_path = (root / args.model).resolve() if not Path(args.model).is_absolute() else Path(args.model)
    dataset_root = (root / args.dataset_root).resolve() if not Path(args.dataset_root).is_absolute() else Path(args.dataset_root)
    out_json = (root / args.out_json).resolve() if not Path(args.out_json).is_absolute() else Path(args.out_json)

    if not app_csv_path.exists():
        raise FileNotFoundError(f"App CSV not found: {app_csv_path}")
    if not images_dir.exists():
        raise FileNotFoundError(f"Images directory not found: {images_dir}")
    if not model_path.exists():
        raise FileNotFoundError(f"Model not found: {model_path}")

    app_df = pd.read_csv(app_csv_path)
    required = {"filename", "result_type", "raw_score", "threshold"}
    if not required.issubset(app_df.columns):
        raise ValueError(f"App CSV missing required columns: {required}")

    # Keep only rows where app produced a raw numeric score.
    app_df = app_df.copy()
    app_df["raw_score"] = pd.to_numeric(app_df["raw_score"], errors="coerce")
    app_df = app_df.dropna(subset=["raw_score"])

    if app_df.empty:
        raise ValueError("No rows with raw_score in app CSV. Analyze at least one scored receipt first.")

    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()

    scored_rows: list[ScoredRow] = []
    missing_files: list[str] = []
    hash_missing_or_mismatch: list[str] = []

    for row in app_df.itertuples(index=False):
        filename = str(getattr(row, "filename"))
        expected_hash = _normalize_hash(getattr(row, "file_sha256", None))
        resolved = _find_image_by_filename(images_dir, filename, expected_hash)
        if resolved is None:
            if expected_hash is not None:
                hash_missing_or_mismatch.append(filename)
            missing_files.append(filename)
            continue

        arr = _preprocess_image(resolved).astype(np.float32)
        py_score = _score_with_tflite(interpreter, arr)
        app_score = float(getattr(row, "raw_score"))
        threshold = _safe_float(getattr(row, "threshold"), 0.16)
        delta = abs(app_score - py_score)
        w, h = _read_dims(resolved)
        actual_hash = _file_sha256(resolved)
        hash_match = None if expected_hash is None else (actual_hash == expected_hash)

        scored_rows.append(
            ScoredRow(
                filename=filename,
                app_result_type=str(getattr(row, "result_type")),
                app_raw_score=app_score,
                threshold=threshold,
                image_path=str(resolved),
                image_ext=resolved.suffix.lower(),
                width=w,
                height=h,
                aspect_ratio=float(w / max(h, 1)),
                long_edge=max(w, h),
                file_size_kb=float(resolved.stat().st_size / 1024.0),
                python_stage3_score=py_score,
                abs_delta=delta,
                expected_file_sha256=expected_hash,
                matched_file_sha256=actual_hash,
                hash_match=hash_match,
                app_label_from_score=_label_from_score(app_score, threshold),
                python_label_from_score=_label_from_score(py_score, threshold),
                verdict=_verdict(delta, args.delta_tolerance),
            )
        )

    if not scored_rows:
        raise ValueError("No matched images were found by filename in images-dir.")

    scored_df = pd.DataFrame([asdict(r) for r in scored_rows])
    app_mismatch_count = int((scored_df["verdict"] == "possible_app_preprocess_mismatch").sum())

    if app_mismatch_count == 0:
        final_diagnosis = "python_matches_app_scores_model_gap_or_data_shift"
    elif app_mismatch_count == len(scored_rows):
        final_diagnosis = "strong_app_preprocess_mismatch_signal"
    else:
        final_diagnosis = "mixed_signal_some_app_preprocess_mismatch"

    report = {
        "input": {
            "app_csv": str(app_csv_path),
            "images_dir": str(images_dir),
            "model": str(model_path),
            "delta_tolerance": float(args.delta_tolerance),
        },
        "counts": {
            "rows_in_app_csv_with_raw_score": int(len(app_df)),
            "rows_scored": int(len(scored_rows)),
            "missing_images_by_filename": int(len(missing_files)),
            "rows_with_hash_in_csv": int(app_df["file_sha256"].notna().sum()) if "file_sha256" in app_df.columns else 0,
            "hash_match_rows": int(scored_df["hash_match"].fillna(False).sum()) if "hash_match" in scored_df.columns else 0,
            "hash_missing_or_mismatch_rows": int(len(hash_missing_or_mismatch)),
        },
        "missing_images": missing_files,
        "hash_missing_or_mismatch": hash_missing_or_mismatch,
        "diagnosis": final_diagnosis,
        "comparison_summary": {
            "mean_abs_delta": float(scored_df["abs_delta"].mean()),
            "max_abs_delta": float(scored_df["abs_delta"].max()),
            "rows_flagged_possible_app_preprocess_mismatch": app_mismatch_count,
            "rows_flagged_model_gap_or_data_shift": int(
                (scored_df["verdict"] == "model_gap_or_data_shift").sum()
            ),
            "label_disagreements": int(
                (scored_df["app_label_from_score"] != scored_df["python_label_from_score"]).sum()
            ),
        },
        "rows": [asdict(r) for r in scored_rows],
        "profiles": {
            "realworld": _realworld_profile(scored_rows),
            "dataset": _dataset_profile(dataset_root),
        },
    }

    out_json.parent.mkdir(parents=True, exist_ok=True)
    with out_json.open("w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    out_csv = out_json.with_suffix(".csv")
    scored_df.to_csv(out_csv, index=False)

    print(json.dumps(report["comparison_summary"], indent=2))
    print(f"Diagnosis: {report['diagnosis']}")
    print(f"Saved JSON report: {out_json}")
    print(f"Saved row CSV: {out_csv}")


if __name__ == "__main__":
    main()
