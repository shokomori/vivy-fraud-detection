from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split

from image_pipeline import augment_train_image, preprocess_image


def binary_label_from_text(label: str) -> str:
    return "Fraudulent" if "fraud" in label.lower() else "Genuine"


def make_splits(df: pd.DataFrame, seed: int) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    strat = df["label"]
    train_val, test = train_test_split(
        df,
        test_size=0.10,
        random_state=seed,
        stratify=strat,
    )

    train, val = train_test_split(
        train_val,
        test_size=0.1111111111,
        random_state=seed,
        stratify=train_val["label"],
    )

    return train.reset_index(drop=True), val.reset_index(drop=True), test.reset_index(drop=True)


def print_split_counts(train: pd.DataFrame, val: pd.DataFrame, test: pd.DataFrame) -> None:
    split_map = {
        "train": train,
        "val": val,
        "test": test,
    }

    print("Per-class counts by split (4-way labels):")
    labels = sorted(pd.concat([train["label"], val["label"], test["label"]]).unique())
    for split_name, split_df in split_map.items():
        counts = split_df["label"].value_counts().reindex(labels, fill_value=0)
        count_str = ", ".join(f"{k}={int(v)}" for k, v in counts.items())
        print(f"- {split_name}: {count_str}")

    print("Per-class counts by split (binary labels):")
    for split_name, split_df in split_map.items():
        counts = split_df["binary_label"].value_counts().reindex(["Fraudulent", "Genuine"], fill_value=0)
        count_str = ", ".join(f"{k}={int(v)}" for k, v in counts.items())
        print(f"- {split_name}: {count_str}")


def build_arrays(
    split_name: str,
    split_df: pd.DataFrame,
    root: Path,
    label_to_index: Dict[str, int],
    augment_train_copies: int,
    seed: int,
) -> Tuple[np.ndarray, np.ndarray, List[str], List[str]]:
    images: List[np.ndarray] = []
    labels_int: List[int] = []
    labels_text: List[str] = []
    source_paths: List[str] = []

    rng = np.random.default_rng(seed)

    for row in split_df.itertuples(index=False):
        src = root / row.relative_path
        img = preprocess_image(src)

        images.append(img)
        labels_int.append(label_to_index[row.label])
        labels_text.append(row.label)
        source_paths.append(row.relative_path)

        if split_name == "train" and augment_train_copies > 0:
            for aug_idx in range(augment_train_copies):
                aug = augment_train_image(img, rng)
                images.append(aug)
                labels_int.append(label_to_index[row.label])
                labels_text.append(row.label)
                source_paths.append(f"{row.relative_path}::aug{aug_idx + 1}")

    return (
        np.stack(images, axis=0).astype(np.float32),
        np.asarray(labels_int, dtype=np.int32),
        labels_text,
        source_paths,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Stage 3 preprocessing pipeline")
    parser.add_argument("--dataset-index", default="dataset/dataset_index.csv", help="Path to dataset index CSV")
    parser.add_argument("--output-dir", default="artifacts/stage3", help="Output directory")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    parser.add_argument(
        "--augment-train-copies",
        type=int,
        default=1,
        help="Number of augmented copies per training image; applied only to train split",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    dataset_index = root / args.dataset_index
    output_dir = root / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    if not dataset_index.exists():
        raise FileNotFoundError(f"dataset index not found: {dataset_index}")

    df = pd.read_csv(dataset_index)
    required_cols = {"relative_path", "label"}
    if not required_cols.issubset(df.columns):
        raise ValueError(f"dataset index must include columns: {required_cols}")

    df = df.copy()
    df["binary_label"] = df["label"].map(binary_label_from_text)

    train_df, val_df, test_df = make_splits(df, seed=args.seed)
    print_split_counts(train_df, val_df, test_df)

    splits_dir = output_dir / "splits"
    splits_dir.mkdir(parents=True, exist_ok=True)
    train_df.to_csv(splits_dir / "train.csv", index=False)
    val_df.to_csv(splits_dir / "val.csv", index=False)
    test_df.to_csv(splits_dir / "test.csv", index=False)

    label_names = sorted(df["label"].unique().tolist())
    label_to_index = {name: idx for idx, name in enumerate(label_names)}

    print("\nBuilding preprocessed arrays...")
    arrays_dir = output_dir / "arrays"
    arrays_dir.mkdir(parents=True, exist_ok=True)

    for split_name, split_df in [("train", train_df), ("val", val_df), ("test", test_df)]:
        x, y, labels_text, source_paths = build_arrays(
            split_name=split_name,
            split_df=split_df,
            root=root,
            label_to_index=label_to_index,
            augment_train_copies=args.augment_train_copies,
            seed=args.seed,
        )

        np.savez_compressed(
            arrays_dir / f"{split_name}.npz",
            images=x,
            labels_int=y,
            labels_text=np.asarray(labels_text),
            source_paths=np.asarray(source_paths),
            label_names=np.asarray(label_names),
        )

        print(f"- {split_name}: saved {len(y)} samples to {arrays_dir / f'{split_name}.npz'}")

    print("\nDone. Stage 3 preprocessing artifacts are ready.")


if __name__ == "__main__":
    main()
