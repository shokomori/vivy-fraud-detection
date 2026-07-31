from pathlib import Path
import glob
import os

root = Path(r"C:\Users\YUKI\Documents\Vivy")

asset_targets = [
    root / "vivy_app" / "assets" / "vivy_assets" / "Guidelines 1.png",
    root / "vivy_app" / "assets" / "vivy_assets" / "Guidelines 2.png",
    root / "vivy_app" / "assets" / "vivy_assets" / "Guidelines 3.png",
    root / "vivy_app" / "assets" / "vivy_assets" / "Logo Splash Screen.png",
]

for path in asset_targets:
    if path.exists():
        path.unlink()
        print(f"removed {path.relative_to(root)}")
    else:
        print(f"missing {path.relative_to(root)}")

patterns = ["1000000203.jpg", "milestone1_*.png", "tap_test_*.png", "tap_system_test.png"]
removed = []
for pattern in patterns:
    for match in glob.glob(str(root / pattern)):
        os.remove(match)
        removed.append(Path(match).relative_to(root))
        print(f"removed {Path(match).relative_to(root)}")

print(f"summary: removed {len(removed)} root-level files")
