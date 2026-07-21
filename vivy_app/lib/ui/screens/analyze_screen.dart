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
        child: _BackButton(onTap: () => Navigator.of(context).maybePop()),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1D2638),
          fontFamily: 'Plus Jakarta Sans',
        ),
      ),
      actions: [],
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
          CustomPaint(
            painter: _DashedBorderPainter(
              color: const Color(0xFF7DD3D1),
              width: 2,
            ),
            child: Container(
              width: 350,
              height: 300,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SvgPicture.asset('assets/vivy_assets/gallery.svg'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select a Receipt Image',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2434),
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Upload your GCash e-receipt for AI verification',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Plus Jakarta Sans',
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FormatChip(label: 'JPG'),
              _FormatChip(label: 'PNG'),
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
                    fontFamily: 'Plus Jakarta Sans',
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 10),
                _TipBullet(text: 'Ensure the receipt is fully visible'),
                SizedBox(height: 10),
                _TipBullet(text: 'Download the GCash e-receipt from the app'),
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
                  fontFamily: 'Plus Jakarta Sans',
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
          SizedBox(
            width: 180,
            height: 180,
            child: SvgPicture.asset('assets/vivy_assets/analysis.svg'),
          ),
          const SizedBox(height: 26),
          const Text(
            'Analyzing Receipt',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C2536),
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verifying metadata & fonts...',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B4B95),
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),
          const SizedBox(height: 26),
          const _AnimatedProgressBar(width: 260, height: 8),
          const SizedBox(height: 20),
          const _AnimatedLoadingBars(),
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
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                const SizedBox(height: 8),
                ResultCard(result: result, threshold: threshold),
                const SizedBox(height: 12),
                _RecommendationCard(result: result),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
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
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2434),
              fontFamily: 'Plus Jakarta Sans',
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
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A658D),
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recommendations[i],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF313D52),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Plus Jakarta Sans',
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

class _AnimatedProgressBar extends StatefulWidget {
  const _AnimatedProgressBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: widget.height,
                  color: const Color(0xFFE4EAF4),
                ),
                Container(
                  width: widget.width * _animation.value,
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF17489D),
                        const Color(0xFF1B5AC7).withAlpha(200),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedLoadingBars extends StatefulWidget {
  const _AnimatedLoadingBars();

  @override
  State<_AnimatedLoadingBars> createState() => _AnimatedLoadingBarsState();
}

class _AnimatedLoadingBarsState extends State<_AnimatedLoadingBars>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      4,
      (index) => AnimationController(
        duration: Duration(milliseconds: 600 + (index * 100)),
        vsync: this,
      )..repeat(reverse: true),
    );

    _animations = _controllers
        .map((controller) => Tween<double>(begin: 0.3, end: 1.0).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeInOut),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (index) => Padding(
          padding: EdgeInsets.symmetric(horizontal: index == 0 ? 0 : 6),
          child: AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color.lerp(
                        const Color(0xFFD9E5F2),
                        const Color(0xFF17489D),
                        _animations[index].value,
                      ) ??
                      const Color(0xFF17489D),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            },
          ),
        ),
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
          fontWeight: FontWeight.w600,
          fontFamily: 'Plus Jakarta Sans',
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
            color: Color(0xFFCCFBF1),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: SvgPicture.asset('assets/vivy_assets/small_check.svg'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF313D52),
              fontWeight: FontWeight.w600,
              fontFamily: 'Plus Jakarta Sans',
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.width,
    this.dashLength = 6,
    this.gapLength = 4,
  });

  final Color color;
  final double width;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final radius = 20.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    final metrics = path.computeMetrics(forceClosed: false);
    for (var metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final extractedPath =
            metric.extractPath(distance, distance + dashLength);
        canvas.drawPath(extractedPath, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

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
        child: SvgPicture.asset(
          'assets/vivy_assets/back.svg',
          width: 40,
          height: 40,
        ),
      ),
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
      'Retake a clear and complete screenshot.',
      'Keep the receipt fully in frame.',
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
