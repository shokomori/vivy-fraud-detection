import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/analysis_models.dart';
import '../theme/vivy_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.entries,
    required this.onUploadVerify,
    required this.onOpenHistory,
  });

  final List<HistoryEntry> entries;
  final VoidCallback onUploadVerify;
  final VoidCallback onOpenHistory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _tipsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final stats = _SummaryStats.fromEntries(widget.entries);

    return Scaffold(
      backgroundColor: const Color(0xFF0A3D8F),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withAlpha(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SvgPicture.asset(
                      'assets/vivy_assets/ViVy.svg',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ViVy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(28),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: SvgPicture.asset(
                        'assets/vivy_assets/help.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Color(0xFF9FC0EE),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Stay Protected.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8ECF4),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
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
                              iconBackground: const Color(0xFFD1FAF5),
                              onTap: widget.onOpenHistory,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: _MiniActionCard(
                              title: 'Learn More',
                              subtitle: 'About fraud',
                              iconAsset: 'assets/vivy_assets/learn.svg',
                              iconBackground: Color(0xFFFFEDD5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _QrCard(),
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
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF174AA5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.asset('assets/vivy_assets/upload.svg'),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload & Verify\nReceipt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to check any GCash receipt now',
                    style: TextStyle(
                      color: Color(0xFFBFD3F7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4F7FCA),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: SvgPicture.asset('assets/vivy_assets/blue_back.svg'),
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
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF189B8F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Text(
              'YOUR SCAN SUMMARY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryPill(
                    value: '${stats.total}',
                    label: 'Scans',
                    valueColor: const Color(0xFF174AA5),
                    background: const Color(0xFFDDE4F2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryPill(
                    value: '${stats.genuine}',
                    label: 'Genuine',
                    valueColor: const Color(0xFF059669),
                    background: const Color(0xFFDDF3EA),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryPill(
                    value: '${stats.flagged}',
                    label: 'Flagged',
                    valueColor: const Color(0xFFDC2626),
                    background: const Color(0xFFFBE4E4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Safe rate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B6D8D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${stats.safeRate.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF174AA5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: (stats.safeRate / 100).clamp(0, 1),
                minHeight: 5,
                backgroundColor: const Color(0xFFEFD4D8),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF189B8F)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEDEFF3),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Text(
              stats.lastScanText,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5A6B89),
                fontWeight: FontWeight.w600,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(label,
            style: TextStyle(
              color: Color(0xFF5D6C86),
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBackground,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: SvgPicture.asset(iconAsset),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
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

class _QrCard extends StatelessWidget {
  const _QrCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE3EDFF),
              border: Border.all(color: const Color(0xFF2E6BD2), width: 1.3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset('assets/vivy_assets/qr.svg'),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Facebook Receipt QR',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Let customers send you receipts to scan',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE4EAF4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset('assets/vivy_assets/view.svg'),
            ),
          ),
        ],
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
        color: const Color(0xFFF5ECB8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4D888)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: SvgPicture.asset('assets/vivy_assets/warning.svg'),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tips for Staying Safe',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A5603),
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded,
                    color: const Color(0xFFA16A04),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE4D888))),
              ),
              child: const Text(
                'Always verify a GCash receipt before releasing goods or services. Fraudulent receipts often look identical to real ones. When in doubt, confirm payment inside the GCash app directly.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF875705),
                  height: 1.35,
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
  });

  final int total;
  final int genuine;
  final int flagged;
  final double safeRate;
  final String lastScanText;

  static _SummaryStats fromEntries(List<HistoryEntry> entries) {
    var total = 0;
    var genuine = 0;
    var flagged = 0;

    for (final entry in entries) {
      final label = entry.label.toLowerCase();
      if (label == 'genuine') {
        genuine++;
        total++;
      } else if (label == 'fraudulent') {
        flagged++;
        total++;
      }
    }

    final safeRate = total == 0 ? 0.0 : (genuine / total) * 100;

    final last = entries.isEmpty
      ? 'Last scan: No scans yet'
        : _formatLastScan(entries.first);

    return _SummaryStats(
      total: total,
      genuine: genuine,
      flagged: flagged,
      safeRate: safeRate,
      lastScanText: last,
    );
  }

  static String _formatLastScan(HistoryEntry entry) {
    final confidenceText = entry.confidence == null
        ? ''
        : ' - ${(entry.confidence! * 100).toStringAsFixed(1)}%';
    return 'Last scan: ${entry.label}$confidenceText';
  }
}
