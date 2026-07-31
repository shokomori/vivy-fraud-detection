import os
from pathlib import Path
root = Path(r'c:\Users\YUKI\Documents\Vivy').resolve()
exclude = {'.git', '.venv', '.venv311', 'vivy_app/build', 'vivy_app/.dart_tool', 'vivy_app/.idea', 'vivy_app/.flutter-plugins', 'vivy_app/.flutter-plugins-dependencies'}
files = []
for p in root.rglob('*'):
    if not p.is_file():
        continue
    rel = p.relative_to(root).as_posix()
    if any(part in exclude for part in p.parts):
        continue
    if 'node_modules' in rel or '__pycache__' in rel:
        continue
    files.append((p, rel, p.stat().st_size))
files.sort(key=lambda x: x[2], reverse=True)
for p, rel, size in files:
    print(f'{size:>12}  {rel}')
print('---TOTAL---')
print(sum(size for _,_,size in files))
