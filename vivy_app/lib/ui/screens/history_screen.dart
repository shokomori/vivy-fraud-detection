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
    this.onDeleteEntry,
    this.onClearAll,
  });

  final List<HistoryEntry> entries;
  final Future<void> Function(HistoryEntry)? onDeleteEntry;
  final Future<void> Function()? onClearAll;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<HistoryEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List<HistoryEntry>.from(widget.entries);
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries)) {
      _entries = List<HistoryEntry>.from(widget.entries);
    }
  }

  Future<void> _handleDeleteEntry(HistoryEntry item) async {
    if (mounted) {
      setState(() {
        _entries = _entries.where((entry) => entry != item).toList();
      });
    }
    await widget.onDeleteEntry?.call(item);
  }

  Future<void> _handleClearAll() async {
    if (mounted) {
      setState(() {
        _entries = <HistoryEntry>[];
      });
    }
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

  void _showDeleteConfirmation(BuildContext context, HistoryEntry item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text(
          'Are you sure you want to delete this verification record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _handleDeleteEntry(item);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text(
          'Are you sure you want to clear your entire verification history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _handleClearAll();
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
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
        actions: _entries.isNotEmpty && widget.onClearAll != null
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
      body: _entries.isEmpty
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
              itemCount: _entries.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _entries[index];
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
                  // unclear, not receipt, error, and any other warning states
                  accent = const Color(0xFFD97706);
                  tintBg = const Color(0xFFFFF2D9);
                }
                final confidenceText = item.confidence == null
                  ? 'N/A'
                  : '${(item.confidence! * 100).toStringAsFixed(1)}%';

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
                              const SizedBox(height: 4),
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        if (widget.onDeleteEntry != null) ...[
                          const SizedBox(width: 8),
                          _TapScale(
                            onTap: () => _showDeleteConfirmation(context, item),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: VivyColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
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