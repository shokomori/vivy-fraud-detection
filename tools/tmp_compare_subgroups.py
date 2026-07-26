import numpy as np
import pandas as pd
import tensorflow as tf


d = np.load('artifacts/stage3/arrays/test.npz', allow_pickle=True)
x = d['images'].astype('float32')
labels = np.array(d['labels_text']).astype(str)
y = np.array([1 if 'fraud' in s.lower() else 0 for s in labels])

old = tf.keras.models.load_model('artifacts/analysis/pre_ai_model_237499f4.keras')
new = tf.keras.models.load_model('artifacts/stage4/mobilenetv2_fraud_detector.keras')

po = old.predict(x, verbose=0).reshape(-1)
pn = new.predict(x, verbose=0).reshape(-1)

df = pd.DataFrame({'label': labels, 'y': y, 'old': po, 'new': pn})
fraud = df[df['y'] == 1]
ai = fraud[fraud['label'].str.contains('ai_fraudulent', case=False, na=False)]
orig = fraud[~fraud['label'].str.contains('ai_fraudulent', case=False, na=False)]

print('AI count', len(ai))
print('Old recall @0.16', float((ai['old'] >= 0.16).mean()))
print('Old recall @0.05', float((ai['old'] >= 0.05).mean()))
print('New recall @0.16', float((ai['new'] >= 0.16).mean()))
print('New recall @0.05', float((ai['new'] >= 0.05).mean()))
print('AI mean old/new', float(ai['old'].mean()), float(ai['new'].mean()))

print('Original fraud count', len(orig))
print('Old recall @0.16', float((orig['old'] >= 0.16).mean()))
print('Old recall @0.05', float((orig['old'] >= 0.05).mean()))
print('New recall @0.16', float((orig['new'] >= 0.16).mean()))
print('New recall @0.05', float((orig['new'] >= 0.05).mean()))
print('Original fraud mean old/new', float(orig['old'].mean()), float(orig['new'].mean()))
