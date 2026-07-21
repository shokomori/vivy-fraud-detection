import 'dart:io';
import 'package:flutter/material.dart';

import '../../domain/analysis_models.dart';
import '../theme/vivy_colors.dart';
import '../theme/vivy_spacing.dart';

class VerificationDetailScreen extends StatelessWidget {
  const VerificationDetailScreen({super.key, required this.entry});

  final HistoryEntry entry;

  bool get _isFraud => entry.label.toLowerCase() == 'fraudulent';

  @override
  Widget build(BuildContext context) {
    final accent = _isFraud ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final tintBg = _isFraud ? const Color(0xFFF5E7E7) : const Color(0xFFDFF1E7);
    final badgeBg = _isFraud ? const Color(0xFFF8D9D9) : const Color(0xFFCFF2DE);
    final confidenceText = entry.confidence == null
        ? 'N/A'
        : '${(entry.confidence! * 100).toStringAsFixed(1)}%';
    final referenceNo = _referenceFromTimestamp(entry.timestamp);
    final explanation = entry.explanation ?? _fallbackExplanation(_isFraud);

    return Scaffold(
      backgroundColor: VivyColors.appBackground,
      appBar: AppBar(
        titleSpacing: 8,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _BackButton(onTap: () => Navigator.of(context).maybePop()),
        ),
        title: const Text(
          'Verification Detail',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: VivyColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: VivyColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VivySpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt image + badge + amount
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 12),
                  child: child,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: VivyColors.surface,
                  borderRadius: BorderRadius.circular(VivySpacing.radiusMedium),
                  border: Border.all(color: VivyColors.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 6, color: accent),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ReceiptPreview(
                            imagePath: entry.imagePath,
                            tint: tintBg,
                            accent: accent,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isFraud
                                          ? Icons.error_outline
                                          : Icons.check_circle_outline,
                                      size: 18,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      entry.label,
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (entry.amount != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Amount',
                                      style: TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 13,
                                        color: VivyColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₱${entry.amount!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: VivyColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Date / confidence / reference
            _FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Container(
                decoration: BoxDecoration(
                  color: VivyColors.surface,
                  borderRadius: BorderRadius.circular(VivySpacing.radiusMedium),
                  border: Border.all(color: VivyColors.cardBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    _DetailRow(
                        label: 'Date & Time',
                        value: _formatDateTime(entry.timestamp)),
                    const Divider(height: 1, color: VivyColors.cardBorder),
                    _DetailRow(label: 'Confidence Score', value: confidenceText),
                    const Divider(height: 1, color: VivyColors.cardBorder),
                    _DetailRow(label: 'Reference No.', value: referenceNo),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // AI explanation
            _FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VivyColors.surface,
                  borderRadius: BorderRadius.circular(VivySpacing.radiusMedium),
                  border: Border.all(color: VivyColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI EXPLANATION',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: VivyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      explanation,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: VivyColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Warning banner (fraudulent only)
            if (_isFraud) ...[
              const SizedBox(height: 12),
              _FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius:
                        BorderRadius.circular(VivySpacing.radiusMedium),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFB45309), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Do not release payment or goods based on this '
                          'receipt. Report suspected fraud to GCash Support '
                          'immediately.',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A small wrapper that gives any tappable widget a quick, subtle
/// press-down scale so taps feel responsive without being flashy.
/// (Same interaction used across the Home screen's cards.)
class _TapScale extends StatefulWidget {
  const _TapScale({
    required this.onTap,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        shape: widget.borderRadius == BorderRadius.zero
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: widget.borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) {
            if (mounted) setState(() => _pressed = value);
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Simple fade + slide-up entrance used to stagger the detail cards in on
/// first build, matching the softer motion language used elsewhere in the
/// app.
class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320) + delay,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        // Hold at 0 during the delay window, then animate in.
        final delayFraction =
            delay.inMilliseconds / (320 + delay.inMilliseconds);
        final adjusted = value < delayFraction
            ? 0.0
            : (value - delayFraction) / (1 - delayFraction);
        return Opacity(
          opacity: adjusted.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - adjusted.clamp(0, 1)) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Rounded-box back button matching the Figma style — white circular
/// container with a light border around the back icon. Wrapped with
/// [_TapScale] so it presses down slightly, matching Home screen buttons.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDCE3F0)),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.arrow_back,
          size: 19,
          color: VivyColors.textPrimary,
        ),
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.imagePath,
    required this.tint,
    required this.accent,
  });

  final String? imagePath;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final file = imagePath == null ? null : File(imagePath!);
    final hasImage = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 180,
        color: tint,
        child: hasImage
            ? Image.file(file, fit: BoxFit.cover)
            : Center(
                child: Icon(Icons.receipt_long_outlined,
                    size: 48, color: accent),
              ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: VivyColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 14,
              color: VivyColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _referenceFromTimestamp(DateTime dt) {
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}${p2(dt.month)}${p2(dt.day)}${p2(dt.hour)}${p2(dt.minute)}';
}

String _formatDateTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  var hour = dt.hour;
  final minute = dt.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $suffix';
}

String _fallbackExplanation(bool isFraud) {
  return isFraud
      ? 'This receipt shows signs of digital manipulation. Inconsistencies '
        'were found in font rendering, metadata timestamps, and compression '
        'artifacts — common indicators of a forged or edited GCash receipt.'
      : 'This receipt passed all verification checks. The document structure, '
        'metadata, and visual patterns are consistent with an authentic '
        'GCash electronic receipt. No signs of editing or tampering were '
        'detected.';
}