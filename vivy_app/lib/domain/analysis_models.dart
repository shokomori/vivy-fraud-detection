import 'dart:convert';

import 'package:image/image.dart' as img;

enum ResultType { genuine, fraudulent, notReceipt, unclear, error }

extension ResultTypeLabel on ResultType {
  String get displayLabel => switch (this) {
    ResultType.fraudulent => 'Fraudulent',
    ResultType.genuine => 'Genuine',
    ResultType.notReceipt => 'Not a GCash Receipt',
    ResultType.unclear => 'Unclear Result',
    ResultType.error => 'Error',
  };
}

class AnalysisResult {
  const AnalysisResult({
    required this.type,
    required this.message,
    this.score,
    this.confidence,
    this.explanation,
    this.areaRatio,
    this.aspectRatio,
  });

  final ResultType type;
  final String message;
  final double? score;
  final double? confidence;
  final String? explanation;
  final double? areaRatio;
  final double? aspectRatio;

  factory AnalysisResult.classified({
    required bool isFraudulent,
    required double score,
    required double confidence,
    String? explanation,
  }) {
    final confidenceText = (confidence * 100).toStringAsFixed(1);
    return AnalysisResult(
      type: isFraudulent ? ResultType.fraudulent : ResultType.genuine,
      message: isFraudulent
          ? 'Receipt appears fraudulent.'
          : 'Receipt appears genuine.',
      score: score,
      confidence: confidence,
      explanation: explanation ??
          (isFraudulent
          ? 'This receipt is flagged as fraudulent. The model is $confidenceText% confident in that result.'
          : 'This receipt is flagged as genuine. The model is $confidenceText% confident in that result.'),
    );
  }

  factory AnalysisResult.notReceipt({
    required String message,
    required double areaRatio,
    required double aspectRatio,
  }) {
    return AnalysisResult(
      type: ResultType.notReceipt,
      message: message,
      areaRatio: areaRatio,
      aspectRatio: aspectRatio,
    );
  }

  factory AnalysisResult.unclear({
    required String message,
    required double score,
  }) {
    return AnalysisResult(
      type: ResultType.unclear,
      message: message,
      score: score,
    );
  }

  factory AnalysisResult.error(String message) {
    return AnalysisResult(type: ResultType.error, message: message);
  }
}

class RoiExtractionResult {
  const RoiExtractionResult({
    required this.roi,
    required this.geometryPass,
    required this.areaRatio,
    required this.aspectRatio,
  });

  final img.Image? roi;
  final bool geometryPass;
  final double areaRatio;
  final double aspectRatio;
}

class HistoryEntry {
  const HistoryEntry({
    required this.label,
    required this.confidence,
    required this.timestamp,
    this.imagePath,
    this.amount,
    this.explanation,
  });

  final String label;
  final double? confidence;
  final DateTime timestamp;

  /// Path to a persisted copy of the scanned receipt image on disk.
  /// Null for entries created before this field existed, or if the
  /// image could not be saved.
  final String? imagePath;

  /// Peso amount parsed from the receipt, if available.
  final double? amount;

  /// AI explanation text captured at analysis time. If null, the
  /// detail screen falls back to a generic explanation based on [label].
  final String? explanation;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'amount': amount,
      'explanation': explanation,
    };
  }

  String toStorageString() => jsonEncode(toJson());

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      label: (json['label'] as String?) ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestamp:
          DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      imagePath: json['imagePath'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      explanation: json['explanation'] as String?,
    );
  }

  factory HistoryEntry.fromStorageString(String encoded) {
    return HistoryEntry.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
  }
}