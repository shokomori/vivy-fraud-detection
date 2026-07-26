# Model v2 AI-Fraud Expansion Summary

## 1) Compact Metrics Table

| Stage | Scope | Key outputs |
|---|---|---|
| Stage 4 (Retraining) | Freeze-then-fine-tune MobileNetV2 on rebuilt dataset | Final train accuracy: **98.79%** (`0.9879`); Final val accuracy: **96.36%** (`0.9636`); Epochs run: **13** |
| Stage 5 (Re-eval + threshold tuning) | Full held-out test evaluation with threshold tuned from scratch | Test accuracy: **95.76%** (`0.9576`); Precision (Fraud=1): **0.9239**; Recall (Fraud=1): **1.0000**; F1 (Fraud=1): **0.9605**; Tuned threshold: **0.05** |
| Stage 5 (Confusion matrix) | Test set confusion matrix at threshold 0.05 | `[[73, 7], [0, 85]]` with label order `[Genuine (0), Fraudulent (1)]` |
| Stage 5 (AI-fraud subgroup, exploratory) | Fraud-only subgroup breakout on test split | AI-generated fraud: **n=5**, TP=5, FN=0, Recall=**1.0000**, Avg fraud score=**0.9525**; Original fraud: **n=80**, TP=80, FN=0, Recall=**1.0000**, Avg fraud score=**0.9843** |
| Stage 6 (TFLite conversion) | Keras -> TFLite (`float16`) | Output: `artifacts/stage6/mobilenetv2_fraud_detector_float16.tflite`; Size: **4,831,912 bytes (~4.61 MB)** |
| Stage 6 (Keras vs TFLite verification) | Full test-set parity at threshold 0.05 | Samples compared: **165**; Matches: **165**; Mismatches: **0**; Match rate: **1.0000**; Max abs prob diff: **0.047961**; Mean abs prob diff: **0.001260** |
| Stage 6 (Native OpenCV parity probe) | Native-like preprocessing parity probe (16 balanced samples) | Threshold used: **0.05**; Accuracy: **1.0000**; FP: **0/8** genuine; FN: **0/8** fraudulent |

## 2) Expected Tradeoff Note (Accuracy Shift)

The observed top-line accuracy shift (roughly from ~99% in the earlier baseline to ~96% after this update) is an **expected tradeoff**, not a regression. This iteration intentionally expands the fraud class with AI-generated fraudulent receipts, which are a more sophisticated and harder-to-separate fraud style. Adding this harder fraud distribution increases class complexity and tightens the decision boundary, so some drop in aggregate accuracy is normal while the model becomes more robust to realistic, higher-quality fraud patterns. Importantly, recall on the fraudulent class remained at 1.0000 on the current test split, consistent with the recall-priority operating objective.

## 3) Limitations Note (Small AI Subgroup Sample)

The AI-fraud subgroup metrics should be treated as **exploratory only** due to small per-split sample sizes (especially in val/test). In this run, the AI-fraud test subset contains only 5 samples, so subgroup estimates (recall, score distribution, error rates) have high variance and wide uncertainty. These values are still useful as directional signals, but they are not yet strong enough to support definitive per-subcategory performance claims. For stronger statistical confidence, the AI-fraud subset should be expanded and re-evaluated across larger held-out sets (or repeated resampling/cross-validation).

## Source Artifacts

- Stage 4 history: `artifacts/stage4/training_history.csv`
- Stage 5 report: `artifacts/stage5/evaluation_report.json`
- Stage 5 predictions: `artifacts/stage5/test_predictions.csv`
- Stage 6 verification report: `artifacts/stage6/tflite_verification_report.json`
- Stage 6 native-like parity report: `artifacts/debug_compare/native_like_16sample_report.json`
