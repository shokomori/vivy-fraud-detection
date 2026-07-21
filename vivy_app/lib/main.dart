import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'domain/analysis_models.dart';
import 'ui/screens/analyze_screen.dart';
import 'ui/screens/guidelines_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/learn_more_screen.dart';
import 'ui/screens/messenger_qr_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/vivy_colors.dart';

const double kFraudThreshold = 0.16;
const double kUnclearBand = 0.05;
const double kMinAreaRatio = 0.12;
const double kMinAspectRatio = 0.25;
const double kMaxAspectRatio = 3.5;
const int kInputSize = 224;
const String kZoneBaselineAsset = 'assets/config/zone_baselines.json';
const Map<String, Map<String, List<double>>> kZoneLayouts = {
  'android-like': {
    'transaction_amount': [0.52, 0.16, 0.95, 0.32],
    'reference_number': [0.52, 0.34, 0.95, 0.48],
    'timestamp': [0.52, 0.50, 0.95, 0.63],
    'name_block': [0.08, 0.66, 0.95, 0.84],
  },
  'ios-like': {
    'transaction_amount': [0.50, 0.18, 0.94, 0.34],
    'reference_number': [0.50, 0.35, 0.94, 0.50],
    'timestamp': [0.50, 0.52, 0.94, 0.66],
    'name_block': [0.08, 0.67, 0.94, 0.86],
  },
};

const Map<String, String> kZoneDisplayNames = {
  'transaction_amount': 'transaction amount',
  'reference_number': 'reference number',
  'timestamp': 'timestamp',
  'name_block': 'name block',
};

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
        fontFamily: 'Plus Jakarta Sans',
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
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

