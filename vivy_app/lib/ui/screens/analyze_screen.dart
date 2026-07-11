import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/analysis_models.dart';
import '../widgets/result_card.dart';

class AnalyzeUiState {
  const AnalyzeUiState({
    this.result,
    this.isBusy = false,
    this.loadError,
  });

  final AnalysisResult? result;
  final bool isBusy;
  final String? loadError;
}

class AnalyzeScreen extends StatelessWidget {
  const AnalyzeScreen({
    super.key,
    required this.uiStateListenable,
    required this.threshold,
    required this.onPickPhoto,
    required this.onOpenHistory,
    required this.onExportRawScores,
    this.onDebugGenuine,
    this.onDebugFraudulent,
  });

  final ValueListenable<AnalyzeUiState> uiStateListenable;
  final double threshold;
  final VoidCallback onPickPhoto;
  final VoidCallback onOpenHistory;
  final VoidCallback onExportRawScores;
  final VoidCallback? onDebugGenuine;
  final VoidCallback? onDebugFraudulent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AnalyzeUiState>(
      valueListenable: uiStateListenable,
      builder: (context, state, _) {
        final mode = state.isBusy
            ? _AnalyzeViewMode.scanning
            : (state.result != null
                  ? _AnalyzeViewMode.result
                  : _AnalyzeViewMode.upload);

        return Scaffold(
          backgroundColor: const Color(0xFFEFF3FB),
          appBar: _TopBar(mode: mode, onOpenHistory: onOpenHistory),
          body: SafeArea(
            child: switch (mode) {
              _AnalyzeViewMode.upload => _UploadStateView(
                loadError: state.loadError,
                onPickPhoto: onPickPhoto,
              ),
              _AnalyzeViewMode.scanning => const _ScanningStateView(),
              _AnalyzeViewMode.result => _ResultStateView(
                result: state.result!,
                threshold: threshold,
                onPickPhoto: onPickPhoto,
                onExportRawScores: onExportRawScores,
              ),
            },
          ),
        );
      },
    );
  }
}

enum _AnalyzeViewMode { upload, scanning, result }

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.mode, required this.onOpenHistory});

  final _AnalyzeViewMode mode;
  final VoidCallback onOpenHistory;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      _AnalyzeViewMode.upload => 'Upload Receipt',
      _AnalyzeViewMode.scanning => '',
      _AnalyzeViewMode.result => 'Verification Result',
    };

    if (mode == _AnalyzeViewMode.scanning) {
      return AppBar(backgroundColor: Colors.transparent, elevation: 0);
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 8,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFDCE3F0),
            ),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: SvgPicture.asset(
              'assets/vivy_assets/back.svg',
              width: 19,
              height: 19,
            ),
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 31,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1D2638),
        ),
      ),
      actions: [
        if (mode == _AnalyzeViewMode.upload)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'History',
              onPressed: onOpenHistory,
              icon: SvgPicture.asset(
                'assets/vivy_assets/history.svg',
                width: 20,
                height: 20,
              ),
            ),
          ),
      ],
    );
  }
}

class _UploadStateView extends StatelessWidget {
  const _UploadStateView({
    required this.loadError,
    required this.onPickPhoto,
  });

