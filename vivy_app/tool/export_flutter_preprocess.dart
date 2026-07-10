import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const double kMinAreaRatio = 0.12;
const double kMinAspectRatio = 0.25;
const double kMaxAspectRatio = 3.5;
const int kInputSize = 224;

void main(List<String> args) {
  final parsed = _parseArgs(args);
  final inputPath = parsed['input'];
  final outDirArg = parsed['out'];
  if (inputPath == null || outDirArg == null) {
    stderr.writeln('Usage: dart run tool/export_flutter_preprocess.dart --input <image> --out <output_dir>');
    exit(2);
  }

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input image not found: $inputPath');
    exit(2);
  }

  final outDir = Directory(outDirArg);
  outDir.createSync(recursive: true);

  final bytes = inputFile.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode image: $inputPath');
    exit(2);
  }

  final roiResult = _extractReceiptRoi(decoded);
  if (!roiResult.geometryPass || roiResult.roi == null) {
    final failMeta = {
      'input_path': inputFile.absolute.path,
      'geometry_pass': false,
      'area_ratio': roiResult.areaRatio,
      'aspect_ratio': roiResult.aspectRatio,
      'message': 'ROI geometry gate failed in Flutter preprocessing.',
    };
    final failFile = File('${outDir.path}${Platform.pathSeparator}flutter_preprocess_metadata.json');
    failFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(failMeta));
    stdout.writeln('ROI gate failed. Wrote metadata: ${failFile.path}');
    exit(1);
  }

  final tensor = _preprocessForModel(roiResult.roi!);
  final tensorPath = '${outDir.path}${Platform.pathSeparator}flutter_tensor_f32.bin';
  final tensorFile = File(tensorPath);
  tensorFile.writeAsBytesSync(tensor.buffer.asUint8List(), flush: true);

  final roiPngPath = '${outDir.path}${Platform.pathSeparator}flutter_roi.png';
  File(roiPngPath).writeAsBytesSync(img.encodePng(roiResult.roi!), flush: true);

  final resized = img.copyResize(
    roiResult.roi!,
    width: kInputSize,
    height: kInputSize,
    interpolation: img.Interpolation.average,
  );
  final resizedPngPath = '${outDir.path}${Platform.pathSeparator}flutter_resized_224.png';
  File(resizedPngPath).writeAsBytesSync(img.encodePng(resized), flush: true);

  double sum = 0;
  double sumSq = 0;
  double minVal = double.infinity;
  double maxVal = double.negativeInfinity;
  for (final v in tensor) {
    sum += v;
    sumSq += v * v;
    if (v < minVal) minVal = v;
    if (v > maxVal) maxVal = v;
  }
  final n = tensor.length.toDouble();
  final mean = sum / n;
  final variance = math.max(0.0, (sumSq / n) - (mean * mean));
  final std = math.sqrt(variance);

  final sampleIndices = <int>[0, 1, 2, 3, 4, 5, (112 * 224 + 112) * 3, (223 * 224 + 223) * 3];
  final sampleValues = {
    for (final i in sampleIndices)
      i.toString(): (i >= 0 && i < tensor.length) ? tensor[i] : null,
  };

  final metadata = {
    'input_path': inputFile.absolute.path,
    'geometry_pass': true,
    'area_ratio': roiResult.areaRatio,
    'aspect_ratio': roiResult.aspectRatio,
    'roi_box': {
      'x': roiResult.component?.x,
      'y': roiResult.component?.y,
      'w': roiResult.component?.w,
      'h': roiResult.component?.h,
      'area': roiResult.component?.area,
    },
    'crop_box_with_padding': {
      'x0': roiResult.cropX0,
      'y0': roiResult.cropY0,
      'x1': roiResult.cropX1,
      'y1': roiResult.cropY1,
      'width': roiResult.cropX1 != null && roiResult.cropX0 != null ? (roiResult.cropX1! - roiResult.cropX0! + 1) : null,
      'height': roiResult.cropY1 != null && roiResult.cropY0 != null ? (roiResult.cropY1! - roiResult.cropY0! + 1) : null,
    },
    'output_tensor_shape': [224, 224, 3],
    'output_tensor_path': tensorFile.absolute.path,
    'roi_png_path': File(roiPngPath).absolute.path,
    'resized_png_path': File(resizedPngPath).absolute.path,
    'stats': {
      'mean': mean,
      'std': std,
      'min': minVal,
      'max': maxVal,
    },
    'sample_values': sampleValues,
  };

  final metaFile = File('${outDir.path}${Platform.pathSeparator}flutter_preprocess_metadata.json');
  metaFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metadata), flush: true);
  stdout.writeln('Wrote tensor: ${tensorFile.path}');
  stdout.writeln('Wrote metadata: ${metaFile.path}');
}

Map<String, String?> _parseArgs(List<String> args) {
  String? input;
  String? out;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--input' && i + 1 < args.length) {
      input = args[++i];
    } else if (args[i] == '--out' && i + 1 < args.length) {
      out = args[++i];
    }
  }
  return {'input': input, 'out': out};
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
      component: null,
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
      component: component,
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
    component: component,
    cropX0: x0,
    cropY0: y0,
    cropX1: x1,
    cropY1: y1,
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
        if (ny < 0 || ny >= height) continue;
        for (var kx = -r; kx <= r; kx++) {
          final nx = x + kx;
          if (nx < 0 || nx >= width) continue;
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
      if (visited[startIdx] || !mask[startIdx]) continue;

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
      if (h <= 0) continue;

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

class RoiExtractionResult {
  const RoiExtractionResult({
    required this.roi,
    required this.geometryPass,
    required this.areaRatio,
    required this.aspectRatio,
    required this.component,
    this.cropX0,
    this.cropY0,
    this.cropX1,
    this.cropY1,
  });

  final img.Image? roi;
  final bool geometryPass;
  final double areaRatio;
  final double aspectRatio;
  final _ComponentBox? component;
  final int? cropX0;
  final int? cropY0;
  final int? cropX1;
  final int? cropY1;
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
