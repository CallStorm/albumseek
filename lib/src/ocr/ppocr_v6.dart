import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../engine/inference_backend.dart';
import 'ctc_decode.dart';
import 'text_boxes.dart';

/// PP-OCRv6 medium detection and recognition on ONNX Runtime's CPU provider.
///
/// Normalization matches RapidOCR: BGR, `(pixel / 255 - 0.5) / 0.5`. The long
/// side of a detection input is capped at 960 so a 12 MP photo does not
/// allocate a multi-thousand-pixel map on a phone.
class PpOcrV6 {
  PpOcrV6({
    OnnxRuntimeBackend? detector,
    OnnxRuntimeBackend? recognizer,
  }) : _detector = detector ?? OnnxRuntimeBackend(),
       _recognizer = recognizer ?? OnnxRuntimeBackend();

  final OnnxRuntimeBackend _detector;
  final OnnxRuntimeBackend _recognizer;
  List<String> _dictionary = const [];

  bool get isOpen => _detector.isOpen && _recognizer.isOpen;

  Future<void> open({
    required String detectionPath,
    required String recognitionPath,
    required String dictionary,
  }) async {
    await _detector.loadModel(detectionPath);
    await _recognizer.loadModel(recognitionPath);
    _dictionary = [
      for (final line in dictionary.split('\n'))
        if (line.isNotEmpty) line,
    ];
    if (_dictionary.isNotEmpty && _dictionary.last.isEmpty) {
      _dictionary.removeLast();
    }
  }

  Future<String> recognize(Uint8List encodedImage) async {
    if (!isOpen) {
      throw StateError('PP-OCRv6 is not loaded.');
    }
    final decoded = img.decodeImage(encodedImage);
    if (decoded == null) {
      return '';
    }
    final source = img.bakeOrientation(decoded);
    final prepared = _resizeLongSide(source, 960);
    final input = _chw(prepared, bgr: true);
    final detSession = _detector.session!;
    final detInput = await OrtValue.fromList(input, [
      1,
      3,
      prepared.height,
      prepared.width,
    ]);
    Map<String, OrtValue>? detOutputs;
    try {
      detOutputs = await detSession.run({
        detSession.inputNames.first: detInput,
      });
      final first = detOutputs.values.first;
      final scores = _asDoubles(await first.asList());
      final mapWidth = _mapWidth(scores.length, prepared.width, prepared.height);
      final mapHeight = scores.length ~/ mapWidth;
      final boxes = boxesFromMap(
        scores,
        width: mapWidth,
        height: mapHeight,
      );
      final lines = <String>[];
      for (final box in boxes) {
        final crop = _cropOriginal(source, prepared, box, mapWidth, mapHeight);
        if (crop == null) {
          continue;
        }
        final line = await _recognizeLine(crop);
        if (line.trim().isNotEmpty) {
          lines.add(line.trim());
        }
      }
      return lines.join('\n');
    } finally {
      await detInput.dispose();
      if (detOutputs != null) {
        for (final value in detOutputs.values) {
          await value.dispose();
        }
      }
    }
  }

  Future<void> close() async {
    await _detector.close();
    await _recognizer.close();
    _dictionary = const [];
  }

  Future<String> _recognizeLine(img.Image crop) async {
    final height = 48;
    final aspect = crop.width / crop.height;
    var width = (height * aspect).ceil();
    if (width < 8) {
      width = 8;
    }
    width = (width + 7) ~/ 8 * 8;
    if (width > 640) {
      width = 640;
    }
    final resized = img.copyResize(
      crop,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final data = _chw(resized, bgr: true);
    final session = _recognizer.session!;
    final input = await OrtValue.fromList(data, [1, 3, height, width]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: input});
      final scores = _asDoubles(await outputs.values.first.asList());
      final classes = _classes(scores, _dictionary.length);
      if (classes <= 1) {
        return '';
      }
      return ctcDecode(ctcArgmax(scores, classes), _dictionary);
    } finally {
      await input.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    }
  }
}

