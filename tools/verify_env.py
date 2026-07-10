import importlib
import platform
import sys
import traceback

packages = [
    "tensorflow",
    "cv2",
    "numpy",
    "pandas",
    "sklearn",
    "matplotlib",
    "seaborn",
]

print(f"Python executable: {sys.executable}")
print(f"Python version: {platform.python_version()}")

for name in packages:
    try:
        print(f"Importing {name}...", flush=True)
        module = importlib.import_module(name)
        version = getattr(module, "__version__", "(no __version__)")
        print(f"{name}: {version}")
    except Exception as exc:
        print(f"Failed to import {name}: {exc}")
        traceback.print_exc()
        raise

print("All required imports succeeded.")
