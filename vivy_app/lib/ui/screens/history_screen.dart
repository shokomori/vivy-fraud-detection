import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/analysis_models.dart';
import '../theme/vivy_colors.dart';
import '../theme/vivy_spacing.dart';
import '../theme/vivy_text_styles.dart';
import 'verification_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.entries,
    this.entriesListenable,
    this.onDeleteEntry,
    this.onClearAll,
  });

  final List<HistoryEntry> entries;
  final ValueNotifier<List<HistoryEntry>>? entriesListenable;
  final Future<void> Function(HistoryEntry)? onDeleteEntry;
  final Future<void> Function()? onClearAll;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late ValueNotifier<List<HistoryEntry>> _entriesNotifier;

  @override
  void initState() {
    super.initState();
    _entriesNotifier = widget.entriesListenable ??
        ValueNotifier<List<HistoryEntry>>(List<HistoryEntry>.from(widget.entries));
    _entriesNotifier.value = List<HistoryEntry>.from(widget.entries);
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entriesListenable != oldWidget.entriesListenable) {
      if (oldWidget.entriesListenable == null) {
        _entriesNotifier.dispose();
      }
      _entriesNotifier = widget.entriesListenable ??
          ValueNotifier<List<HistoryEntry>>(List<HistoryEntry>.from(widget.entries));
    }
    if (widget.entriesListenable == null &&
        !identical(oldWidget.entries, widget.entries)) {
      _entriesNotifier.value = List<HistoryEntry>.from(widget.entries);
    }
  }

  @override
  void dispose() {
    if (widget.entriesListenable == null) {
      _entriesNotifier.dispose();
    }
    super.dispose();
  }

  Future<void> _handleDeleteEntry(HistoryEntry item) async {
    final updated = _entriesNotifier.value.where((entry) => entry != item).toList();
    _entriesNotifier.value = updated;
    await widget.onDeleteEntry?.call(item);
  }

  Future<void> _handleClearAll() async {
    _entriesNotifier.value = <HistoryEntry>[];
    await widget.onClearAll?.call();
  }

  void _openDetail(BuildContext context, HistoryEntry item) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) =>
            VerificationDetailScreen(
              entry: item,
            onDelete: widget.onDeleteEntry != null
              ? () => _handleDeleteEntry(item)
                  : null,
            ),
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
      ),
    );
  }

  /// Shows the delete confirmation dialog and resolves to `true` only if
  /// the user confirms. Used both by the swipe-to-delete gesture (via
  /// [Dismissible.confirmDismiss]) so the card doesn't disappear until the
  /// user actually confirms.
  Future<bool> _confirmDelete(BuildContext context) {
    return _showVivyConfirmDialog(
      context,
      title: 'Delete Record?',
      message:
          'Are you sure you want to delete this verification record? This action cannot be undone.',
      confirmLabel: 'Delete',
    );
  }

  Future<void> _showClearAllConfirmation(BuildContext context) async {
    final confirmed = await _showVivyConfirmDialog(
      context,
      title: 'Clear History?',
      message:
          'Are you sure you want to clear your entire verification history? This action cannot be undone.',
      confirmLabel: 'Clear All',
    );
    if (confirmed) {
      await _handleClearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<HistoryEntry>>(
      valueListenable: widget.entriesListenable ?? _entriesNotifier,
      builder: (context, entries, _) {
        final displayEntries = entries;
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
            actions: displayEntries.isNotEmpty && widget.onClearAll != null
                ? [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _TapScale(
                        onTap: () => _showClearAllConfirmation(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F5FB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: VivyColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ]
                : null,
          ),
          body: displayEntries.isEmpty
              ? Center(
                  child: Text(
                    'No local history yet.',
                    style: VivyTextStyles.body.copyWith(
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    VivySpacing.pagePadding,
                    VivySpacing.pagePadding,
                    VivySpacing.pagePadding,
                    VivySpacing.pagePadding +
                        MediaQuery.of(context).padding.bottom +
                        22,
                  ),
                  itemCount: displayEntries.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = displayEntries[index];
                    final labelLower = item.label.toLowerCase();
                    final isFraud = labelLower == 'fraudulent';
                    final isGenuine = labelLower == 'genuine';

                    late Color accent, tintBg;
                    if (isFraud) {
                      accent = const Color(0xFFDC2626);
                      tintBg = const Color(0xFFF8D9D9);
                    } else if (isGenuine) {
                      accent = const Color(0xFF059669);
                      tintBg = const Color(0xFFCFF2DE);
                    } else {
                      // fallback state for any non-genuine result
                      accent = const Color(0xFF6B7280);
                      tintBg = const Color.fromARGB(213, 235, 234, 234);
                    }
                    final confidenceText = item.confidence == null
                        ? 'N/A'
                        : '${(item.confidence! * 100).toStringAsFixed(1)}%';

                    final card = _TapScale(
                      borderRadius: BorderRadius.circular(VivySpacing.radiusMedium),
                      onTap: () => _openDetail(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: tintBg,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            item.label,
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Plus Jakarta Sans',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule,
                                          size: 13,
                                          color: VivyColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          _formatShort(item.timestamp),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Plus Jakarta Sans',
                                            fontSize: 12,
                                            color: VivyColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  confidenceText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    color: VivyColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.amount != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '₱${item.amount!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: VivyColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    // Swipe-to-delete: only enabled when a delete handler is
                    // actually wired up (mirrors the old X-button condition).
                    if (widget.onDeleteEntry == null) {
                      return card;
                    }

                    return Dismissible(
                      key: ObjectKey(item),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(context),
                      onDismissed: (_) => _handleDeleteEntry(item),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius:
                              BorderRadius.circular(VivySpacing.radiusMedium),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      child: card,
                    );
                  },
                ),
        );
      },
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

/// A destructive-confirmation dialog styled to match the rest of the app:
/// rounded surface card, tinted icon badge, ExtraBold title, and SemiBold
/// body/button copy — all in Plus Jakarta Sans. Resolves to `true` only
/// when the destructive action is confirmed.
Future<bool> _showVivyConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  const destructive = Color(0xFFDC2626);
  const destructiveTint = Color(0xFFF8D9D9);

  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: VivyColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VivyColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: destructiveTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                color: destructive,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800, // ExtraBold
                fontSize: 18,
                color: VivyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w600, // SemiBold
                fontSize: 13.5,
                height: 1.45,
                color: VivyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogButton(
                    label: confirmLabel,
                    filled: true,
                    color: destructive,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Pill-shaped dialog action button, reusing the same tap-scale interaction
/// as the rest of the app's tappable surfaces so the dialog feels native
/// to the screen rather than a stock system alert.
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? VivyColors.textPrimary;
    return _TapScale(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? accent : const Color(0xFFF3F5FB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w600, // SemiBold
            fontSize: 14.5,
            color: filled ? Colors.white : VivyColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Custom fade + slide-up transition used when opening a history entry's
/// detail screen, giving the navigation a softer feel than the default
/// platform slide (echoes the motion used by the "How to Use" sheet on
/// Home).
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