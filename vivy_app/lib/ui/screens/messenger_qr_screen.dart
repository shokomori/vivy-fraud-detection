import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Color tokens (per spec)
// ---------------------------------------------------------------------------
const _kBrowseGalleryBlue = const Color(0xFF1877F2); // Browse Gallery button + Watch Video pill + headings
const _kDisplayQrBlue = Color(0xFF0A3D8F); // Display QR to Customer button
const _kProTipBlue = Color(0xFF0369A1); // Pro tip text + icon
const _kTextDark = Color(0xFF1B2434);
const _kTextMuted = Color(0xFF6A7A96);
const _kBorder = Color(0xFFE8ECF4);
const _kBackgroundLight = Color(0xFFE8EFFC); // Light background
const _kContainerWhite = Color(0xFFFFFFFF); // White containers

// ---------------------------------------------------------------------------
// Reusable "quick tap" animation wrapper — used on every tappable surface
// ---------------------------------------------------------------------------
class _AnimatedTapScale extends StatefulWidget {
  const _AnimatedTapScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_AnimatedTapScale> createState() => _AnimatedTapScaleState();
}

class _AnimatedTapScaleState extends State<_AnimatedTapScale> {
  double _scale = 1;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setScale(0.96),
      onTapUp: (_) => _setScale(1),
      onTapCancel: () => _setScale(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashed border painter for upload box
// ---------------------------------------------------------------------------
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

    final radius = 14.0;
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

class MessengerQrScreen extends StatefulWidget {
  const MessengerQrScreen({super.key});

  @override
  State<MessengerQrScreen> createState() => _MessengerQrScreenState();
}

class _MessengerQrScreenState extends State<MessengerQrScreen> {
  final _picker = ImagePicker();
  final _store = const _LocalMessengerQrStore();

  File? _qrFile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  Future<void> _loadQr() async {
    final file = await _store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _qrFile = file;
      _loading = false;
    });
  }

  Future<void> _uploadQr() async {
    final selected = await _picker.pickImage(source: ImageSource.gallery);
    if (selected == null) {
      return;
    }

    setState(() {
      _loading = true;
    });
    final saved = await _store.saveFromPicker(selected.path);
    if (!mounted) {
      return;
    }

    setState(() {
      _qrFile = saved;
      _loading = false;
    });
  }

