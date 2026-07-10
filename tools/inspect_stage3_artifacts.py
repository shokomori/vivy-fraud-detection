from pathlib import Path
import numpy as np

root = Path(__file__).resolve().parents[1]
arrays_dir = root / "artifacts" / "stage3" / "arrays"

for split in ["train", "val", "test"]:
    data = np.load(arrays_dir / f"{split}.npz", allow_pickle=True)
    x = data["images"]
    y = data["labels_int"]
    print(f"{split}: images_shape={x.shape}, labels_shape={y.shape}, min={x.min():.4f}, max={x.max():.4f}")
