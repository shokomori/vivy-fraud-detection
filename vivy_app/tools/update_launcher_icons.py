from PIL import Image

icon_sizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': (48, 48),
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': (72, 72),
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': (96, 96),
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': (144, 144),
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': (192, 192),
}

source = 'assets/vivy_assets/vivy_logo.PNG'
img = Image.open(source).convert('RGBA')
for path, size in icon_sizes.items():
    img.resize(size, Image.LANCZOS).save(path)
    print(f'Wrote {path} {size}')