  void _openFullScreen() {
    final file = _qrFile;
    if (file == null) {
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _MessengerQrFullScreen(qrFile: file),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _showWatchVideoDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.54,
          minChildSize: 0.35,
          maxChildSize: 0.75,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: _kContainerWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'How to Set Up Your QR',
                                  style: TextStyle(
                                    color: _kTextDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Step-by-step instructions · 1:42',
                                  style: TextStyle(
                                    color: _kTextMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _AnimatedTapScale(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F5FB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 20, color: _kTextDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildVideoCard(),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: Column(
                        children: [
                          _buildVideoStep('Open Facebook Messenger and go to Settings', 1),
                          const SizedBox(height: 12),
                          _buildVideoStep('Tap on your QR Code and save it to your gallery', 2),
                          const SizedBox(height: 12),
                          _buildVideoStep('Come back to ViVy and upload it here', 3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoCard() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video player placeholder — your video will appear here.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF0F3FE6).withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCE3F0)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: const Color(0xFFF7F9FE),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _kBrowseGalleryBlue,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _kBrowseGalleryBlue.withOpacity(0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 38),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kBrowseGalleryBlue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '1:42',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoStep(String text, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: index < 3 ? const Color(0xFFDCEAFB) : const Color(0xFFD1FAE5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              index.toString(),
              style: TextStyle(
                color: index < 3 ? _kBrowseGalleryBlue : const Color(0xFF0F9D74),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _kTextDark,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundLight,
      appBar: AppBar(
        backgroundColor: _kBackgroundLight,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kContainerWhite,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDCE3F0)),
            ),
            alignment: Alignment.center,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, size: 19, color: _kTextDark),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Facebook Receipt QR',
              style: TextStyle(
                color: _kTextDark,
                fontWeight: FontWeight.w800, // ExtraBold
                fontSize: 20,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            Text(
              'Let customers send you receipts',
              style: TextStyle(
                color: _kTextMuted,
                fontWeight: FontWeight.w600, // SemiBold
                fontSize: 14,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ],
        ),
        centerTitle: false,
        titleSpacing: 12,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HOW IT WORKS section — wrapped in white container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kContainerWhite,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'HOW IT WORKS',
                                style: TextStyle(
                                  color: const Color(0xFF1877F2),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  fontFamily: 'Plus Jakarta Sans',
                                  letterSpacing: 0.5,
                                ),
                              ),
                              _AnimatedTapScale(
                                onTap: _showWatchVideoDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _kBrowseGalleryBlue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Watch Video',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          fontFamily: 'Plus Jakarta Sans',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Steps — 1 & 2 use the blue badge, 3 uses the mint/teal badge
                          _buildStep(
                            number: '1',
                            title: 'Download your QR from Facebook Messenger settings',
                            badgeColor: const Color(0xFFDCEAFB),
                            numberColor: _kBrowseGalleryBlue,
                          ),
                          _buildStep(
                            number: '2',
                            title: 'Upload it here so ViVy can display it',
                            badgeColor: const Color(0xFFDCEAFB),
                            numberColor: _kBrowseGalleryBlue,
                          ),
                          _buildStep(
                            number: '3',
                            title: 'Show it to customers — they scan & send you the receipt',
                            badgeColor: const Color(0xFFD1FAE5),
                            numberColor: const Color(0xFF0F9D74),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(sizeFactor: animation, child: child),
                      ),
                      child: _qrFile == null
                          ? _buildUploadState(key: const ValueKey('empty'))
                          : _buildActiveState(key: const ValueKey('active')),
                    ),
                    const SizedBox(height: 16),
                    // Pro tip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kProTipBlue.withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kProTipBlue.withAlpha(60)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.storefront_rounded, color: _kProTipBlue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600, // SemiBold
                                  color: _kProTipBlue,
                                  height: 1.4,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Pro tip: ',
                                    style: TextStyle(fontWeight: FontWeight.w800), // ExtraBold
                                  ),
                                  TextSpan(
                                    text:
                                        'Post your QR at your cashier or storefront so customers can scan and send you their receipt screenshot via Messenger.',
                                  ),
                                ],
                              ),
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

  // Container-20: no QR uploaded yet
  Widget _buildUploadState({Key? key}) {
    return CustomPaint(
      key: key,
      painter: _DashedBorderPainter(
        color: const Color.fromARGB(255, 244, 244, 245),
        width: 2,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _kContainerWhite,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Just the raw icon asset — no wrapping circular/rounded background container.
            SvgPicture.asset('assets/vivy_assets/upload_qr.svg', width: 56, height: 56),
            const SizedBox(height: 16),
            const Text(
              'Upload Your QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800, // ExtraBold
                color: _kTextDark,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find it in Facebook Messenger → Settings → QR Code. Save it to your gallery, then upload here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600, // SemiBold
                color: _kTextMuted,
                height: 1.4,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
            const SizedBox(height: 16),
            _AnimatedTapScale(
              onTap: _uploadQr,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kBrowseGalleryBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Browse Gallery',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Container-21: user's own uploaded QR is displayed
  Widget _buildActiveState({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _kContainerWhite,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Blue line header
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(60),
                    topRight: Radius.circular(60),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(19),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset('assets/vivy_assets/facebook.svg', width: 20, height: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Facebook Messenger QR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1877F2),
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // This is the user's own uploaded QR image (their receipt QR).
                    Hero(
                      tag: 'messenger_qr_hero',
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_qrFile!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Tap below to display full-screen for your customer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: _kTextMuted,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AnimatedTapScale(
                      onTap: _openFullScreen,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _kDisplayQrBlue,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Display QR to Customer',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AnimatedTapScale(
                      onTap: _uploadQr,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: _kBorder),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, color: _kTextDark, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Replace QR Code',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: _kTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required Color badgeColor,
    required Color numberColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: numberColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600, // SemiBold
                  color: _kTextDark,
                  height: 1.4,
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

class _MessengerQrFullScreen extends StatelessWidget {
  const _MessengerQrFullScreen({
    required this.qrFile,
  });

  final File qrFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button and title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _AnimatedTapScale(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A3B52),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: 0.6,
                    child: const Text(
                      'SHOW TO CUSTOMER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Centered content area
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Facebook Messenger branding
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset('assets/vivy_assets/facebook.svg', width: 25, height: 25),
                            const SizedBox(width: 8),
                            Opacity(
                              opacity: 0.8,
                              child: const Text(
                                'Facebook Messenger QR',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Plus Jakarta Sans',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // White rounded container with QR
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Hero(
                            tag: 'messenger_qr_hero',
                            child: SizedBox(
                              width: 262,
                              height: 262,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(qrFile, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Three dots pagination indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1877F2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1877F2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1877F2),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Instruction text
                        Opacity(
                          opacity: 0.6,
                          child: const Text(
                            'Ask your customer to open Facebook Messenger, tap the QR icon, and scan this code to send you their receipt.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFB8C1D1),
                              height: 1.5,
                              fontFamily: 'Plus Jakarta Sans',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Done button at bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: _AnimatedTapScale(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3B52),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
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

class _LocalMessengerQrStore {
  const _LocalMessengerQrStore();

  static const _pathKey = 'messenger_qr_local_path_v1';

  Future<File?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPath = prefs.getString(_pathKey);
    if (storedPath == null || storedPath.isEmpty) {
      return null;
    }

    final file = File(storedPath);
    if (!await file.exists()) {
      await prefs.remove(_pathKey);
      return null;
    }
    return file;
  }

  Future<File> saveFromPicker(String sourcePath) async {
    final prefs = await SharedPreferences.getInstance();
    final existingPath = prefs.getString(_pathKey);

    final docsDir = await getApplicationDocumentsDirectory();
    final qrDir = Directory('${docsDir.path}/messenger_qr');
    if (!await qrDir.exists()) {
      await qrDir.create(recursive: true);
    }

    final extIndex = sourcePath.lastIndexOf('.');
    final ext = extIndex > 0 ? sourcePath.substring(extIndex) : '.png';
    final targetPath = '${qrDir.path}/active_qr$ext';
    final targetFile = await File(sourcePath).copy(targetPath);

    if (existingPath != null && existingPath != targetPath) {
      final oldFile = File(existingPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    await prefs.setString(_pathKey, targetFile.path);
    return targetFile;
  }
}