img.Image _resizeLongSide(img.Image source, int longSide) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= longSide) {
    return _align32(source);
  }
  final scale = longSide / longest;
  final width = (source.width * scale).round().clamp(32, longSide);
  final height = (source.height * scale).round().clamp(32, longSide);
  return _align32(
    img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    ),
  );
}

img.Image _align32(img.Image source) {
  final width = (source.width / 32).round().clamp(1, 4096) * 32;
  final height = (source.height / 32).round().clamp(1, 4096) * 32;
  if (width == source.width && height == source.height) {
    return source;
  }
  return img.copyResize(
    source,
    width: width,
    height: height,
    interpolation: img.Interpolation.linear,
  );
}

List<double> _chw(img.Image image, {required bool bgr}) {
  final plane = image.width * image.height;
  final data = List<double>.filled(3 * plane, 0);
  var offset = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final red = ((pixel.r.toDouble()) / 255.0 - 0.5) / 0.5;
      final green = ((pixel.g.toDouble()) / 255.0 - 0.5) / 0.5;
      final blue = ((pixel.b.toDouble()) / 255.0 - 0.5) / 0.5;
      final first = bgr ? blue : red;
      final third = bgr ? red : blue;
      data[offset] = first;
      data[plane + offset] = green;
      data[2 * plane + offset] = third;
      offset++;
    }
  }
  return data;
}

List<double> _asDoubles(List<dynamic> values) {
  final flat = <double>[];
  void walk(dynamic node) {
    if (node is List) {
      for (final item in node) {
        walk(item);
      }
    } else if (node is num) {
      flat.add(node.toDouble());
    }
  }
  walk(values);
  return flat;
}

int _mapWidth(int length, int inputWidth, int inputHeight) {
  if (length == inputWidth * inputHeight) {
    return inputWidth;
  }
  for (final divisor in [1, 2, 4]) {
    final width = inputWidth ~/ divisor;
    final height = inputHeight ~/ divisor;
    if (width > 0 && height > 0 && width * height == length) {
      return width;
    }
  }
  var width = inputWidth;
  while (width > 1 && length % width != 0) {
    width--;
  }
  return width <= 0 ? inputWidth : width;
}

int _classes(List<double> scores, int dictionaryLength) {
  final candidates = <int>[
    if (dictionaryLength > 0) dictionaryLength + 1,
    if (dictionaryLength > 0) dictionaryLength + 2,
    18710,
  ];
  for (final classes in candidates) {
    if (classes > 1 && scores.length % classes == 0) {
      return classes;
    }
  }
  return dictionaryLength > 0 ? dictionaryLength + 1 : 1;
}

img.Image? _cropOriginal(
  img.Image source,
  img.Image resized,
  TextBox box,
  int mapWidth,
  int mapHeight,
) {
  final scaleX = source.width / mapWidth;
  final scaleY = source.height / mapHeight;
  // The map matches the resized network input, which matches [resized].
  // Map coordinates are in network pixels. Scale through the resize ratio.
  final resizeX = resized.width / mapWidth;
  final resizeY = resized.height / mapHeight;
  final left = (box.left * resizeX * source.width / resized.width).round();
  final top = (box.top * resizeY * source.height / resized.height).round();
  final right = (box.right * resizeX * source.width / resized.width).round();
  final bottom = (box.bottom * resizeY * source.height / resized.height).round();
  final x = left.clamp(0, source.width - 1);
  final y = top.clamp(0, source.height - 1);
  final width = (right - left).clamp(2, source.width - x);
  final height = (bottom - top).clamp(2, source.height - y);
  if (width < 2 || height < 2) {
    return null;
  }
  // scaleX/scaleY stay referenced so a same-size map still crops the photo.
  if (scaleX <= 0 || scaleY <= 0) {
    return null;
  }
  return img.copyCrop(source, x: x, y: y, width: width, height: height);
}
