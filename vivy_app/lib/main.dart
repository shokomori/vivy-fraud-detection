import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'domain/analysis_models.dart';
import 'ui/screens/analyze_screen.dart';
import 'ui/screens/guidelines_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/vivy_colors.dart';

const double kFraudThreshold = 0.16;
const double kUnclearBand = 0.05;
const double kMinAreaRatio = 0.12;
const double kMinAspectRatio = 0.25;
const double kMaxAspectRatio = 3.5;
const int kInputSize = 224;

void main() {
  runApp(const VivyApp());
}

class VivyApp extends StatelessWidget {
  const VivyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vivy Receipt Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: VivyColors.appBackground,
        colorScheme: ColorScheme.fromSeed(seedColor: VivyColors.primaryBlue),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: VivyColors.textPrimary,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const AppLaunchFlow(),
    );
  }
}

enum _LaunchStage { splash, guidelines, home }

class AppLaunchFlow extends StatefulWidget {
  const AppLaunchFlow({super.key});

  @override
  State<AppLaunchFlow> createState() => _AppLaunchFlowState();
}

class _AppLaunchFlowState extends State<AppLaunchFlow> {
  static const String _onboardingCompleteKey = 'onboarding_complete_v1';
  _LaunchStage _stage = _LaunchStage.splash;

  @override
  void initState() {
    super.initState();
    _resolveLaunchStage();
  }

  Future<void> _resolveLaunchStage() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_onboardingCompleteKey) ?? false;

    await Future<void>.delayed(const Duration(milliseconds: 2800));
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = done ? _LaunchStage.home : _LaunchStage.guidelines;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    if (!mounted) {
      return;
    }
    setState(() {
      _stage = _LaunchStage.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _LaunchStage.splash => const SplashScreen(),
      _LaunchStage.guidelines => GuidelinesScreen(
        onComplete: _completeOnboarding,
      ),
      _LaunchStage.home => const ReceiptCheckPage(),
    };
  }
}

class ReceiptCheckPage extends StatefulWidget {
  const ReceiptCheckPage({super.key});

  @override
  State<ReceiptCheckPage> createState() => _ReceiptCheckPageState();
}

class _ReceiptCheckPageState extends State<ReceiptCheckPage> {
  static const String _historyStorageKey = 'analysis_history_v1';

  final ImagePicker _picker = ImagePicker();