  final String? loadError;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      child: Column(
        children: [
          const SizedBox(height: 84),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFAEDFD8), width: 1.2),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBDEEE6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SvgPicture.asset('assets/vivy_assets/upload.svg'),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select a Receipt Image',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2434),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Upload your GCash e-receipt for AI verification',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onPickPhoto,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15489D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Browse Gallery',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FormatChip(label: 'JPG'),
              _FormatChip(label: 'PNG'),
              _FormatChip(label: 'WEBP'),
              _FormatChip(label: 'Max 10 MB'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(225),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FOR BEST RESULTS',
                  style: TextStyle(
                    color: Color(0xFF0B9D90),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 10),
                _TipBullet(text: 'Ensure the receipt is fully visible and flat'),
                SizedBox(height: 10),
                _TipBullet(text: 'Use good lighting - avoid shadows or glare'),
                SizedBox(height: 10),
                _TipBullet(text: 'Capture the full receipt including all text'),
              ],
            ),
          ),
          if (loadError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                loadError!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanningStateView extends StatelessWidget {
  const _ScanningStateView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE9EEF8),
              border: Border.all(color: const Color(0xFFDCE4F2), width: 2),
            ),
            child: Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFF17489D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SvgPicture.asset('assets/vivy_assets/analysis.svg'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Analyzing Receipt',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2536),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifying metadata & fonts...',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B4B95),
            ),
          ),
          const SizedBox(height: 26),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              width: 260,
              child: const LinearProgressIndicator(
                minHeight: 8,
                value: 0.8,
                backgroundColor: Color(0xFFE4EAF4),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF17489D)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _PulseBars(),
        ],
      ),
    );
  }
}

class _ResultStateView extends StatelessWidget {
  const _ResultStateView({
    required this.result,
    required this.threshold,
    required this.onPickPhoto,
    required this.onExportRawScores,
  });

  final AnalysisResult result;
  final double threshold;
  final VoidCallback onPickPhoto;
  final VoidCallback onExportRawScores;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF677892),
                  ),
                ),
                const SizedBox(height: 8),
                ResultCard(result: result, threshold: threshold),
                const SizedBox(height: 12),
                _RecommendationCard(result: result),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: onExportRawScores,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF15489D),
                      side: const BorderSide(
                        color: Color(0xFF15489D),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Copy Raw Score CSV',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: const Color(0xFFEFF3FB),
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPickPhoto,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF15489D),
                    side: const BorderSide(color: Color(0xFF15489D), width: 2),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Verify Another',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15489D),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final recommendations = _recommendations(result.type);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7DFED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommendations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2434),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < recommendations.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE1EAF7),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A658D),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recommendations[i],
                    style: const TextStyle(
                      fontSize: 17,
                      color: Color(0xFF313D52),
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (i != recommendations.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PulseBars extends StatelessWidget {
  const _PulseBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _MiniBar(active: true),
        SizedBox(width: 7),
        _MiniBar(active: true),
        SizedBox(width: 7),
        _MiniBar(active: true),
        SizedBox(width: 7),
        _MiniBar(active: true),
        SizedBox(width: 7),
        _MiniBar(active: false),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 6,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF17489D) : const Color(0xFFC9D5EA),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFD2DBEA)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF647793),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TipBullet extends StatelessWidget {
  const _TipBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFBCECE5),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SvgPicture.asset('assets/vivy_assets/checkmark.svg'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF313D52),
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

List<String> _recommendations(ResultType type) {
  return switch (type) {
    ResultType.genuine => const [
      'Safe to proceed with the transaction.',
      'Save this receipt for your records.',
      'Verify payment amount and timestamp once more.',
    ],
    ResultType.fraudulent => const [
      'Do not release goods or payment based on this receipt.',
      'Report to your payment provider immediately.',
      'Request a fresh payment confirmation from sender.',
    ],
    ResultType.notReceipt => const [
      'Upload a full GCash receipt screenshot.',
      'Ensure transaction details are visible and clear.',
      'Avoid cropped or heavily edited images.',
    ],
    ResultType.unclear => const [
      'Retake with better lighting and less glare.',
      'Keep the receipt flat and fully in frame.',
      'Try another screenshot source if available.',
    ],
    ResultType.error => const [
      'Retry the analysis with a clear image.',
      'Restart the app if issue persists.',
      'Use another receipt screenshot for verification.',
    ],
  };
}

String _formatDate(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[dateTime.month - 1];
  final day = dateTime.day;
  final year = dateTime.year;
  var hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) {
    hour = 12;
  }
  return '$month $day, $year, $hour:$minute $suffix';
}
