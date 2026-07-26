# AI-Generated Fraud Subset Approval Note

Date: 2026-07-26

## Decision

Approved subset for downstream indexing and Stage 3 split:
- Include OCR triage categories: `pass` and `ambiguous`
- Exclude OCR triage category: `fail`

Approved totals:
- Total approved AI-generated fraud images: 49
- Android approved: 28
- iOS approved: 21

Excluded totals:
- Total excluded AI-generated fraud images: 30
- Android excluded: 12
- iOS excluded: 18

## Rationale

The excluded `fail` bucket showed repeated OCR weakness patterns, especially:
- low OCR text length
- low OCR confidence
- fewer OCR-detected text lines

These samples were judged more likely to teach unhelpful patterns than represent realistic sophisticated fake receipts.

## iOS Batch Quality Note

The iOS AI-generated batch showed a systematically higher automated triage failure rate than the Android batch.

Failure rates:
- iOS: 18 / 39 = 46.2%
- Android: 12 / 40 = 30.0%

Top fail reasons by platform:

### iOS
- `ocr_text_len_low`: 10
- `ocr_mean_conf_low`: 9
- `ocr_line_count_low`: 6
- `ocr_few_numeric_tokens`: 1

### Android
- `ocr_text_len_low`: 11
- `ocr_mean_conf_low`: 5
- `ocr_few_numeric_tokens`: 2
- `ocr_line_count_low`: 1
- `struct_line_band_count_low`: 1
- `struct_component_count_low`: 1

Interpretation:
- The higher iOS fail rate appears systematic rather than scattered.
- iOS failures are concentrated in a small recurring cluster of OCR-related weaknesses.
- Android failures are more mixed and less dominated by low-confidence or low-line OCR behavior.

Suggested writeup wording:

> The AI-generated iOS fraud subset showed a systematically higher automated triage failure rate than the Android subset (46.2% vs 30.0%). Failures in the iOS batch were dominated by recurring OCR-readability issues, particularly low extracted text length, lower OCR confidence, and fewer detected text lines, suggesting a consistent source-batch quality pattern rather than isolated outliers.

## Traceability

Primary audit artifacts:
- `artifacts/ai_fraud_audit/ocr_triage/ocr_triage_summary.json`
- `artifacts/ai_fraud_audit/ocr_triage/ocr_triage_results.csv`
- `artifacts/ai_fraud_audit/ocr_triage/manual_review_priority.csv`
- `artifacts/ai_fraud_audit/ocr_triage/manual_review_priority_20.jpg`