  Interpreter? _interpreter;
  XFile? _selectedFile;
  AnalysisResult? _result;
  List<HistoryEntry> _historyEntries = const [];
  bool _isBusy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadHistory();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      final interpreter = await Interpreter.fromAsset(
        'assets/models/mobilenetv2_fraud_detector_float16.tflite',
      );
      setState(() {
        _interpreter = interpreter;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load model: $e';
      });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }
    setState(() {
      _selectedFile = file;
      _result = null;
    });
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyStorageKey) ?? <String>[];
      final parsed = raw
          .map((row) {
            try {
              return HistoryEntry.fromStorageString(row);
            } catch (_) {
              return null;
            }
          })
          .whereType<HistoryEntry>()
          .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _historyEntries = parsed;
      });
    } catch (_) {
      // Keep app usable even if local history cannot be loaded.
    }
  }

  Future<void> _recordHistory(AnalysisResult result) async {
    final entry = HistoryEntry(
      label: result.type.displayLabel,
      confidence: result.confidence,
      timestamp: DateTime.now(),
    );

    final updated = <HistoryEntry>[entry, ..._historyEntries];
    if (mounted) {
      setState(() {
        _historyEntries = updated;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = updated
          .map((item) => item.toStorageString())
          .toList(growable: false);
      await prefs.setStringList(_historyStorageKey, encoded);
    } catch (_) {
      // Ignore persistence failures to avoid blocking inference flow.
    }
  }

  Future<void> _analyzePhoto() async {
    if (_selectedFile == null || _interpreter == null) {
      return;
    }

    setState(() {
      _isBusy = true;
      _result = null;
    });

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Could not decode image.');
      }

      final roiResult = _extractReceiptRoi(decoded);
      if (!roiResult.geometryPass) {
        final result = AnalysisResult.notReceipt(
          message: 'This does not look like a GCash receipt.',
          areaRatio: roiResult.areaRatio,
          aspectRatio: roiResult.aspectRatio,
        );
        setState(() {
          _result = result;
        });
        await _recordHistory(result);
        return;
      }

      final normalized = _preprocessForModel(roiResult.roi!);
      final score = _runModel(normalized);

      if ((score - kFraudThreshold).abs() < kUnclearBand) {
        final result = AnalysisResult.unclear(
          score: score,
          message: 'Result unclear - try a clearer or better-lit photo.',
        );
        setState(() {
          _result = result;
        });
        await _recordHistory(result);
        return;
      }

      final isFraudulent = score >= kFraudThreshold;
      final confidence = isFraudulent ? score : (1.0 - score);
      final result = AnalysisResult.classified(
        score: score,
        confidence: confidence,
        isFraudulent: isFraudulent,
      );
      setState(() {
        _result = result;
      });
      await _recordHistory(result);
    } catch (e) {
      final result = AnalysisResult.error('Analysis failed: $e');
      setState(() {
        _result = result;
      });
      await _recordHistory(result);
    } finally {
      setState(() {
        _isBusy = false;
      });
    }
  }

  Future<void> _simulateClassifiedResult({required bool isFraudulent}) async {
    final score = isFraudulent ? 0.9992 : 0.0092;
    final confidence = isFraudulent ? score : (1.0 - score);
    final result = AnalysisResult.classified(
      isFraudulent: isFraudulent,
      score: score,
      confidence: confidence,
    );
    setState(() {
      _result = result;
    });
    await _recordHistory(result);
  }

  double _runModel(Float32List inputBuffer) {
    final input = List.generate(
      1,
      (_) => List.generate(
        kInputSize,
        (y) => List.generate(kInputSize, (x) {
          final base = (y * kInputSize + x) * 3;
          return <double>[
            inputBuffer[base],
            inputBuffer[base + 1],
            inputBuffer[base + 2],
          ];
        }),
      ),
    );

    final output = List.generate(1, (_) => List.filled(1, 0.0));
    _interpreter!.run(input, output);
    return (output[0][0] as num).toDouble();
  }

  Float32List _preprocessForModel(img.Image roi) {
    final resized = img.copyResize(
      roi,
      width: kInputSize,
      height: kInputSize,
      interpolation: img.Interpolation.average,
    );

    final buffer = Float32List(kInputSize * kInputSize * 3);
    var i = 0;
    for (var y = 0; y < kInputSize; y++) {
      for (var x = 0; x < kInputSize; x++) {
        final pixel = resized.getPixel(x, y);
        // RGB order normalized to 0..1.
        buffer[i++] = pixel.r / 255.0;
        buffer[i++] = pixel.g / 255.0;
        buffer[i++] = pixel.b / 255.0;
      }
    }
    return buffer;
  }

  RoiExtractionResult _extractReceiptRoi(img.Image source) {
    final width = source.width;
    final height = source.height;

    final gray = img.grayscale(source);
    final blurred = img.gaussianBlur(gray, radius: 2);

    final threshold = _otsuThreshold(blurred);
    var mask = _binaryMask(blurred, threshold);

    // Morphological close with 5x5 kernel, 2 iterations to mimic training preprocessing.
    for (var i = 0; i < 2; i++) {
      mask = _dilate(mask, width, height, kernelSize: 5);
    }
    for (var i = 0; i < 2; i++) {
      mask = _erode(mask, width, height, kernelSize: 5);
    }

    final component = _largestValidComponent(mask, width, height);
    if (component == null) {
      return const RoiExtractionResult(
        roi: null,
        geometryPass: false,
        areaRatio: 0,
        aspectRatio: 0,
      );
    }

    final areaRatio = component.area / (width * height);
    final aspectRatio = component.w / component.h;

    final pass =
        areaRatio >= kMinAreaRatio &&
        aspectRatio >= kMinAspectRatio &&
        aspectRatio <= kMaxAspectRatio;
    if (!pass) {
      return RoiExtractionResult(
        roi: null,
        geometryPass: false,
        areaRatio: areaRatio,
        aspectRatio: aspectRatio,
      );
    }

    final padX = (component.w * 0.03).round();
    final padY = (component.h * 0.03).round();
    final x0 = math.max(0, component.x - padX);
    final y0 = math.max(0, component.y - padY);
    final x1 = math.min(width - 1, component.x + component.w - 1 + padX);
    final y1 = math.min(height - 1, component.y + component.h - 1 + padY);

    final roi = img.copyCrop(
      source,
      x: x0,
      y: y0,
      width: (x1 - x0 + 1),
      height: (y1 - y0 + 1),
    );

    return RoiExtractionResult(
      roi: roi,
      geometryPass: true,
      areaRatio: areaRatio,
      aspectRatio: aspectRatio,
    );
  }

  int _otsuThreshold(img.Image image) {
    final hist = List<int>.filled(256, 0);
    final total = image.width * image.height;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final v = image.getPixel(x, y).r.toInt();
        hist[v]++;
      }
    }

    var sum = 0.0;
    for (var i = 0; i < 256; i++) {
      sum += i * hist[i];
    }

    var sumB = 0.0;
    var wB = 0;
    var maxVariance = -1.0;
    var threshold = 0;

    for (var t = 0; t < 256; t++) {
      wB += hist[t];
      if (wB == 0) {
        continue;
      }

      final wF = total - wB;
      if (wF == 0) {
        break;
      }

      sumB += t * hist[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final between = wB * wF * (mB - mF) * (mB - mF);

      if (between > maxVariance) {
        maxVariance = between;
        threshold = t;
      }
    }

    return threshold;
  }

  List<bool> _binaryMask(img.Image image, int threshold) {
    final mask = List<bool>.filled(image.width * image.height, false);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final idx = y * image.width + x;
        mask[idx] = image.getPixel(x, y).r.toInt() > threshold;
      }
    }
    return mask;
  }

  List<bool> _dilate(
    List<bool> mask,
    int width,
    int height, {
    required int kernelSize,
  }) {
    final out = List<bool>.filled(mask.length, false);
    final r = kernelSize ~/ 2;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var any = false;
        for (var ky = -r; ky <= r && !any; ky++) {
          final ny = y + ky;
          if (ny < 0 || ny >= height) {
            continue;
          }
          for (var kx = -r; kx <= r; kx++) {
            final nx = x + kx;
            if (nx < 0 || nx >= width) {
              continue;
            }
            if (mask[ny * width + nx]) {
              any = true;
              break;
            }
          }
        }
        out[y * width + x] = any;
      }
    }
    return out;
  }

  List<bool> _erode(
    List<bool> mask,
    int width,
    int height, {
    required int kernelSize,
  }) {
    final out = List<bool>.filled(mask.length, false);
    final r = kernelSize ~/ 2;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var all = true;
        for (var ky = -r; ky <= r && all; ky++) {
          final ny = y + ky;
          if (ny < 0 || ny >= height) {
            all = false;
            break;
          }
          for (var kx = -r; kx <= r; kx++) {
            final nx = x + kx;
            if (nx < 0 || nx >= width || !mask[ny * width + nx]) {
              all = false;
              break;
            }
          }
        }
        out[y * width + x] = all;
      }
    }
    return out;
  }

  _ComponentBox? _largestValidComponent(
    List<bool> mask,
    int width,
    int height,
  ) {
    final visited = List<bool>.filled(mask.length, false);
    _ComponentBox? best;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final startIdx = y * width + x;
        if (visited[startIdx] || !mask[startIdx]) {
          continue;
        }

        var minX = x;
        var maxX = x;
        var minY = y;
        var maxY = y;
        var area = 0;

        final queue = <int>[startIdx];
        visited[startIdx] = true;
        var qHead = 0;

        while (qHead < queue.length) {
          final idx = queue[qHead++];
          final cx = idx % width;
          final cy = idx ~/ width;
          area++;

          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;

          for (var ny = cy - 1; ny <= cy + 1; ny++) {
            if (ny < 0 || ny >= height) continue;
            for (var nx = cx - 1; nx <= cx + 1; nx++) {
              if (nx < 0 || nx >= width) continue;
              final nIdx = ny * width + nx;
              if (!visited[nIdx] && mask[nIdx]) {
                visited[nIdx] = true;
                queue.add(nIdx);
              }
            }
          }
        }

        final w = maxX - minX + 1;
        final h = maxY - minY + 1;
        if (h <= 0) {
          continue;
        }

        final aspect = w / h;
        final areaRatio = area / (width * height);
        if (areaRatio < kMinAreaRatio ||
            aspect < kMinAspectRatio ||
            aspect > kMaxAspectRatio) {
          continue;
        }

        if (best == null || area > best.area) {
          best = _ComponentBox(x: minX, y: minY, w: w, h: h, area: area);
        }
      }
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      entries: _historyEntries,
      onUploadVerify: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AnalyzeScreen(
              selectedFile: _selectedFile,
              result: _result,
              isBusy: _isBusy,
              loadError: _loadError,
              modelReady: _interpreter != null,
              threshold: kFraudThreshold,
              onPickPhoto: _pickPhoto,
              onRunOfflineCheck: _analyzePhoto,
              onOpenHistory: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HistoryScreen(entries: _historyEntries),
                  ),
                );
              },
              onDebugGenuine: kReleaseMode
                  ? null
                  : () => _simulateClassifiedResult(isFraudulent: false),
              onDebugFraudulent: kReleaseMode
                  ? null
                  : () => _simulateClassifiedResult(isFraudulent: true),
            ),
          ),
        );
      },
      onOpenHistory: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HistoryScreen(entries: _historyEntries),
          ),
        );
      },
    );
  }
}

class _ComponentBox {
  const _ComponentBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.area,
  });

  final int x;
  final int y;
  final int w;
  final int h;
  final int area;
}
