from pathlib import Path
import pandas as pd

root = Path(__file__).resolve().parents[1]
splits_dir = root / "artifacts" / "stage3" / "splits"

for split in ["train", "val", "test"]:
    df = pd.read_csv(splits_dir / f"{split}.csv")
    counts = df["label"].value_counts().sort_index()
    count_text = ", ".join(f"{k}={v}" for k, v in counts.items())
    print(f"{split}: {count_text}")
