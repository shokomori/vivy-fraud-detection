import 'package:flutter/material.dart';

import '../../domain/analysis_models.dart';
import '../theme/vivy_colors.dart';
import '../theme/vivy_spacing.dart';
import '../theme/vivy_text_styles.dart';
import 'verification_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.entries});

  final List<HistoryEntry> entries;

  void _openDetail(BuildContext context, HistoryEntry item) {
    Navigator.of(context).push(_detailRoute(item));
  }

  @override
  Widget build(BuildContext context) {
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
          'Verification History',
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
      body: entries.isEmpty
          ? Center(
              child: Text(
                'No local history yet.',
                style: VivyTextStyles.body.copyWith(
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(VivySpacing.pagePadding),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = entries[index];
                final isFraud = item.label.toLowerCase() == 'fraudulent';
                final accent =
                    isFraud ? const Color(0xFFDC2626) : const Color(0xFF059669);
                final tintBg =
                    isFraud ? const Color(0xFFF8D9D9) : const Color(0xFFCFF2DE);
                final confidenceText = item.confidence == null
                    ? 'N/A confidence'
                    : '${(item.confidence! * 100).toStringAsFixed(1)}% confidence';

                return _TapScale(
                  borderRadius: BorderRadius.circular(VivySpacing.radiusMedium),
                  onTap: () => _openDetail(context, item),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: VivyColors.surface,
                      borderRadius:
                          BorderRadius.circular(VivySpacing.radiusMedium),
                      border: Border.all(color: VivyColors.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tintBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.receipt_long_outlined,
                              color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tintBg,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 13,
                                      color: VivyColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatShort(item.timestamp),
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 12,
                                      color: VivyColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.amount != null)
                              Text(
                                '₱${item.amount!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: VivyColors.textPrimary,
                                ),
                              ),
                            Text(
                              confidenceText,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                color: VivyColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// A small wrapper that gives any tappable card a quick, subtle
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
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius:
            widget.borderRadius == BorderRadius.zero ? null : widget.borderRadius,
        shape: widget.borderRadius == BorderRadius.zero
            ? const CircleBorder()
            : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.borderRadius,
          onHighlightChanged: (value) {
            if (mounted) setState(() => _pressed = value);
          },
          child: widget.child,
        ),
      ),
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

/// Custom fade + slide-up transition used when opening a history entry's
/// detail screen, giving the navigation a softer feel than the default
/// platform slide (echoes the motion used by the "How to Use" sheet on
/// Home).
Route<void> _detailRoute(HistoryEntry entry) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        VerificationDetailScreen(entry: entry),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

String _formatShort(DateTime dt) {
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