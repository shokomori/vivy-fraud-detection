from __future__ import annotations

from pathlib import Path
from typing import Tuple

import cv2
import numpy as np


def crop_receipt_roi(image_bgr: np.ndarray) -> np.ndarray:
    """Crop to the largest likely receipt region; fallback to the full image."""
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)

    # Otsu threshold tends to separate bright receipt paper from darker surroundings.
    _, thresh = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    kernel = np.ones((5, 5), np.uint8)
    closed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel, iterations=2)

    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return image_bgr

    h, w = gray.shape
    min_area = 0.12 * h * w

    best = None
    best_area = 0
    for c in contours:
        area = cv2.contourArea(c)
        if area < min_area:
            continue
        x, y, bw, bh = cv2.boundingRect(c)
        aspect = bw / max(float(bh), 1.0)
        if 0.25 <= aspect <= 3.5 and area > best_area:
            best = (x, y, bw, bh)
            best_area = area

    if best is None:
        return image_bgr

    x, y, bw, bh = best
    pad_x = int(0.03 * bw)
    pad_y = int(0.03 * bh)
    x0 = max(x - pad_x, 0)
    y0 = max(y - pad_y, 0)
    x1 = min(x + bw + pad_x, w)
    y1 = min(y + bh + pad_y, h)
    return image_bgr[y0:y1, x0:x1]


def preprocess_image(image_path: Path, image_size: Tuple[int, int] = (224, 224)) -> np.ndarray:
    """Read image, crop ROI, resize to 224x224, convert BGR->RGB, normalize to [0, 1]."""
    bgr = cv2.imread(str(image_path))
    if bgr is None:
        raise ValueError(f"Unable to read image: {image_path}")

    roi = crop_receipt_roi(bgr)
    resized = cv2.resize(roi, image_size, interpolation=cv2.INTER_AREA)
    rgb = cv2.cvtColor(resized, cv2.COLOR_BGR2RGB)
    normalized = rgb.astype(np.float32) / 255.0
    return normalized


def augment_train_image(image_rgb_norm: np.ndarray, rng: np.random.Generator) -> np.ndarray:
    """Apply light geometric/intensity augmentation to training images only."""
    img = (np.clip(image_rgb_norm, 0.0, 1.0) * 255.0).astype(np.uint8)

    # Small random affine transform for realistic camera variance.
    h, w, _ = img.shape
    angle = float(rng.uniform(-5.0, 5.0))
    scale = float(rng.uniform(0.95, 1.05))
    tx = float(rng.uniform(-0.04, 0.04) * w)
    ty = float(rng.uniform(-0.04, 0.04) * h)
    matrix = cv2.getRotationMatrix2D((w / 2.0, h / 2.0), angle, scale)
    matrix[:, 2] += [tx, ty]
    warped = cv2.warpAffine(
        img,
        matrix,
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REFLECT_101,
    )

    alpha = float(rng.uniform(0.9, 1.1))
    beta = float(rng.uniform(-8.0, 8.0))
    adjusted = cv2.convertScaleAbs(warped, alpha=alpha, beta=beta)

    return adjusted.astype(np.float32) / 255.0
