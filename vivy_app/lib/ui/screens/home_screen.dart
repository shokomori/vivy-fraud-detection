import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/analysis_models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.entries,
    required this.onUploadVerify,
    required this.onOpenHistory,
    required this.onOpenLearnMore,
    required this.onOpenMessengerQr,
  });

  final List<HistoryEntry> entries;
  final VoidCallback onUploadVerify;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenLearnMore;
  final VoidCallback onOpenMessengerQr;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _tipsExpanded = false;

  void _showHowToModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(110),
      constraints: const BoxConstraints(maxWidth: 390),
      builder: (_) => const _HowToUseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _SummaryStats.fromEntries(widget.entries);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        iconTheme: Theme.of(context).iconTheme.copyWith(color: Colors.white),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A3D8F),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: Image.asset(
                        'assets/vivy_assets/vivy_logo.PNG',
                        fit: BoxFit.contain,
                        width: 30,
                        height: 30,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('vivy_logo.PNG failed to load: $error');
                          return Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'V',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ViVy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -0.3,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _showHowToModal,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.14),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(10),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: SvgPicture.asset(
                            'assets/vivy_assets/question_mark.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Color(0xFF9FC0EE),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.08,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Stay Protected.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.02,
                      letterSpacing: -0.45,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F4FB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      14,
                      14,
                      14,
                      20 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      children: [
                        _UploadCard(onTap: widget.onUploadVerify),
                        const SizedBox(height: 10),
                        _SummaryCard(stats: stats),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniActionCard(
                                title: 'History',
                                subtitle: '${stats.total} results saved',
                                iconAsset: 'assets/vivy_assets/history.svg',
                                iconBackground: const Color(0xFFCCFBF1),
                                onTap: widget.onOpenHistory,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MiniActionCard(
                                title: 'Learn More',
                                subtitle: 'About fraud',
                                iconAsset: 'assets/vivy_assets/learn.svg',
                                iconBackground: const Color(0xFFFFF1D6),
                                onTap: widget.onOpenLearnMore,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _QrCard(onTap: widget.onOpenMessengerQr),
                        const SizedBox(height: 10),
                        _TipsCard(
                          expanded: _tipsExpanded,
                          onToggle: () {
                            setState(() {
                              _tipsExpanded = !_tipsExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small wrapper that gives any tappable card a quick, subtle
/// press-down scale so taps feel responsive without being flashy.
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
        borderRadius: widget.borderRadius,
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

/// The "How to Use ViVy" walkthrough sheet.
///
/// Sized to exactly 390x490 and anchored to the bottom of the screen so it
/// sits just below the Upload & Verify card on the Home screen behind it.
class _HowToUseSheet extends StatefulWidget {
  const _HowToUseSheet();

  @override
  State<_HowToUseSheet> createState() => _HowToUseSheetState();
}

class _HowToUseSheetState extends State<_HowToUseSheet> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _steps = [
    (
      title: 'Step 1: Upload a Receipt',
      description:
          "Tap 'Upload & Verify Receipt' on the Home screen. Pick a photo from your gallery to begin.",
      art: _HowToArtType.upload,
      cta: 'Next',
    ),
    (
      title: 'Step 2: AI Analysis',
      description:
          'ViVy scans the receipt image for signs of tampering, inconsistencies, and anomalies.',
      art: _HowToArtType.analysis,
      cta: 'Next',
    ),
    (
      title: 'Step 3: Review Results',
      description:
          'Get an instant Genuine or Fraudulent verdict with a clear explanation. Results are saved automatically to History.',
      art: _HowToArtType.result,
      cta: "Let's Go!",
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 490,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'How to Use ViVy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Plus Jakarta Sans',
                        height: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE9EEF7),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    color: const Color(0xFF334155),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 150,
                          child: Center(
                            child: _HowToArt(type: step.art),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Plus Jakarta Sans',
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontFamily: 'Plus Jakarta Sans',
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (dotIndex) {
                      final active = dotIndex == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 30 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF174AA5)
                              : const Color(0xFFC8D4E5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF174AA5),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _steps[_index].cta,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HowToArtType { upload, analysis, result }

class _HowToArt extends StatelessWidget {
  const _HowToArt({required this.type});

  final _HowToArtType type;

  @override
  Widget build(BuildContext context) {
    final asset = switch (type) {
      _HowToArtType.upload => 'assets/vivy_assets/scan.svg',
      _HowToArtType.analysis => 'assets/vivy_assets/security_check.svg',
      _HowToArtType.result => 'assets/vivy_assets/green_check.svg',
    };

    return SvgPicture.asset(
      asset,
      width: 150,
      height: 150,
      fit: BoxFit.contain,
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D5FD4), Color(0xFF0A3D8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A3D8F).withOpacity(0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A3D8F).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/vivy_assets/upload_transparent.svg',
                  fit: BoxFit.contain,
                  width: 28,
                  height: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Upload & Verify\nReceipt',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: -0.3,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tap to check any GCash receipt now',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFDBEAFE),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A3D8F).withOpacity(0.4),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/vivy_assets/back_transparent.svg',
                fit: BoxFit.contain,
                width: 20,
                height: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats});

  final _SummaryStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF7), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3D8F).withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: Color(0xFF0D9488),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/vivy_assets/summary_line.svg',
                  width: 14,
                  height: 14,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 6),
                const Text(
                  'YOUR SCAN SUMMARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryPill(
                    value: '${stats.total}',
                    label: 'Scans',
                    valueColor: const Color(0xFF0A3D8F),
                    background: const Color(0xFFE8EFFC),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryPill(
                    value: '${stats.genuine}',
                    label: 'Genuine',
                    valueColor: const Color(0xFF059669),
                    background: const Color(0xFFDCFCE7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryPill(
                    value: '${stats.flagged}',
                    label: 'Flagged',
                    valueColor: const Color(0xFFDC2626),
                    background: const Color(0xFFFEE2E2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Safe rate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7A99),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ),
                Text(
                  '${stats.safeRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0A3D8F),
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (stats.safeRate / 100).clamp(0, 1),
                minHeight: 5,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: const Color(0xFFE3EAF7),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_outlined,
                      size: 15,
                      color: Color(0xFF6B7A99),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7A99),
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                          children: _buildLastScanTextSpans(stats.lastScanText, stats.lastScanColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.background,
  });

  final String value;
  final String label;
  final Color valueColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (label == 'Genuine')
                SvgPicture.asset(
                  'assets/vivy_assets/genuine_shield.svg',
                  width: 15,
                  height: 15,
                  fit: BoxFit.contain,
                )
              else if (label == 'Flagged')
                SvgPicture.asset(
                  'assets/vivy_assets/fraudulent_warning.svg',
                  width: 15,
                  height: 15,
                  fit: BoxFit.contain,
                ),
              if (label == 'Genuine' || label == 'Flagged') const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7A99),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              fontFamily: 'Plus Jakarta Sans',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionCard extends StatelessWidget {
  const _MiniActionCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.iconBackground,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final Color iconBackground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4EAF6), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A3D8F).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: SvgPicture.asset(
                iconAsset,
                fit: BoxFit.contain,
                width: 30,
                height: 30,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E1726),
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.2,
                      color: Color(0xFF6B7A99),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4EAF6), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A3D8F).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: SvgPicture.asset(
                'assets/vivy_assets/qr.svg',
                fit: BoxFit.contain,
                width: 34,
                height: 34,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Facebook Receipt QR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E1726),
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Let customers send you receipts to scan',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7A99),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A3D8F).withOpacity(0.1),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/vivy_assets/back_transparent.svg',
                fit: BoxFit.contain,
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF0A3D8F),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4D888), width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    child: const Text(
                      '💡',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tips for Staying Safe',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8A5603),
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: expanded ? 0.25 : 0,
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                        child: const Text(
                          '>',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF8A5603),
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE4D888))),
              ),
              child: const Text(
                'Always verify a GCash receipt before releasing goods or services. Fraudulent receipts often look identical to real ones. When in doubt, confirm payment inside the GCash app directly.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF875705),
                  height: 1.35,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStats {
  const _SummaryStats({
    required this.total,
    required this.genuine,
    required this.flagged,
    required this.safeRate,
    required this.lastScanText,
    required this.lastScanColor,
  });

  final int total;
  final int genuine;
  final int flagged;
  final double safeRate;
  final String lastScanText;
  final Color lastScanColor;

  static _SummaryStats fromEntries(List<HistoryEntry> entries) {
    var genuine = 0;
    var flagged = 0;

    for (final entry in entries) {
      final label = entry.label.toLowerCase();
      if (label == 'genuine') {
        genuine++;
      } else if (label == 'fraudulent') {
        flagged++;
      }
    }

    // Total includes all records: Genuine, Fraudulent, Unclear, and Not a GCash Receipt
    final total = entries.length;
    final safeRate = total == 0 ? 0.0 : (genuine / total) * 100;

    final last = entries.isEmpty
      ? 'Last scan: No scans yet'
        : _formatLastScan(entries.first);
    final lastScanColor = entries.isEmpty
        ? const Color(0xFF6B7A99)
        : _scanColorForLabel(entries.first.label);

    return _SummaryStats(
      total: total,
      genuine: genuine,
      flagged: flagged,
      safeRate: safeRate,
      lastScanText: last,
      lastScanColor: lastScanColor,
    );
  }

  static String _formatLastScan(HistoryEntry entry) {
    final confidenceText = entry.confidence == null
        ? ''
        : ' - ${(entry.confidence! * 100).toStringAsFixed(1)}%';
    return 'Last scan: ${entry.label}$confidenceText';
  }

  static Color _scanColorForLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized == 'genuine') {
      return const Color(0xFF059669);
    }
    if (normalized == 'unclear' || normalized == 'fraudulent') {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF6B7A99);
  }
}

List<TextSpan> _buildLastScanTextSpans(String text, Color resultColor) {
  final prefix = 'Last scan: ';
  final prefixIndex = text.indexOf(prefix);
  if (prefixIndex == -1) {
    return [TextSpan(text: text)];
  }

  final prefixText = text.substring(0, prefixIndex + prefix.length);
  final remainder = text.substring(prefixIndex + prefix.length);
  final resultText = remainder.trim();

  if (resultText.isEmpty) {
    return [TextSpan(text: text)];
  }

  return [
    TextSpan(text: prefixText),
    TextSpan(text: resultText, style: TextStyle(color: resultColor)),
  ];
}