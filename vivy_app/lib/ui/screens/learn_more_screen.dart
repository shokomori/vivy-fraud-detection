import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).pop();
      return;
    }
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECF4),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  const Text(
                    'Learn More',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE2E8F0),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      color: const Color(0xFF475569),
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
                    iconAsset: 'assets/vivy_assets/warning.svg',
                    title: 'What is Receipt Fraud?',
                    body:
                        'Receipt fraud happens when someone edits or fabricates a payment receipt to look like a successful transaction. Always verify before releasing goods or services.',
                  ),
                  const _LearnMoreStep(
                    iconAsset: 'assets/vivy_assets/redflags.svg',
                    title: 'Common Red Flags',
                    body:
                        'Watch out for blurred text, inconsistent fonts, odd spacing, missing details, and suspicious timestamps. Small visual anomalies can indicate manipulation.',
                  ),
                  const _LearnMoreStep(
                    iconAsset: 'assets/vivy_assets/secure.svg',
                    title: 'Stay Protected',
                    body:
                        'Use ViVy before every handoff, check payment in the official app when possible, and keep transaction records. Prevention is faster than dispute recovery.',
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
                        duration: const Duration(milliseconds: 200),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _back,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFB9C6DB)),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _index == 0 ? 'Close' : 'Back',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF174AA5),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _index == _count - 1 ? 'Got it!' : 'Next',
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }
}

class _LearnMoreStep extends StatelessWidget {
  const _LearnMoreStep({
    required this.iconAsset,
    required this.title,
    required this.body,
  });

  final String iconAsset;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF0F5FF),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: SvgPicture.asset(iconAsset),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF0F5FF),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SvgPicture.asset('assets/vivy_assets/help.svg'),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Help Desks & Contacts',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ContactCard(
            dotColor: const Color(0xFF2563EB),
            title: 'GCash Support',
            lines: const ['help.gcash.com', 'In-app Help Center'],
            onTapLine: (line) async {
              if (line == 'help.gcash.com') {
                await onLaunchUri('https://help.gcash.com');
              }
            },
          ),
          const SizedBox(height: 10),
          _ContactCard(
            dotColor: const Color(0xFF06B6D4),
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
          const SizedBox(height: 10),
          _ContactCard(
            dotColor: const Color(0xFFF97316),
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
          const SizedBox(height: 10),
          _ContactCard(
            dotColor: const Color(0xFF8B5CF6),
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Text(
              'Keep records of the fraudulent receipt and reference number before reporting.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
                height: 1.4,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTapLine(line),
                      child: Text(
                        line,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF93C5FD),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
