# Stage 7 Batch Report: 40-Image Manual Check

## Input Summary
- Total images: 40
- Decisive predictions: 39
- Unclear / abstained: 1
- Threshold: 0.16
- Unclear band: 0.05
- Actual class balance: 20 genuine, 20 fraudulent

## Aggregate Confusion Matrix
The unclear sample was not forced into a class label, so the confusion matrix below is computed on the 39 decisive predictions only.

| Actual \ Predicted | Genuine | Fraudulent |
| --- | ---: | ---: |
| Genuine | 18 | 1 |
| Fraudulent | 0 | 20 |

### Coverage
- Decisive coverage: 39 / 40 = 97.5%
- Abstention count: 1

## Batch Metrics
Computed on the 39 decisive predictions:
- Accuracy: 0.9744
- Precision: 0.9524
- Recall: 1.0000
- F1: 0.9756

The false positive is gA_108.jfif, which is genuinely labeled but was predicted Fraudulent. The abstained borderline sample is gA_308.jfif, which fell inside the uncertainty band and was excluded from the decisive confusion matrix.

## Comparison Against Stage 5 Test Metrics
Stage 5 test metrics:
- Accuracy: 0.98125
- Precision: 0.9753
- Recall: 0.9875
- F1: 0.9814

Difference from Stage 5 on decisive predictions:
- Accuracy: -0.00689 (-0.69 percentage points)
- Precision: -0.02292 (-2.29 percentage points)
- Recall: +0.01250 (+1.25 percentage points)
- F1: -0.00579 (-0.58 percentage points)

## Interpretation
The manual 40-image batch contains 39 decisive predictions and 1 abstention. The only decisive error is a false positive on the genuine sample gA_108.jfif, while the borderline gA_308.jfif sample is held out by the uncertainty gate rather than forced into a class. That makes the batch slightly weaker than Stage 5 on accuracy, precision, and F1, while still preserving perfect recall on the fraudulent class.
