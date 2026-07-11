# verifio

Detection of fraudulent GCash electronic payment receipts using pattern analysis-based image processing.

## System Guide

This project is organized into 11 stages that cover the full pipeline from dataset preparation to mobile deployment.

### Stage 1 - Set Up Your Tools

Use Python for model training with TensorFlow, OpenCV, NumPy, Pandas, scikit-learn, Matplotlib, and Seaborn. Use Flutter for the mobile app with the Flutter SDK, Android Studio, `tflite_flutter`, `image_picker`, `image`, `path_provider`, and `shared_preferences`.

### Stage 2 - Collect and Organize Receipt Images

Gather genuine GCash receipts from Android and iOS devices, create fraudulent examples, vary capture conditions, and organize everything into labeled folders. Set the dataset target with your adviser early; a rough benchmark is at least 150-200 images per class before augmentation.

### Stage 3 - Prepare the Images for Training

Resize, crop to the receipt ROI, resize again to 224 x 224, normalize pixel values to 0-1, and keep images in RGB. Apply augmentation only to the training split. Use a stratified split for training, validation, and test sets.

### Stage 4 - Train the Model

Start with MobileNetV2, freeze most layers, train a new classification head, then fine-tune the last layers with a smaller learning rate. Watch for overfitting using training and validation accuracy.

### Stage 5 - Test How Good the Model Is

Evaluate on the held-out test set using accuracy, precision, recall, F1-score, and a confusion matrix. Tune the decision threshold instead of hardcoding 0.5.

### Binary Label Encoding Contract

Use this mapping consistently across Stage 4 training, Stage 5 threshold tuning, and the Flutter app inference logic:

- 0 = Genuine
- 1 = Fraudulent

Treat `Fraudulent` (1) as the positive class when computing precision, recall, F1-score, confusion matrix, and threshold selection.

### Stage 6 - Shrink the Model for Mobile

Convert the trained model to TensorFlow Lite, apply optimization or quantization if appropriate, compare outputs between the original and converted model, and place the final `.tflite` file in the Flutter app.

### Stage 7 - Build the App Around the Model

Match preprocessing exactly between training and app inference, let users upload from the gallery, run inference offline on-device, apply the tuned threshold, and display the result with confidence. Add a rejection path for images that do not look like receipts.

### Stage 8 - Add the AI Explanation Feature

Start with a template-based explanation message tied to the prediction result. Treat per-field anomaly detection as an optional stretch goal if timeline allows.

### Stage 9 - Save a Simple History

Store only the label, confidence score, and timestamp locally on the phone. Do not save receipt photos or transaction details.

### Stage 10 - Test Everything

Test preprocessing, inference, the full app flow, multiple devices, and usability with target users.

### Stage 11 - Package It for Your Defense

Build the final installable app and install it on demo devices ahead of time.

## Summary Table

| Stage | Main focus | Main tools |
| --- | --- | --- |
| 1 | Set up Python and Flutter environments | TensorFlow, OpenCV, Flutter SDK |
| 2 | Collect and organize genuine and fraudulent images | Phone camera, Canva |
| 3 | Clean, standardize, and augment images | OpenCV, NumPy |
| 4 | Train the classifier | TensorFlow / Keras, MobileNetV2 |
| 5 | Measure model quality and tune threshold | scikit-learn, Matplotlib |
| 6 | Convert the model for mobile use | TensorFlow Lite Converter |
| 7 | Build the app and rejection flow | Flutter, `tflite_flutter`, `image_picker` |
| 8 | Add an explanation feature | Dart logic, optional OpenCV analysis |
| 9 | Save local history | `shared_preferences` |
| 10 | Validate the full system | Manual testing, PSSUQ |
| 11 | Prepare the demo build | Flutter build tools |

## Key Fixes

- Confirm the dataset size target with your adviser before collecting too many images.
- Apply augmentation only to the training split.
- Tune the fraud threshold based on validation results instead of using 0.5.
- Add a rejection path for images that are not receipts.
- Keep the explanation feature simple first; per-zone anomaly detection is a stretch goal.

## Real-World Misclassification Diagnosis (No Retraining Yet)

Use this workflow before proposing any retraining changes.

1. Export app raw scores on-device

- In the result screen, tap `Copy Raw Score CSV`.
- The app copies CSV text with columns:
	- `timestamp_iso,filename,result_type,raw_score,threshold,file_path,file_sha256,file_size_bytes,decoded_width,decoded_height`
- Paste this into a local file, for example:
	- `artifacts/debug_compare/app_raw_scores.csv`

2. Compare app raw score vs Python Stage 3 + TFLite score

Run from repo root:

```bash
python tools/compare_realworld_app_vs_stage3.py \
	--app-csv artifacts/debug_compare/app_raw_scores.csv \
	--images-dir <folder_with_realworld_images> \
	--model artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite
```

Outputs:

- `artifacts/debug_compare/realworld_score_comparison.json`
- `artifacts/debug_compare/realworld_score_comparison.csv`

Interpretation:

- If per-image `abs_delta` is small (within tolerance), app and Python agree; this points to model gap or data shift.
- If `abs_delta` is consistently high, this signals app-side preprocessing mismatch.
- If `file_sha256` is present, comparator performs hash-aware image matching so each CSV row is tied to the exact source bytes.

## Debug Batch Ingestion (ADB Triggered)

This path is for collecting real-world batches without picker tapping.

### Debug-only enforcement

- The batch runner is gated by `kReleaseMode` in app code.
- In release builds, trigger files are ignored and batch ingestion will not run.
- The trigger check executes only in debug/profile app sessions.

### Where to drop images

Push real-world screenshots to this app-specific folder on device/emulator:

- `/sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/batch_inbox/`

### Single adb command to trigger a full batch run

Use one host command (from repo root) after images are in `batch_inbox`:

```bash
adb shell "touch /sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/trigger.run" && adb shell monkey -p com.example.vivy_app -c android.intent.category.LAUNCHER 1
```

### Cleanup command (recommended after every run)

Clear `batch_inbox` so old images cannot mix into the next batch:

```bash
adb shell "rm -f /sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/batch_inbox/*"
```

Optional strict pre-run sequence (empty inbox first, then push fresh files):

```bash
adb shell "rm -f /sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/batch_inbox/*"
adb push <your_real_image_folder>/* /sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/batch_inbox/
adb shell "touch /sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/trigger.run" && adb shell monkey -p com.example.vivy_app -c android.intent.category.LAUNCHER 1
```

### Output files

After processing, app writes:

- CSV: `/sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/batch_exports/batch_results_<UTC>.csv`
- Status JSON: `/sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/last_batch_status.json`

Pull outputs to local workspace:

```bash
adb pull /sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/batch_exports artifacts/debug_compare/
adb pull /sdcard/Android/data/com.example.vivy_app/files/vivy_debug_batch/last_batch_status.json artifacts/debug_compare/
```
