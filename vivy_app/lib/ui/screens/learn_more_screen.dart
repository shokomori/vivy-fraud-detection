import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class LearnMoreScreen extends StatefulWidget {
  const LearnMoreScreen({super.key});

  @override
  State<LearnMoreScreen> createState() => _LearnMoreScreenState();
}

class _LearnMoreScreenState extends State<LearnMoreScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const int _count = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchUri(String uri) async {
    final parsed = Uri.parse(uri);
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  void _next() {
    if (_index == _count - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).pop();
      return;
    }
    _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFE8ECF4),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 14, 8),
                child: Row(
                  children: [
                    const Text(
                      'Learn More',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        height: 1,
                        letterSpacing: -0.3,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                    const Spacer(),
                    _TapScale(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE2E8F0),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _index = value),
                  children: [
                    const _LearnMoreStep(
                      key: ValueKey('step0'),
                      iconAsset: 'assets/vivy_assets/redflags.svg',
                      title: 'What is Receipt Fraud?',
                      body:
                          "GCash receipt fraud involves digitally editing or fabricating electronic payment receipts to falsely show a completed transaction. Scammers use image editors to alter amounts, dates, and reference numbers.",
                    ),
                    const _LearnMoreStep(
                      key: ValueKey('step1'),
                      iconAsset: 'assets/vivy_assets/list.svg',
                      title: 'Common Red Flags',
                      body:
                          "Watch out for blurry fonts, mismatched colors, unusual compression artifacts, or reference numbers that don't follow GCash's standard 12-digit format starting with the transaction date.",
                    ),
                    const _LearnMoreStep(
                      key: ValueKey('step2'),
                      iconAsset: 'assets/vivy_assets/security.svg',
                      title: 'Stay Protected',
                      body:
                          'Always verify receipts with ViVy before releasing goods. Confirm payments directly in the GCash app. Never rely solely on a screenshot shared by the buyer.',
                    ),
                    _HelpDeskStep(onLaunchUri: _launchUri),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_count, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF174AA5)
                                : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (_index == 0)
                      _TapScale(
                        onTap: _next,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF174AA5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                              fontFamily: 'Plus Jakarta Sans',
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _TapScale(
                              onTap: _back,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFB9C6DB),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Back',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Color(0xFF0A3D8F),
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TapScale(
                              onTap: _next,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF174AA5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _index == _count - 1 ? 'Got it!' : 'Next',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
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
        ),
      ),
    );
  }
}

/// A small wrapper that gives any tappable element a quick, subtle
/// press-down scale so taps feel responsive without being flashy.
/// Mirrors the `_TapScale` behavior used on the Home screen.
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

/// Fades and slides its content in on first build, giving each carousel
/// page a gentle entrance animation as it becomes visible.
class _StepEntrance extends StatefulWidget {
  const _StepEntrance({required this.child});

  final Widget child;

  @override
  State<_StepEntrance> createState() => _StepEntranceState();
}

class _StepEntranceState extends State<_StepEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _LearnMoreStep extends StatelessWidget {
  const _LearnMoreStep({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.body,
  });

  final String iconAsset;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + ConstrainedBox lets the content truly center itself
    // vertically within the available space, instead of just hugging the
    // top of the scroll view.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight -
                  24 -
                  8, // account for vertical padding above
            ),
            child: _StepEntrance(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 150,
                    child: Center(
                      child: SvgPicture.asset(
                        iconAsset,
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      height: 1.1,
                      letterSpacing: -0.3,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      height: 1.5,
                      fontFamily: 'Plus Jakarta Sans',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HelpDeskStep extends StatelessWidget {
  const _HelpDeskStep({required this.onLaunchUri});

  final Future<void> Function(String uri) onLaunchUri;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: _StepEntrance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 150,
              child: Center(
                child: SvgPicture.asset(
                  'assets/vivy_assets/help.svg',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Help Desks & Contacts',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                height: 1.1,
                letterSpacing: -0.3,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            const SizedBox(height: 14),
            _ContactCard(
              dotColor: const Color(0xFF0D9488),
              title: 'GCash Support',
              lines: const ['help.gcash.com'],
              onTapLine: (line) async {
                if (line == 'help.gcash.com') {
                  await onLaunchUri('https://help.gcash.com');
                }
              },
            ),
            const SizedBox(height: 8),
            _ContactCard(
              dotColor: const Color(0xFF0A3D8F),
              title: 'BSP Consumer Assistance',
              lines: const ['(02) 5306-2584', 'consumeraffairs@bsp.gov.ph'],
              onTapLine: (line) async {
                if (line == '(02) 5306-2584') {
                  await onLaunchUri('tel:(02)5306-2584');
                } else if (line == 'consumeraffairs@bsp.gov.ph') {
                  await onLaunchUri('mailto:consumeraffairs@bsp.gov.ph');
                }
              },
            ),
            const SizedBox(height: 8),
            _ContactCard(
              dotColor: const Color(0xFFDC2626),
              title: 'PNP Anti-Cybercrime Group',
              lines: const ['+63 (02) 8723-0401', 'cpiu.acg@pnp.gov.ph'],
              onTapLine: (line) async {
                if (line == '+63 (02) 8723-0401') {
                  await onLaunchUri('tel:+630287230401');
                } else if (line == 'cpiu.acg@pnp.gov.ph') {
                  await onLaunchUri('mailto:cpiu.acg@pnp.gov.ph');
                }
              },
            ),
            const SizedBox(height: 8),
            _ContactCard(
              dotColor: const Color(0xFFD97706),
              title: 'DTI Consumer Hotline',
              lines: const ['1-DTI (384)', 'ftesb@dti.gov.ph'],
              onTapLine: (line) async {
                if (line == '1-DTI (384)') {
                  await onLaunchUri('tel:1384');
                } else if (line == 'ftesb@dti.gov.ph') {
                  await onLaunchUri('mailto:ftesb@dti.gov.ph');
                }
              },
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Keep records of the fraudulent receipt and reference number before reporting.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  height: 1.4,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.dotColor,
    required this.title,
    required this.lines,
    required this.onTapLine,
  });

  final Color dotColor;
  final String title;
  final List<String> lines;
  final Future<void> Function(String line) onTapLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: dotColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                const SizedBox(height: 2),
                // All contact lines rendered side by side, separated by a
                // dot, rather than stacked underneath each other.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (int i = 0; i < lines.length; i++) ...[
                      if (i > 0)
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                        ),
                      _TapScale(
                        onTap: () => onTapLine(lines[i]),
                        child: Text(
                          lines[i],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF93C5FD),
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                        ),
                      ),
                    ],
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