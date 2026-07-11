import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/vivy_colors.dart';
import '../theme/vivy_spacing.dart';

class GuidelinesScreen extends StatefulWidget {
  const GuidelinesScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends State<GuidelinesScreen> {
  static const _items = [
    (
      type: _GuidelineArtType.scanConfidence,
      title: 'Scan with Confidence',
      subtitle:
          'Use ViVy to quickly check if a GCash receipt looks genuine before accepting it.',
    ),
    (
      type: _GuidelineArtType.reviewDetails,
      title: 'Review Critical Details',
      subtitle:
          'Follow the in-app checks and warnings to avoid suspicious or manipulated receipts.',
    ),
    (
      type: _GuidelineArtType.stayProtected,
      title: 'Stay Protected',
      subtitle:
          'Keep your transactions safer with a fast local analysis workflow.',
    ),
  ];

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _items.length - 1) {
      widget.onComplete();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _items.length - 1;

    return Scaffold(
      backgroundColor: VivyColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VivySpacing.pagePadding),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              color: const Color(0xFFE8EEF8),
                              border: Border.all(color: const Color(0xFFD5DFEF)),
                            ),
                            child: _GuidelineArt(type: item.type),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: VivyColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: VivyColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_items.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? VivyColors.primaryBlue
                          : VivyColors.divider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: VivyColors.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        VivySpacing.radiusMedium,
                      ),
                    ),
                  ),
                  child: Text(isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _GuidelineArtType { scanConfidence, reviewDetails, stayProtected }

class _GuidelineArt extends StatelessWidget {
  const _GuidelineArt({required this.type});

  final _GuidelineArtType type;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      _GuidelineArtType.scanConfidence => const _ScanConfidenceArt(),
      _GuidelineArtType.reviewDetails => const _ReviewDetailsArt(),
      _GuidelineArtType.stayProtected => const _StayProtectedArt(),
    };
  }
}

class _ScanConfidenceArt extends StatelessWidget {
  const _ScanConfidenceArt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: SvgPicture.asset('assets/vivy_assets/security.svg'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: SvgPicture.asset('assets/vivy_assets/security_check.svg'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 48,
            height: 48,
            child: SvgPicture.asset('assets/vivy_assets/analysis.svg'),
          ),
        ],
      ),
    );
  }
}

class _ReviewDetailsArt extends StatelessWidget {
  const _ReviewDetailsArt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: SvgPicture.asset('assets/vivy_assets/redflags.svg'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 52,
            height: 52,
            child: SvgPicture.asset('assets/vivy_assets/warning.svg'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 80,
            height: 38,
            child: SvgPicture.asset('assets/vivy_assets/list.svg'),
          ),
        ],
      ),
    );
  }
}

class _StayProtectedArt extends StatelessWidget {
  const _StayProtectedArt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: SvgPicture.asset('assets/vivy_assets/secure.svg'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: SvgPicture.asset('assets/vivy_assets/checkmark.svg'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 90,
            height: 40,
            child: SvgPicture.asset('assets/vivy_assets/scan.svg'),
          ),
        ],
      ),
    );
  }
}