class _ReceiptCheckPageState extends State<ReceiptCheckPage>
    with WidgetsBindingObserver {
  static const MethodChannel _preprocessChannel = MethodChannel(
    'vivy/preprocess',
  );
  static const String _historyStorageKey = 'analysis_history_v1';
  static const String _rawScoreStorageKey = 'analysis_raw_score_log_v2';
  static const String _debugBatchRootName = 'vivy_debug_batch';
  static const String _debugBatchInboxName = 'batch_inbox';
  static const String _debugBatchExportName = 'batch_exports';
  static const String _debugBatchTriggerName = 'trigger.run';
  static const String _debugBatchStatusName = 'last_batch_status.json';

  final ImagePicker _picker = ImagePicker();
  final ValueNotifier<AnalyzeUiState> _analyzeUiState =
      ValueNotifier(const AnalyzeUiState());

  Interpreter? _interpreter;
  XFile? _selectedFile;
  AnalysisResult? _result;
  List<HistoryEntry> _historyEntries = const [];
  bool _isBusy = false;
  String? _loadError;
  bool _isDebugBatchRunning = false;
  _ZoneBaselineProfile? _zoneBaselineProfile;
  bool _zoneBaselineLoadAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadZoneBaselines();
    _loadModel();
    _loadHistory();
    _maybeRunDebugBatchIngestion(reason: 'startup');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _analyzeUiState.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRunDebugBatchIngestion(reason: 'resume');
    }
  }

  void _syncAnalyzeUiState() {
    _analyzeUiState.value = AnalyzeUiState(
      result: _result,
      isBusy: _isBusy,
      loadError: _loadError,
    );
  }

  Future<void> _loadModel() async {
    try {
      final interpreter = await Interpreter.fromAsset(
        'assets/models/mobilenetv2_fraud_detector_float16.tflite',
      );
      setState(() {
        _interpreter = interpreter;
      });
      _maybeRunDebugBatchIngestion(reason: 'model_ready');
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load model: $e';
      });
      _syncAnalyzeUiState();
    }
  }

  Future<void> _loadZoneBaselines() async {
    if (_zoneBaselineLoadAttempted) {
      return;
    }
    _zoneBaselineLoadAttempted = true;
    try {
      final raw = await rootBundle.loadString(kZoneBaselineAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _zoneBaselineProfile = _ZoneBaselineProfile.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[VIVY][ZONE] Baseline unavailable: $e');
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
    _syncAnalyzeUiState();

    // UI flow: skip manual crop/confirm and go straight to scanning.
    await _analyzePhoto();
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
    _syncAnalyzeUiState();

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final outcome = await _analyzeBytesThroughLivePipeline(
        bytes: bytes,
        sourcePathForNative: _selectedFile!.path,
      );
      final result = outcome.result;

      setState(() {
        _result = result;
      });
      _syncAnalyzeUiState();
      await _recordRawScoreObservation(
        result: result,
        imagePath: _selectedFile!.path,
        fileSha256: outcome.fileSha256,
        fileSizeBytes: outcome.fileSizeBytes,
        decodedWidth: outcome.decodedWidth,
        decodedHeight: outcome.decodedHeight,
        backendUsed: outcome.backendUsed,
        backendNote: outcome.backendNote,
      );
      await _recordHistory(result);
    } catch (e) {
      final result = AnalysisResult.error('Analysis failed: $e');
      setState(() {
        _result = result;
      });
      _syncAnalyzeUiState();
      await _recordRawScoreObservation(
        result: result,
        imagePath: _selectedFile!.path,
        fileSha256: '',
        fileSizeBytes: 0,
        decodedWidth: null,
        decodedHeight: null,
        backendUsed: 'error',
        backendNote: e.toString(),
      );
      await _recordHistory(result);
    } finally {
      setState(() {
        _isBusy = false;
      });
      _syncAnalyzeUiState();
    }
  }

  Future<_PipelineOutcome> _analyzeBytesThroughLivePipeline({
    required Uint8List bytes,
    required String sourcePathForNative,
  }) async {
    final fileSha256 = _sha256Hex(bytes);
    final fileSizeBytes = bytes.length;
    final decodedForMeta = img.decodeImage(bytes);
    final decodedWidth = decodedForMeta?.width;
    final decodedHeight = decodedForMeta?.height;

    try {
      final native = await _preprocessNative(sourcePathForNative);
      if (!native.geometryPass) {
        _reportBackendUsage(
          imagePath: sourcePathForNative,
          backendUsed: 'native-opencv',
          backendNote: native.reason,
        );
        final result = AnalysisResult.notReceipt(
          message: 'This does not look like a GCash receipt.',
          areaRatio: native.areaRatio,
          aspectRatio: native.aspectRatio,
        );
        return _PipelineOutcome(
          result: result,
          fileSha256: fileSha256,
          fileSizeBytes: fileSizeBytes,
          decodedWidth: decodedWidth,
          decodedHeight: decodedHeight,
          backendUsed: 'native-opencv',
          backendNote: native.reason,
        );
      }

      final score = _runModel(native.tensor!);
      _reportBackendUsage(
        imagePath: sourcePathForNative,
        backendUsed: 'native-opencv',
        backendNote: native.reason,
      );

      if ((score - kFraudThreshold).abs() < kUnclearBand) {
        final result = AnalysisResult.unclear(
          score: score,
          message: 'Result unclear - try a clearer or better-lit photo.',
        );
        return _PipelineOutcome(
          result: result,
          fileSha256: fileSha256,
          fileSizeBytes: fileSizeBytes,
          decodedWidth: decodedWidth,
          decodedHeight: decodedHeight,
          backendUsed: 'native-opencv',
          backendNote: native.reason,
        );
      }

      final isFraudulent = score >= kFraudThreshold;
      final confidence = isFraudulent ? score : (1.0 - score);
      final zoneExplanation = _buildZoneExplanation(
        isFraudulent: isFraudulent,
        confidence: confidence,
        family: native.templateFamily,
        templateConfidence: native.templateConfidence,
        zoneMetrics: native.zoneMetrics,
      );
      final result = AnalysisResult.classified(
        score: score,
        confidence: confidence,
        isFraudulent: isFraudulent,
        explanation: zoneExplanation,
      );
      return _PipelineOutcome(
        result: result,
        fileSha256: fileSha256,
        fileSizeBytes: fileSizeBytes,
        decodedWidth: decodedWidth,
        decodedHeight: decodedHeight,
        backendUsed: 'native-opencv',
        backendNote: native.reason,
      );
    } catch (e, st) {
      final fallbackNote = 'native_failed_fallback_to_dart: $e';
      _reportBackendUsage(
        imagePath: sourcePathForNative,
        backendUsed: 'dart-image-fallback',
        backendNote: fallbackNote,
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'vivy.preprocess',
          context: ErrorDescription(
            'Native preprocess failed; Dart fallback path executed.',
          ),
        ),
      );
    }

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
      return _PipelineOutcome(
        result: result,
        fileSha256: fileSha256,
        fileSizeBytes: fileSizeBytes,
        decodedWidth: decodedWidth,
        decodedHeight: decodedHeight,
        backendUsed: 'dart-image-fallback',
        backendNote: 'geometry_gate_failed',
      );
    }

    final normalized = _preprocessForModel(roiResult.roi!);
    final score = _runModel(normalized);

    if ((score - kFraudThreshold).abs() < kUnclearBand) {
      final result = AnalysisResult.unclear(
        score: score,
        message: 'Result unclear - try a clearer or better-lit photo.',
      );
      return _PipelineOutcome(
        result: result,
        fileSha256: fileSha256,
        fileSizeBytes: fileSizeBytes,
        decodedWidth: decodedWidth,
        decodedHeight: decodedHeight,
        backendUsed: 'dart-image-fallback',
        backendNote: 'ok',
      );
    }

    final isFraudulent = score >= kFraudThreshold;
    final confidence = isFraudulent ? score : (1.0 - score);
    final fallbackZoneFeatures = _extractZoneFeaturesFromRoi(roiResult.roi!);
    final fallbackTemplate = _inferTemplateFamily(
      roiWidth: roiResult.roi!.width,
      roiHeight: roiResult.roi!.height,
    );
    final zoneExplanation = _buildZoneExplanation(
      isFraudulent: isFraudulent,
      confidence: confidence,
      family: fallbackTemplate.family,
      templateConfidence: fallbackTemplate.confidence,
      zoneMetrics: fallbackZoneFeatures,
    );
    final result = AnalysisResult.classified(
      score: score,
      confidence: confidence,
      isFraudulent: isFraudulent,
      explanation: zoneExplanation,
    );
    return _PipelineOutcome(
      result: result,
      fileSha256: fileSha256,
      fileSizeBytes: fileSizeBytes,
      decodedWidth: decodedWidth,
      decodedHeight: decodedHeight,
      backendUsed: 'dart-image-fallback',
      backendNote: 'ok',
    );
  }

  Future<_NativePreprocessResult> _preprocessNative(String imagePath) async {
    final raw = await _preprocessChannel.invokeMethod<Object?>(
      'preprocessReceipt',
      <String, Object?>{'path': imagePath},
    );
    if (raw is! Map) {
      throw Exception('Native preprocess returned invalid payload type.');
    }

    final map = Map<dynamic, dynamic>.from(raw);
    final geometryPass = map['geometryPass'] == true;
    final reason = (map['reason'] ?? '').toString();
    final areaRatio = (map['areaRatio'] as num?)?.toDouble() ?? 0.0;
    final aspectRatio = (map['aspectRatio'] as num?)?.toDouble() ?? 0.0;
    final templateFamily = (map['templateFamily'] as String?) ?? 'generic';
    final templateConfidence =
      (map['templateConfidence'] as num?)?.toDouble() ?? 0.0;
    final zoneMetrics = _parseNativeZoneMetrics(map['zoneMetrics']);

    if (!geometryPass) {
      return _NativePreprocessResult(
        geometryPass: false,
        reason: reason,
        areaRatio: areaRatio,
        aspectRatio: aspectRatio,
        templateFamily: templateFamily,
        templateConfidence: templateConfidence,
        zoneMetrics: zoneMetrics,
      );
    }

    final tensorBytesAny = map['tensorBytes'];
    Uint8List? tensorBytes;
    if (tensorBytesAny is Uint8List) {
      tensorBytes = tensorBytesAny;
    } else if (tensorBytesAny is List) {
      tensorBytes = Uint8List.fromList(
        tensorBytesAny.cast<int>(),
      );
    }

    if (tensorBytes == null) {
      throw Exception('Native preprocess did not return tensorBytes.');
    }

    final expectedBytes = kInputSize * kInputSize * 3 * 4;
    if (tensorBytes.lengthInBytes != expectedBytes) {
      throw Exception(
        'Native tensorBytes length mismatch: ${tensorBytes.lengthInBytes} != $expectedBytes',
      );
    }

    final data = ByteData.sublistView(tensorBytes);
    final tensor = Float32List(kInputSize * kInputSize * 3);
    for (var i = 0; i < tensor.length; i++) {
      tensor[i] = data.getFloat32(i * 4, Endian.little);
    }

    return _NativePreprocessResult(
      geometryPass: true,
      reason: reason,
      areaRatio: areaRatio,
      aspectRatio: aspectRatio,
      templateFamily: templateFamily,
      templateConfidence: templateConfidence,
      zoneMetrics: zoneMetrics,
      tensor: tensor,
    );
  }

  void _reportBackendUsage({
    required String imagePath,
    required String backendUsed,
    required String backendNote,
  }) {
    final msg =
        '[VIVY][BACKEND] backend=$backendUsed note=$backendNote image=${_basename(imagePath)}';
    debugPrint(msg);
    assert(() {
      debugPrint(msg);
      return true;
    }());
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
    _syncAnalyzeUiState();
    await _recordRawScoreObservation(
      result: result,
      imagePath: isFraudulent ? 'debug_fraudulent.png' : 'debug_genuine.png',
      fileSha256: 'debug_simulated',
      fileSizeBytes: 0,
      decodedWidth: null,
      decodedHeight: null,
      backendUsed: 'debug-simulated',
      backendNote: 'manual_debug_button',
    );
    await _recordHistory(result);
  }

  Future<void> _recordRawScoreObservation({
    required AnalysisResult result,
    required String imagePath,
    required String fileSha256,
    required int fileSizeBytes,
    required int? decodedWidth,
    required int? decodedHeight,
    required String backendUsed,
    required String backendNote,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_rawScoreStorageKey) ?? <String>[];
      final row = _buildRawScoreCsvRow(
        result: result,
        imagePath: imagePath,
        fileSha256: fileSha256,
        fileSizeBytes: fileSizeBytes,
        decodedWidth: decodedWidth,
        decodedHeight: decodedHeight,
        backendUsed: backendUsed,
        backendNote: backendNote,
      );
      await prefs.setStringList(_rawScoreStorageKey, <String>[...existing, row]);
    } catch (_) {
      // Keep analysis flow responsive even if score logging fails.
    }
  }

  Future<void> _maybeRunDebugBatchIngestion({required String reason}) async {
    if (kReleaseMode || _isDebugBatchRunning || _interpreter == null) {
      return;
    }

    final rootDir = await _debugBatchRootDir();
    if (rootDir == null) {
      return;
    }

    final trigger = File(
      '${rootDir.path}${Platform.pathSeparator}$_debugBatchTriggerName',
    );
    if (!trigger.existsSync()) {
      return;
    }

    _isDebugBatchRunning = true;
    try {
      final inbox = Directory(
        '${rootDir.path}${Platform.pathSeparator}$_debugBatchInboxName',
      );
      final exportDir = Directory(
        '${rootDir.path}${Platform.pathSeparator}$_debugBatchExportName',
      )..createSync(recursive: true);

      final images = inbox
          .listSync()
          .whereType<File>()
          .where(_isBatchImageFile)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-');
      final csvPath =
          '${exportDir.path}${Platform.pathSeparator}batch_results_$timestamp.csv';
      final csvFile = File(csvPath);
      final rows = <String>[];

      for (final file in images) {
        try {
          final bytes = await file.readAsBytes();
          final outcome = await _analyzeBytesThroughLivePipeline(
            bytes: bytes,
            sourcePathForNative: file.path,
          );
          rows.add(
            _buildRawScoreCsvRow(
              result: outcome.result,
              imagePath: file.path,
              fileSha256: outcome.fileSha256,
              fileSizeBytes: outcome.fileSizeBytes,
              decodedWidth: outcome.decodedWidth,
              decodedHeight: outcome.decodedHeight,
              backendUsed: outcome.backendUsed,
              backendNote: outcome.backendNote,
            ),
          );
        } catch (_) {
          final errorResult = AnalysisResult.error('Batch analysis failed.');
          rows.add(
            _buildRawScoreCsvRow(
              result: errorResult,
              imagePath: file.path,
              fileSha256: '',
              fileSizeBytes: 0,
              decodedWidth: null,
              decodedHeight: null,
              backendUsed: 'error',
              backendNote: 'batch_analysis_failed',
            ),
          );
        }
      }

      const header =
          'timestamp_iso,filename,result_type,raw_score,threshold,file_path,file_sha256,file_size_bytes,decoded_width,decoded_height,backend_used,backend_note';
      final csv = rows.isEmpty ? header : '$header\n${rows.join('\n')}';
      await csvFile.writeAsString(csv, flush: true);

      final status = {
        'trigger_reason': reason,
        'ran_at_utc': DateTime.now().toUtc().toIso8601String(),
        'inbox_dir': inbox.path,
        'export_csv_path': csvFile.path,
        'processed_count': rows.length,
      };
      final statusFile = File(
        '${rootDir.path}${Platform.pathSeparator}$_debugBatchStatusName',
      );
      await statusFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(status),
        flush: true,
      );

      trigger.deleteSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Debug batch processed ${rows.length} image(s).',
            ),
          ),
        );
      }
    } finally {
      _isDebugBatchRunning = false;
    }
  }

  Future<Directory?> _debugBatchRootDir() async {
    Directory? base;

    // Some Android images deny app writes under external app-specific paths.
    try {
      base = await getExternalStorageDirectory();
      if (base != null) {
        final probe = Directory(
          '${base.path}${Platform.pathSeparator}$_debugBatchRootName',
        );
        probe.createSync(recursive: true);
        Directory(
          '${probe.path}${Platform.pathSeparator}$_debugBatchInboxName',
        ).createSync(recursive: true);
        return probe;
      }
    } catch (_) {
      // Fall back to internal app documents storage.
    }

    final docs = await getApplicationSupportDirectory();
    final root = Directory(
      '${docs.path}${Platform.pathSeparator}$_debugBatchRootName',
    );
    root.createSync(recursive: true);
    Directory(
      '${root.path}${Platform.pathSeparator}$_debugBatchInboxName',
    ).createSync(recursive: true);
    return root;
  }

  bool _isBatchImageFile(File file) {
    final lower = file.path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jfif') ||
        lower.endsWith('.webp');
  }

  Future<void> _copyRawScoreLogToClipboard() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(_rawScoreStorageKey) ?? <String>[];
    const header =
      'timestamp_iso,filename,result_type,raw_score,threshold,file_path,file_sha256,file_size_bytes,decoded_width,decoded_height,backend_used,backend_note';
    final csv = rows.isEmpty ? header : '$header\n${rows.join('\n')}';

    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) {
      return;
    }
    final count = rows.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'No score rows yet. Header copied to clipboard.'
              : 'Copied $count raw-score rows to clipboard.',
        ),
      ),
    );
  }

  String _buildRawScoreCsvRow({
    required AnalysisResult result,
    required String imagePath,
    required String fileSha256,
    required int fileSizeBytes,
    required int? decodedWidth,
    required int? decodedHeight,
    required String backendUsed,
    required String backendNote,
  }) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final filename = _basename(imagePath);
    final score = result.score == null ? '' : result.score!.toStringAsFixed(6);
    final encodedPath = imagePath.replaceAll(',', '_');

    return [
      timestamp,
      filename,
      result.type.name,
      score,
      kFraudThreshold.toStringAsFixed(2),
      encodedPath,
      fileSha256,
      fileSizeBytes.toString(),
      decodedWidth?.toString() ?? '',
      decodedHeight?.toString() ?? '',
      backendUsed,
      backendNote.replaceAll(',', ';'),
    ].join(',');
  }

  String _sha256Hex(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _basename(String value) {
    if (value.isEmpty) {
      return 'unknown';
    }
    final normalized = value.replaceAll('\\\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? value : parts.last;
  }

  Map<String, _ZoneFeatureVector> _extractZoneFeaturesFromRoi(img.Image roi) {
    final family = _inferTemplateFamily(roiWidth: roi.width, roiHeight: roi.height);
    final layout = kZoneLayouts[family.family] ?? kZoneLayouts['android-like']!;
    final gray = img.grayscale(roi);
    final out = <String, _ZoneFeatureVector>{};
    for (final entry in layout.entries) {
      final bounds = entry.value;
      final zone = _cropNormalized(gray, bounds);
      out[entry.key] = _computeZoneFeatureVector(zone);
    }
    return out;
  }

  _TemplateFamilyGuess _inferTemplateFamily({
    required int roiWidth,
    required int roiHeight,
  }) {
    final aspect = roiWidth / math.max(roiHeight.toDouble(), 1.0);
    if (aspect >= 0.80) {
      return const _TemplateFamilyGuess(family: 'android-like', confidence: 0.86);
    }
    if (aspect <= 0.68) {
      return const _TemplateFamilyGuess(family: 'ios-like', confidence: 0.86);
    }
    return const _TemplateFamilyGuess(family: 'generic', confidence: 0.55);
  }

  img.Image _cropNormalized(img.Image gray, List<double> bounds) {
    final x0 = _denormX(bounds[0], gray.width);
    final y0 = _denormY(bounds[1], gray.height);
    final x1 = _denormX(bounds[2], gray.width);
    final y1 = _denormY(bounds[3], gray.height);
    final w = math.max(1, x1 - x0);
    final h = math.max(1, y1 - y0);
    return img.copyCrop(gray, x: x0, y: y0, width: w, height: h);
  }

  int _denormX(double x, int width) {
    final raw = (x * width).round();
    return raw.clamp(0, math.max(0, width - 1));
  }

  int _denormY(double y, int height) {
    final raw = (y * height).round();
    return raw.clamp(0, math.max(0, height - 1));
  }

  _ZoneFeatureVector _computeZoneFeatureVector(img.Image grayZone) {
    final lapVar = _laplacianVariance(grayZone);
    final edgeDensity = _edgeDensity(grayZone);
    final bin = _binaryMask(grayZone, _otsuThreshold(grayZone));
    final stats = _connectedComponentStats(bin, grayZone.width, grayZone.height);
    final strokeFill = bin.where((v) => v).length / math.max(1, bin.length);

    if (stats.isEmpty) {
      return _ZoneFeatureVector(
        laplacianVar: lapVar,
        edgeDensity: edgeDensity,
        spacingCv: 0.0,
        alignmentStd: 0.0,
        fontHeightCv: 0.0,
        strokeFillRatio: strokeFill,
      );
    }

    final centerXs = stats.map((s) => s.centerX).toList()..sort();
    final gaps = <double>[];
    for (var i = 1; i < centerXs.length; i++) {
      final d = centerXs[i] - centerXs[i - 1];
      if (d > 1.0) {
        gaps.add(d);
      }
    }
    final spacingCv = gaps.length < 2
        ? 0.0
        : _stddev(gaps) / math.max(_mean(gaps), 1e-6);

    final centerYs = stats.map((s) => s.centerY).toList();
    final heights = stats.map((s) => s.height).toList();
    final alignmentStd = _stddev(centerYs) / math.max(grayZone.height.toDouble(), 1.0);
    final fontHeightCv = _stddev(heights) / math.max(_mean(heights), 1e-6);

    return _ZoneFeatureVector(
      laplacianVar: lapVar,
      edgeDensity: edgeDensity,
      spacingCv: spacingCv,
      alignmentStd: alignmentStd,
      fontHeightCv: fontHeightCv,
      strokeFillRatio: strokeFill,
    );
  }

  double _laplacianVariance(img.Image gray) {
    final values = <double>[];
    final kernel = const <List<int>>[
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0],
    ];
    for (var y = 1; y < gray.height - 1; y++) {
      for (var x = 1; x < gray.width - 1; x++) {
        var v = 0.0;
        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final p = gray.getPixel(x + kx, y + ky).r.toDouble();
            v += kernel[ky + 1][kx + 1] * p;
          }
        }
        values.add(v);
      }
    }
    if (values.isEmpty) {
      return 0.0;
    }
    final m = _mean(values);
    var acc = 0.0;
    for (final v in values) {
      final d = v - m;
      acc += d * d;
    }
    return acc / values.length;
  }

  double _edgeDensity(img.Image gray) {
    var count = 0;
    var total = 0;
    for (var y = 1; y < gray.height - 1; y++) {
      for (var x = 1; x < gray.width - 1; x++) {
        final gx = (gray.getPixel(x + 1, y).r - gray.getPixel(x - 1, y).r).toDouble();
        final gy = (gray.getPixel(x, y + 1).r - gray.getPixel(x, y - 1).r).toDouble();
        final mag = math.sqrt(gx * gx + gy * gy);
        if (mag >= 48.0) {
          count++;
        }
        total++;
      }
    }
    if (total == 0) {
      return 0.0;
    }
    return count / total;
  }

  List<_ConnectedComponentStat> _connectedComponentStats(
    List<bool> mask,
    int width,
    int height,
  ) {
    final visited = Uint8List(mask.length);
    final stats = <_ConnectedComponentStat>[];
    final qx = <int>[];
    final qy = <int>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final idx = y * width + x;
        if (!mask[idx] || visited[idx] == 1) {
          continue;
        }

        qx.clear();
        qy.clear();
        qx.add(x);
        qy.add(y);
        visited[idx] = 1;

        var minX = x;
        var minY = y;
        var maxX = x;
        var maxY = y;
        var area = 0;
        var sumX = 0.0;
        var sumY = 0.0;

        for (var p = 0; p < qx.length; p++) {
          final cx = qx[p];
          final cy = qy[p];
          area++;
          sumX += cx;
          sumY += cy;
          if (cx < minX) minX = cx;
          if (cy < minY) minY = cy;
          if (cx > maxX) maxX = cx;
          if (cy > maxY) maxY = cy;

          for (var ny = cy - 1; ny <= cy + 1; ny++) {
            if (ny < 0 || ny >= height) {
              continue;
            }
            for (var nx = cx - 1; nx <= cx + 1; nx++) {
              if (nx < 0 || nx >= width) {
                continue;
              }
              final nidx = ny * width + nx;
              if (!mask[nidx] || visited[nidx] == 1) {
                continue;
              }
              visited[nidx] = 1;
              qx.add(nx);
              qy.add(ny);
            }
          }
        }

        final bw = maxX - minX + 1;
        final bh = maxY - minY + 1;
        if (area < 10 || bw < 2 || bh < 4) {
          continue;
        }
        stats.add(
          _ConnectedComponentStat(
            centerX: sumX / area,
            centerY: sumY / area,
            height: bh.toDouble(),
          ),
        );
      }
    }
    return stats;
  }

  double _mean(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    var sum = 0.0;
    for (final v in values) {
      sum += v;
    }
    return sum / values.length;
  }

  double _stddev(List<double> values) {
    if (values.length < 2) {
      return 0.0;
    }
    final m = _mean(values);
    var acc = 0.0;
    for (final v in values) {
      final d = v - m;
      acc += d * d;
    }
    return math.sqrt(acc / values.length);
  }

  Map<String, _ZoneFeatureVector> _parseNativeZoneMetrics(Object? raw) {
    if (raw is! Map) {
      return const <String, _ZoneFeatureVector>{};
    }
    final out = <String, _ZoneFeatureVector>{};
    for (final entry in raw.entries) {
      final zoneName = entry.key.toString();
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      out[zoneName] = _ZoneFeatureVector(
        laplacianVar: (value['laplacian_var'] as num?)?.toDouble() ?? 0.0,
        edgeDensity: (value['edge_density'] as num?)?.toDouble() ?? 0.0,
        spacingCv: (value['spacing_cv'] as num?)?.toDouble() ?? 0.0,
        alignmentStd: (value['alignment_std'] as num?)?.toDouble() ?? 0.0,
        fontHeightCv: (value['font_height_cv'] as num?)?.toDouble() ?? 0.0,
        strokeFillRatio: (value['stroke_fill_ratio'] as num?)?.toDouble() ?? 0.0,
      );
    }
    return out;
  }

  String _buildZoneExplanation({
    required bool isFraudulent,
    required double confidence,
    required String family,
    required double templateConfidence,
    required Map<String, _ZoneFeatureVector> zoneMetrics,
  }) {
    final confidenceText = (confidence * 100).toStringAsFixed(1);
    final profile = _zoneBaselineProfile;
    if (profile == null || zoneMetrics.isEmpty) {
      return isFraudulent
          ? 'Receipt is classified as fraudulent ($confidenceText% confidence). The image shows suspicious formatting signals, but zone-level evidence is unavailable on this device.'
          : 'Receipt is classified as genuine ($confidenceText% confidence). No strong anomalies were detected in available checks.';
    }

    final tuned = profile.precisionBias;
    final lowTemplateConfidence =
        family == 'generic' || templateConfidence < tuned.templateConfidenceMin;
    final baselineFamily = lowTemplateConfidence
        ? 'generic'
        : (profile.stats.containsKey(family) ? family : 'generic');

    final anomalies = <_ZoneAnomalySummary>[];
    for (final entry in zoneMetrics.entries) {
      final zone = entry.key;
      final vector = entry.value;
      final zoneStats = profile.stats[baselineFamily]?[zone];
      if (zoneStats == null) {
        continue;
      }

      final failures = <String>[];
      var severeCount = 0;
      final metricValues = vector.toMap();
      for (final metricEntry in metricValues.entries) {
        final metric = metricEntry.key;
        final value = metricEntry.value;
        final ref = zoneStats[metric];
        if (ref == null) {
          continue;
        }
        final z = (value - ref.median).abs() / math.max(ref.mad * 1.4826, 1e-6);
        final outsideBand = value < ref.p05 || value > ref.p95;
        if (z >= tuned.metricZThreshold && outsideBand) {
          failures.add(metric);
          if (tuned.severeMetrics.contains(metric)) {
            severeCount++;
          }
        }
      }

      final failsZone = failures.length >= tuned.zoneFailMetricsMin ||
          (failures.length >= tuned.zoneFailMetricsMinWithSevere && severeCount >= 1);
      if (failsZone) {
        anomalies.add(
          _ZoneAnomalySummary(
            zoneName: zone,
            failedMetrics: failures,
          ),
        );
      }
    }

    if (isFraudulent) {
      if (lowTemplateConfidence) {
        return 'Receipt is classified as fraudulent ($confidenceText% confidence). Template family confidence is low, so zone-level claims are intentionally withheld to avoid overconfident localization.';
      }
      if (anomalies.isEmpty) {
        return 'Receipt is classified as fraudulent ($confidenceText% confidence). No zone passed strict anomaly criteria; classification relies on global model evidence.';
      }
      final zoneList = anomalies
          .map((a) => kZoneDisplayNames[a.zoneName] ?? a.zoneName)
          .join(', ');
      return 'Receipt is classified as fraudulent ($confidenceText% confidence). Conservative zone anomalies were found in: $zoneList.';
    }

    return 'Receipt is classified as genuine ($confidenceText% confidence). No zone exceeded strict anomaly thresholds against train-genuine baselines.';
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
              uiStateListenable: _analyzeUiState,
              threshold: kFraudThreshold,
              onPickPhoto: _pickPhoto,
              onOpenHistory: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HistoryScreen(entries: _historyEntries),
                  ),
                );
              },
              onExportRawScores: _copyRawScoreLogToClipboard,
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
      onOpenLearnMore: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const LearnMoreScreen(),
          ),
        );
      },
      onOpenMessengerQr: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MessengerQrScreen(),
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

