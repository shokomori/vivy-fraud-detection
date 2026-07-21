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
      asset: 'assets/vivy_assets/scan.svg',
      title: 'Scan Any GCash Receipt',
      subtitle:
          'Upload a photo of any GCash electronic payment receipt to begin instant verification.',
    ),
    (
      asset: 'assets/vivy_assets/security_check.svg',
      title: 'AI-Powered Detection',
      subtitle:
          'Our machine learning model scans for tampering and visual inconsistencies in seconds.',
    ),
    (
      asset: 'assets/vivy_assets/checkmark.svg',
      title: 'Instant, Clear Results',
      subtitle:
          'Get an immediate Genuine or Fraudulent verdict with a detailed explanation — and save it to your history.',
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
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: VivyColors.primaryBlue,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            item.asset,
                            width: 160,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: VivyColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              item.subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: VivyColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  child: Text(
                    isLast ? 'Tap to Start →' : 'Next',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
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