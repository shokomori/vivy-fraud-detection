from pathlib import Path
import numpy as np
import tensorflow as tf
from PIL import Image
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input

root = Path('c:/Users/YUKI/Documents/Vivy')
model_path = root / 'artifacts/analysis/pre_ai_model_237499f4.keras'
model = tf.keras.models.load_model(model_path)

paths = [
    root / 'dataset/AndroidGenuine/gA_272.jfif',
    root / 'dataset/iOSGenuine/gI_059.jpg',
]

for path in paths:
    img = Image.open(path).convert('RGB').resize((224, 224))
    arr = np.asarray(img, dtype=np.float32)
    arr = preprocess_input(arr)[None, ...]
    prob = float(model.predict(arr, verbose=0)[0, 0])
    pred = int(prob >= 0.16)
    print(f'{path.name}: prob={prob:.6f} pred={pred} threshold=0.16')
