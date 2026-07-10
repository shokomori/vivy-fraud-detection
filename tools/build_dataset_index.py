from pathlib import Path
import csv

CLASS_MAP = {
    "AndroidFraudulent": "android_fraudulent",
    "AndroidGenuine": "android_genuine",
    "iOSFraudulent": "ios_fraudulent",
    "iOSGenuine": "ios_genuine",
}

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset_dir = root / "dataset"
    output_csv = dataset_dir / "dataset_index.csv"

    rows = []
    for folder_name, label in CLASS_MAP.items():
        folder = dataset_dir / folder_name
        if not folder.exists():
            continue

        for image_path in sorted(folder.iterdir()):
            if image_path.is_file() and image_path.suffix.lower() in IMAGE_EXTENSIONS:
                rows.append(
                    {
                        "relative_path": str(image_path.relative_to(root)).replace("\\", "/"),
                        "class_folder": folder_name,
                        "label": label,
                    }
                )

    with output_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["relative_path", "class_folder", "label"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {output_csv}")


if __name__ == "__main__":
    main()