class _NativePreprocessResult {
  const _NativePreprocessResult({
    required this.geometryPass,
    required this.reason,
    required this.areaRatio,
    required this.aspectRatio,
    required this.templateFamily,
    required this.templateConfidence,
    required this.zoneMetrics,
    this.tensor,
  });

  final bool geometryPass;
  final String reason;
  final double areaRatio;
  final double aspectRatio;
  final String templateFamily;
  final double templateConfidence;
  final Map<String, _ZoneFeatureVector> zoneMetrics;
  final Float32List? tensor;
}

class _PipelineOutcome {
  const _PipelineOutcome({
    required this.result,
    required this.fileSha256,
    required this.fileSizeBytes,
    required this.decodedWidth,
    required this.decodedHeight,
    required this.backendUsed,
    required this.backendNote,
  });

  final AnalysisResult result;
  final String fileSha256;
  final int fileSizeBytes;
  final int? decodedWidth;
  final int? decodedHeight;
  final String backendUsed;
  final String backendNote;
}

class _ConnectedComponentStat {
  const _ConnectedComponentStat({
    required this.centerX,
    required this.centerY,
    required this.height,
  });

  final double centerX;
  final double centerY;
  final double height;
}

class _ZoneFeatureVector {
  const _ZoneFeatureVector({
    required this.laplacianVar,
    required this.edgeDensity,
    required this.spacingCv,
    required this.alignmentStd,
    required this.fontHeightCv,
    required this.strokeFillRatio,
  });

