import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpDesksContactsScreen extends StatelessWidget {
  const HelpDesksContactsScreen({
    super.key,
    this.onBack,
    this.onGotIt,
  });

  final VoidCallback? onBack;
  final VoidCallback? onGotIt;

  Future<void> _launchUri(String uri) async {
    final parsed = Uri.parse(uri);
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECF4),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack ?? () => Navigator.of(context).pop(),
                    icon: SvgPicture.asset('assets/vivy_assets/back.svg', width: 18),
                  ),
                  const Spacer(),
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
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  children: [
                    _ContactCard(
                      dotColor: const Color(0xFF2563EB),
                      title: 'GCash Support',
                      lines: const ['help.gcash.com', 'In-app Help Center'],
                      onTapLine: (line) async {
                        if (line == 'help.gcash.com') {
                          await _launchUri('https://help.gcash.com');
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _ContactCard(
                      dotColor: const Color(0xFF06B6D4),
                      title: 'BSP Consumer Assistance',
                      lines: const [
                        '(02) 5306-2584',
                        'consumeraffairs@bsp.gov.ph',
                      ],
                      onTapLine: (line) async {
                        if (line == '(02) 5306-2584') {
                          await _launchUri('tel:(02)5306-2584');
                        } else if (line == 'consumeraffairs@bsp.gov.ph') {
                          await _launchUri('mailto:consumeraffairs@bsp.gov.ph');
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
                          await _launchUri('tel:+630287230401');
                        } else if (line == 'cpiu.acg@pnp.gov.ph') {
                          await _launchUri('mailto:cpiu.acg@pnp.gov.ph');
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
                          await _launchUri('tel:1384');
                        } else if (line == 'ftesb@dti.gov.ph') {
                          await _launchUri('mailto:ftesb@dti.gov.ph');
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBack ?? () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFB9C6DB)),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onGotIt ?? () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF174AA5),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Got it!',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
