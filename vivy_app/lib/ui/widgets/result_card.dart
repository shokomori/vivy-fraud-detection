import 'package:flutter/material.dart';

import '../../domain/analysis_models.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result, required this.threshold});

  final AnalysisResult result;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final theme = _ResultTheme.fromType(result.type);
    final confidenceValue = result.confidence ?? (result.score == null ? null : (1.0 - result.score!));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7DFED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 7,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.headerBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: theme.accent, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'GCash Payment Receipt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.badgeBackground,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(theme.badgeIcon, size: 19, color: theme.accent),
                      const SizedBox(width: 6),
                      Text(
                        theme.badgeLabel,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: theme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Confidence Score',
                  style: TextStyle(
                    fontSize: 17,
                    color: Color(0xFF6A7A96),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  confidenceValue == null
                      ? 'N/A'
                      : '${(confidenceValue * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 43,
                    color: Color(0xFF1B2434),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE3EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI EXPLANATION',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF687A96),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.explanation ?? result.message,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Color(0xFF313D52),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (result.score != null ||
                    (result.areaRatio != null && result.aspectRatio != null)) ...[
                  const SizedBox(height: 10),
                  Text(
                    _technicalLine(result, threshold),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73849D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _technicalLine(AnalysisResult result, double threshold) {
  final parts = <String>[];
  if (result.score != null) {
    parts.add(
      'raw score ${result.score!.toStringAsFixed(4)} @ ${threshold.toStringAsFixed(2)}',
    );
  }
  if (result.areaRatio != null && result.aspectRatio != null) {
    parts.add(
      'geometry area ${result.areaRatio!.toStringAsFixed(3)} / aspect ${result.aspectRatio!.toStringAsFixed(3)}',
    );
  }
  return parts.join(' • ');
}

class _ResultTheme {
  const _ResultTheme({
    required this.accent,
    required this.headerBackground,
    required this.badgeBackground,
    required this.badgeIcon,
    required this.badgeLabel,
  });

  final Color accent;
  final Color headerBackground;
  final Color badgeBackground;
  final IconData badgeIcon;
  final String badgeLabel;

  static _ResultTheme fromType(ResultType type) {
    return switch (type) {
      ResultType.genuine => const _ResultTheme(
        accent: Color(0xFF059669),
        headerBackground: Color(0xFFDFF1E7),
        badgeBackground: Color(0xFFCFF2DE),
        badgeIcon: Icons.check_circle_outline_rounded,
        badgeLabel: 'Genuine',
      ),
      ResultType.fraudulent => const _ResultTheme(
        accent: Color(0xFFDC2626),
        headerBackground: Color(0xFFF5E7E7),
        badgeBackground: Color(0xFFF8D9D9),
        badgeIcon: Icons.error_outline_rounded,
        badgeLabel: 'Fraudulent',
      ),
      ResultType.notReceipt => const _ResultTheme(
        accent: Color(0xFFD97706),
        headerBackground: Color(0xFFFFF2D9),
        badgeBackground: Color(0xFFFFE6C2),
        badgeIcon: Icons.help_outline_rounded,
        badgeLabel: 'Not Receipt',
      ),
      ResultType.unclear => const _ResultTheme(
        accent: Color(0xFFD97706),
        headerBackground: Color(0xFFFFF2D9),
        badgeBackground: Color(0xFFFFE6C2),
        badgeIcon: Icons.report_gmailerrorred_rounded,
        badgeLabel: 'Unclear',
      ),
      ResultType.error => const _ResultTheme(
        accent: Color(0xFFDC2626),
        headerBackground: Color(0xFFF5E7E7),
        badgeBackground: Color(0xFFF8D9D9),
        badgeIcon: Icons.error_outline_rounded,
        badgeLabel: 'Error',
      ),
    };
  }
}