  final double laplacianVar;
  final double edgeDensity;
  final double spacingCv;
  final double alignmentStd;
  final double fontHeightCv;
  final double strokeFillRatio;

  Map<String, double> toMap() {
    return {
      'laplacian_var': laplacianVar,
      'edge_density': edgeDensity,
      'spacing_cv': spacingCv,
      'alignment_std': alignmentStd,
      'font_height_cv': fontHeightCv,
      'stroke_fill_ratio': strokeFillRatio,
    };
  }
}

class _TemplateFamilyGuess {
  const _TemplateFamilyGuess({
    required this.family,
    required this.confidence,
  });

  final String family;
  final double confidence;
}

class _ZoneMetricBaseline {
  const _ZoneMetricBaseline({
    required this.median,
    required this.mad,
    required this.p05,
    required this.p95,
  });

  final double median;
  final double mad;
  final double p05;
  final double p95;

  factory _ZoneMetricBaseline.fromJson(Map<String, dynamic> json) {
    return _ZoneMetricBaseline(
      median: (json['median'] as num?)?.toDouble() ?? 0.0,
      mad: (json['mad'] as num?)?.toDouble() ?? 1e-6,
      p05: (json['p05'] as num?)?.toDouble() ?? 0.0,
      p95: (json['p95'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class _ZonePrecisionBias {
  const _ZonePrecisionBias({
    required this.metricZThreshold,
    required this.zoneFailMetricsMin,
    required this.zoneFailMetricsMinWithSevere,
    required this.severeMetrics,
    required this.templateConfidenceMin,
  });

  final double metricZThreshold;
  final int zoneFailMetricsMin;
  final int zoneFailMetricsMinWithSevere;
  final Set<String> severeMetrics;
  final double templateConfidenceMin;

  factory _ZonePrecisionBias.fromJson(Map<String, dynamic> json) {
    final severe = (json['severe_metrics'] as List?) ?? const <Object>[];
    return _ZonePrecisionBias(
      metricZThreshold: (json['metric_z_threshold'] as num?)?.toDouble() ?? 3.5,
      zoneFailMetricsMin: (json['zone_fail_metrics_min'] as num?)?.toInt() ?? 3,
      zoneFailMetricsMinWithSevere:
          (json['zone_fail_metrics_min_with_severe'] as num?)?.toInt() ?? 2,
      severeMetrics: severe.map((e) => e.toString()).toSet(),
      templateConfidenceMin:
          (json['template_confidence_min'] as num?)?.toDouble() ?? 0.8,
    );
  }
}

class _ZoneBaselineProfile {
  const _ZoneBaselineProfile({
    required this.stats,
    required this.precisionBias,
  });

  final Map<String, Map<String, Map<String, _ZoneMetricBaseline>>> stats;
  final _ZonePrecisionBias precisionBias;

  factory _ZoneBaselineProfile.fromJson(Map<String, dynamic> json) {
    final statsRaw = (json['stats'] as Map?) ?? const <Object, Object>{};
    final stats = <String, Map<String, Map<String, _ZoneMetricBaseline>>>{};

    for (final familyEntry in statsRaw.entries) {
      final family = familyEntry.key.toString();
      final zonesRaw = familyEntry.value;
      if (zonesRaw is! Map) {
        continue;
      }
      final zones = <String, Map<String, _ZoneMetricBaseline>>{};
      for (final zoneEntry in zonesRaw.entries) {
        final zone = zoneEntry.key.toString();
        final metricsRaw = zoneEntry.value;
        if (metricsRaw is! Map) {
          continue;
        }
        final metrics = <String, _ZoneMetricBaseline>{};
        for (final metricEntry in metricsRaw.entries) {
          final metricName = metricEntry.key.toString();
          final raw = metricEntry.value;
          if (raw is! Map) {
            continue;
          }
          metrics[metricName] = _ZoneMetricBaseline.fromJson(
            Map<String, dynamic>.from(raw),
          );
        }
        zones[zone] = metrics;
      }
      stats[family] = zones;
    }

    final precisionRaw =
        (json['precision_bias'] as Map?) ?? const <Object, Object>{};
    return _ZoneBaselineProfile(
      stats: stats,
      precisionBias: _ZonePrecisionBias.fromJson(
        Map<String, dynamic>.from(precisionRaw),
      ),
    );
  }
}

class _ZoneAnomalySummary {
  const _ZoneAnomalySummary({
    required this.zoneName,
    required this.failedMetrics,
  });

  final String zoneName;
  final List<String> failedMetrics;
}
