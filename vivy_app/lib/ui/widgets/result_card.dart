import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            height: 8,
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
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.headerBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: SvgPicture.asset(theme.headerAsset),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'GCash Payment Receipt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.accent,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.badgeBackground,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            theme.badgeIcon,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        theme.badgeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.accent,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Confidence Score',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6A7A96),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                Text(
                  confidenceValue == null
                      ? 'N/A'
                      : '${(confidenceValue * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 34,
                    color: Color(0xFF1B2434),
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EBEF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI EXPLANATION',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF687A96),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.25,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.explanation ?? result.message,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF313D52),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTheme {
  const _ResultTheme({
    required this.accent,
    required this.headerBackground,
    required this.badgeBackground,
    required this.headerAsset,
    required this.titleAsset,
    required this.badgeLabel,
    required this.badgeIcon,
  });

  final Color accent;
  final Color headerBackground;
  final Color badgeBackground;
  final String headerAsset;
  final String titleAsset;
  final String badgeLabel;
  final String badgeIcon;

  static _ResultTheme fromType(ResultType type) {
    return switch (type) {
      ResultType.genuine => const _ResultTheme(
        accent: Color(0xFF059669),
        headerBackground: Color(0xFFDFF1E7),
        badgeBackground: Color(0xFFCFF2DE),
        headerAsset: 'assets/vivy_assets/genuine.svg',
        titleAsset: 'assets/vivy_assets/genuine_text.svg',
        badgeLabel: 'Genuine',
        badgeIcon: '✓',
      ),
      ResultType.fraudulent => const _ResultTheme(
        accent: Color(0xFFDC2626),
        headerBackground: Color(0xFFF5E7E7),
        badgeBackground: Color(0xFFF8D9D9),
        headerAsset: 'assets/vivy_assets/fraudulent.svg',
        titleAsset: 'assets/vivy_assets/fraudulent_text.svg',
        badgeLabel: 'Fraudulent',
        badgeIcon: '!',
      ),
      ResultType.notReceipt => const _ResultTheme(
        accent: Color(0xFFD97706),
        headerBackground: Color(0xFFFFF2D9),
        badgeBackground: Color(0xFFFFE6C2),
        headerAsset: 'assets/vivy_assets/warning.svg',
        titleAsset: 'assets/vivy_assets/warning.svg',
        badgeLabel: 'Unclear',
        badgeIcon: '?',
      ),
      ResultType.unclear => const _ResultTheme(
        accent: Color(0xFFD97706),
        headerBackground: Color(0xFFFFF2D9),
        badgeBackground: Color(0xFFFFE6C2),
        headerAsset: 'assets/vivy_assets/warning.svg',
        titleAsset: 'assets/vivy_assets/warning.svg',
        badgeLabel: 'Unclear',
        badgeIcon: '?',
      ),
      ResultType.error => const _ResultTheme(
        accent: Color(0xFFDC2626),
        headerBackground: Color(0xFFF5E7E7),
        badgeBackground: Color(0xFFF8D9D9),
        headerAsset: 'assets/vivy_assets/warning.svg',
        titleAsset: 'assets/vivy_assets/warning.svg',
        badgeLabel: 'Error',
        badgeIcon: '!',
      ),
    };
  }
}
