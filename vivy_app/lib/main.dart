import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6D6A)),
        useMaterial3: true,
      ),
      home: const ReceiptCheckPage(),
    );
  }
}

class ReceiptCheckPage extends StatefulWidget {
  const ReceiptCheckPage({super.key});

  @override
  State<ReceiptCheckPage> createState() => _ReceiptCheckPageState();
}

class _ReceiptCheckPageState extends State<ReceiptCheckPage> {
  final ImagePicker _picker = ImagePicker();

  Interpreter? _interpreter;
  XFile? _selectedFile;
  AnalysisResult? _result;
  bool _isBusy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadModel();
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
        setState(() {
          _result = AnalysisResult.notReceipt(
            message: 'This does not look like a GCash receipt.',
            areaRatio: roiResult.areaRatio,
            aspectRatio: roiResult.aspectRatio,
          );
        });
        return;
      }

      final normalized = _preprocessForModel(roiResult.roi!);
      final score = _runModel(normalized);

      if ((score - kFraudThreshold).abs() < kUnclearBand) {
        setState(() {
          _result = AnalysisResult.unclear(
            score: score,
            message: 'Result unclear - try a clearer or better-lit photo.',
          );
        });
        return;
      }

      final isFraudulent = score >= kFraudThreshold;
      final confidence = isFraudulent ? score : (1.0 - score);
      setState(() {
        _result = AnalysisResult.classified(
          score: score,
          confidence: confidence,
          isFraudulent: isFraudulent,
        );
      });
    } catch (e) {
      setState(() {
        _result = AnalysisResult.error('Analysis failed: $e');
      });
    } finally {
      setState(() {
        _isBusy = false;
      });
    }
  }

  double _runModel(Float32List inputBuffer) {
    final input = List.generate(
      1,
      (_) => List.generate(
        kInputSize,
        (y) => List.generate(
          kInputSize,
          (x) {
            final base = (y * kInputSize + x) * 3;
            return <double>[
              inputBuffer[base],
              inputBuffer[base + 1],
              inputBuffer[base + 2],
            ];
          },
        ),
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

    final pass = areaRatio >= kMinAreaRatio && aspectRatio >= kMinAspectRatio && aspectRatio <= kMaxAspectRatio;
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

  List<bool> _dilate(List<bool> mask, int width, int height, {required int kernelSize}) {
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

  List<bool> _erode(List<bool> mask, int width, int height, {required int kernelSize}) {
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

  _ComponentBox? _largestValidComponent(List<bool> mask, int width, int height) {
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
        if (areaRatio < kMinAreaRatio || aspect < kMinAspectRatio || aspect > kMaxAspectRatio) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('GCash Receipt Checker'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Offline fraud check using on-device TFLite model',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedFile == null
                      ? const Center(child: Text('No image selected'))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_selectedFile!.path),
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loadError != null)
                Text(
                  _loadError!,
                  style: const TextStyle(color: Colors.red),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBusy ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Pick Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isBusy || _selectedFile == null || _interpreter == null ? null : _analyzePhoto,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Run Offline Check'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isBusy)
                const Row(
                  children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    SizedBox(width: 10),
                    Text('Running on-device analysis...'),
                  ],
                ),
              const SizedBox(height: 8),
              if (_result != null) _ResultCard(result: _result!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final color = switch (result.type) {
      ResultType.fraudulent => Colors.red.shade700,
      ResultType.genuine => Colors.green.shade700,
      ResultType.notReceipt => Colors.orange.shade800,
      ResultType.unclear => Colors.deepOrange.shade700,
      ResultType.error => Colors.red.shade900,
    };

    final title = switch (result.type) {
      ResultType.fraudulent => 'Fraudulent',
      ResultType.genuine => 'Genuine',
      ResultType.notReceipt => 'Not a GCash Receipt',
      ResultType.unclear => 'Unclear Result',
      ResultType.error => 'Error',
    };

    return Card(
      color: color.withAlpha(28),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.message),
            if (result.confidence != null) ...[
              const SizedBox(height: 8),
              Text('Confidence: ${(result.confidence! * 100).toStringAsFixed(1)}%'),
            ],
            if (result.score != null) ...[
              const SizedBox(height: 4),
              Text(
                'Raw fraud score: ${result.score!.toStringAsFixed(4)} (threshold ${kFraudThreshold.toStringAsFixed(2)})',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ],
            if (result.areaRatio != null && result.aspectRatio != null) ...[
              const SizedBox(height: 4),
              Text(
                'Geometry: area ratio ${result.areaRatio!.toStringAsFixed(3)}, aspect ratio ${result.aspectRatio!.toStringAsFixed(3)}',
                style: TextStyle(color: Colors.grey.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum ResultType { genuine, fraudulent, notReceipt, unclear, error }

class AnalysisResult {
  const AnalysisResult({
    required this.type,
    required this.message,
    this.score,
    this.confidence,
    this.areaRatio,
    this.aspectRatio,
  });

  final ResultType type;
  final String message;
  final double? score;
  final double? confidence;
  final double? areaRatio;
  final double? aspectRatio;

  factory AnalysisResult.classified({
    required bool isFraudulent,
    required double score,
    required double confidence,
  }) {
    return AnalysisResult(
      type: isFraudulent ? ResultType.fraudulent : ResultType.genuine,
      message: isFraudulent ? 'Receipt appears fraudulent.' : 'Receipt appears genuine.',
      score: score,
      confidence: confidence,
    );
  }

  factory AnalysisResult.notReceipt({
    required String message,
    required double areaRatio,
    required double aspectRatio,
  }) {
    return AnalysisResult(
      type: ResultType.notReceipt,
      message: message,
      areaRatio: areaRatio,
      aspectRatio: aspectRatio,
    );
  }

  factory AnalysisResult.unclear({required String message, required double score}) {
    return AnalysisResult(
      type: ResultType.unclear,
      message: message,
      score: score,
    );
  }

  factory AnalysisResult.error(String message) {
    return AnalysisResult(type: ResultType.error, message: message);
  }
}

class RoiExtractionResult {
  const RoiExtractionResult({
    required this.roi,
    required this.geometryPass,
    required this.areaRatio,
    required this.aspectRatio,
  });

  final img.Image? roi;
  final bool geometryPass;
  final double areaRatio;
  final double aspectRatio;
}

class _ComponentBox {
  const _ComponentBox({required this.x, required this.y, required this.w, required this.h, required this.area});

  final int x;
  final int y;
  final int w;
  final int h;
  final int area;
}
