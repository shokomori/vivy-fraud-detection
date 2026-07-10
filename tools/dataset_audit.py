from pathlib import Path


def count_images(folder: Path) -> int:
    exts = {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}
    return sum(1 for p in folder.iterdir() if p.is_file() and p.suffix.lower() in exts)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset_dir = root / "dataset"

    class_folders = [
        "AndroidFraudulent",
        "AndroidGenuine",
        "iOSFraudulent",
        "iOSGenuine",
    ]

    print("Dataset audit")
    print(f"Root: {dataset_dir}")

    total = 0
    for name in class_folders:
        folder = dataset_dir / name
        if not folder.exists():
            print(f"- {name}: MISSING")
            continue

        count = count_images(folder)
        total += count
        meets_min = "YES" if count >= 300 else "NO"
        print(f"- {name}: {count} images (>=300 target: {meets_min})")

    print(f"Total images across 4 classes: {total}")


if __name__ == "__main__":
    main()
