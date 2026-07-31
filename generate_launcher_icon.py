from pathlib import Path
import subprocess
import sys

root = Path(r"C:\Users\YUKI\Documents\Vivy")
svg_path = root / "vivy_assets" / "ViVy LOGO.svg"
android_res = root / "vivy_app" / "android" / "app" / "src" / "main" / "res"

try:
    import cairosvg
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "cairosvg"])
    import cairosvg

sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

for folder, size in sizes.items():
    out_path = android_res / folder / "ic_launcher.png"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(url=str(svg_path), write_to=str(out_path), output_width=size, output_height=size)
    print(f"wrote {out_path.relative_to(root)}")
