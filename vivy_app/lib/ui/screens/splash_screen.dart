import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // remove if you bundle the font locally instead

import '../theme/vivy_colors.dart';

/// Splash screen for ViVy — GCash e-receipt authenticity checker.
///
/// Plays a short, layered entrance animation:
///   1. Logo glows in and bounces up to full size.
///   2. "ViVy" wordmark fades and slides up.
///   3. Subtitle fades and slides up.
///   4. A breathing 3-dot loader loops until [onFinished] fires.
class SplashScreen extends StatefulWidget {
  /// Called once the entrance animation has finished playing, so the
  /// caller can navigate away (e.g. to an auth check or home screen).
  final VoidCallback? onFinished;

  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _loop;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleOffset;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    // Separate, continuously-looping controller for the dot indicator so
    // it keeps breathing after the one-shot entrance animation completes.
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _logoOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    _glowOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.05, 0.55, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _titleOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );

    _titleOffset = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
    );

    _subtitleOffset = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _entrance.forward();

    // Give the caller a hook to navigate once the splash has had time to
    // finish its animation and be read by the user.
    _navTimer = Timer(const Duration(milliseconds: 2600), () {
      widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Keep the logo proportionate on both small and large screens.
    final logoSize = math.min(140.0, width * 0.36);

    return Scaffold(
      backgroundColor: VivyColors.primaryBlue,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLogo(logoSize),
              SizedBox(height: logoSize * 0.14),
              _buildTitle(),
              const SizedBox(height: 8),
              _buildSubtitle(width),
              const SizedBox(height: 56),
              _buildDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double size) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        return Opacity(
          opacity: _logoOpacity.value,
          child: Transform.scale(scale: _logoScale.value, child: child),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow behind the icon for a "flashy" feel.
          AnimatedBuilder(
            animation: _glowOpacity,
            builder: (context, _) {
              return Container(
                width: size * 1.35,
                height: size * 1.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // Swap for VivyColors.accentCyan (or similar) if your
                      // theme already defines the icon's cyan accent.
                      color: const Color(0xFF3AD7E0)
                          .withOpacity(0.35 * _glowOpacity.value),
                      blurRadius: 55,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              );
            },
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/vivy_assets/vivy_logo.PNG',
              width: size,
              height: size,
              fit: BoxFit.contain,
              semanticLabel: 'ViVy Logo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return FadeTransition(
      opacity: _titleOpacity,
      child: SlideTransition(
        position: _titleOffset,
        child: Text(
          'ViVy',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800, // ExtraBold
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(double screenWidth) {
    return FadeTransition(
      opacity: _subtitleOpacity,
      child: SlideTransition(
        position: _subtitleOffset,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.12),
          child: Text(
            'GCASH E-RECEIPT AUTHENTICITY CHECKER',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600, // SemiBold
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return FadeTransition(
      opacity: _subtitleOpacity,
      child: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Stagger each dot by 0.2 of the loop, wrapped to stay positive.
              final phase = ((_loop.value - i * 0.2) % 1.0 + 1.0) % 1.0;
              final pulse = 1 - (2 * phase - 1).abs(); // 0 -> 1 -> 0
              final scale = 0.65 + 0.45 * pulse;
              final opacity = 0.35 + 0.65 * pulse;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}