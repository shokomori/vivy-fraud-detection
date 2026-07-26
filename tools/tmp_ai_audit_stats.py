from pathlib import Path
from PIL import Image
import statistics as st

root = Path(__file__).resolve().parents[1] / "dataset"
groups = {
    "incoming_android": root / "AndroidAIFraudulent",
    "incoming_ios": root / "iOSAIFraudulent",
    "old_android_fraud": root / "AndroidFraudulent",
    "old_android_genuine": root / "AndroidGenuine",
    "old_ios_fraud": root / "iOSFraudulent",
    "old_ios_genuine": root / "iOSGenuine",
}
exts = {".jpg", ".jpeg", ".png", ".jfif", ".webp", ".bmp", ".tif", ".tiff"}

for name, folder in groups.items():
    vals = []
    if folder.exists():
        for p in sorted(folder.iterdir()):
            if p.is_file() and p.suffix.lower() in exts:
                try:
                    with Image.open(p) as im:
                        w, h = im.size
                    vals.append((w, h, (w / h) if h else 0.0))
                except Exception:
                    pass

    if not vals:
        print(f"{name}: count=0")
        continue

    ws = [v[0] for v in vals]
    hs = [v[1] for v in vals]
    ars = [v[2] for v in vals]
    print(
        f"{name}: count={len(vals)} "
        f"w[min/med/max]={min(ws)}/{st.median(ws):.1f}/{max(ws)} "
        f"h[min/med/max]={min(hs)}/{st.median(hs):.1f}/{max(hs)} "
        f"aspect[min/med/max]={min(ars):.4f}/{st.median(ars):.4f}/{max(ars):.4f}"
    )
