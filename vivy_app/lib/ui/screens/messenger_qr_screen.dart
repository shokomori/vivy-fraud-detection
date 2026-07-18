import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label coming soon.')));
  }

  void _openFullScreen() {
    final file = _qrFile;
    if (file == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _MessengerQrFullScreen(
          qrFile: file,
          onDownloadTap: () => _showComingSoon('Download'),
          onShareTap: () => _showComingSoon('Share'),
        ),
      ),
    );
  }

  void _showHelpModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E8F0),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF0F5FF),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.asset('assets/vivy_assets/question.svg'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'How This QR Works',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'This QR is stored only on this device. Upload your own Facebook Messenger receipt QR code so customers can quickly send payment receipts for verification.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF174AA5),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Got it!'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECF4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: SvgPicture.asset('assets/vivy_assets/back.svg', width: 18),
        ),
        title: const Text(
          'Facebook QR',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showHelpModal,
            icon: SvgPicture.asset('assets/vivy_assets/help.svg', width: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF174AA5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: SvgPicture.asset('assets/vivy_assets/facebook.svg'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Manage your Messenger receipt QR locally on this device.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_qrFile == null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEAF1FF),
                                border: Border.all(color: const Color(0xFFC4D5F7)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: SvgPicture.asset('assets/vivy_assets/upload_qr.svg'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No Messenger QR configured yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Upload your own QR image to display it full-screen for customers.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _uploadQr,
                                icon: SvgPicture.asset(
                                  'assets/vivy_assets/upload.svg',
                                  width: 16,
                                  height: 16,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF174AA5),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                label: const Text('Upload Messenger QR'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Messenger QR',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(_qrFile!, fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _openFullScreen,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFCAD5E5)),
                                      minimumSize: const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('View Full Screen'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _uploadQr,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF174AA5),
                                      minimumSize: const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Replace QR'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _VisualActionButton(
                                label: 'Download',
                                icon: SvgPicture.asset(
                                  'assets/vivy_assets/download.svg',
                                  width: 16,
                                  height: 16,
                                ),
                                onTap: () => _showComingSoon('Download'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _VisualActionButton(
                                label: 'Share',
                                icon: SvgPicture.asset(
                                  'assets/vivy_assets/facebook.svg',
                                  width: 16,
                                  height: 16,
                                ),
                                onTap: () => _showComingSoon('Share'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _MessengerQrFullScreen extends StatelessWidget {
  const _MessengerQrFullScreen({
    required this.qrFile,
    required this.onDownloadTap,
    required this.onShareTap,
  });

  final File qrFile;
  final VoidCallback onDownloadTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: SvgPicture.asset(
                      'assets/vivy_assets/back.svg',
                      width: 18,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDownloadTap,
                    icon: SvgPicture.asset(
                      'assets/vivy_assets/download.svg',
                      width: 18,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onShareTap,
                    icon: SvgPicture.asset(
                      'assets/vivy_assets/facebook.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(qrFile, fit: BoxFit.contain),
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

class _VisualActionButton extends StatelessWidget {
  const _VisualActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F5FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
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
