import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../engine/inference_backend.dart';
import 'face_cluster.dart';
import 'yunet_decode.dart';

/// One face located on the original photo, before or after embedding.
class LocatedFace {
  const LocatedFace({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    this.embedding = const [],
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double score;
  final List<double> embedding;

  LocatedFace withEmbedding(List<double> embedding) {
    return LocatedFace(
      x: x,
      y: y,
      width: width,
      height: height,
      score: score,
      embedding: embedding,
    );
  }
}

/// YuNet detection and AdaFace embeddings. The indexer keeps both sessions
/// open for the whole faces pass, then closes them.
class FacePipeline {
  FacePipeline({OnnxRuntimeBackend? detector, OnnxRuntimeBackend? embedder})
    : _detector = detector ?? OnnxRuntimeBackend(),
      _embedder = embedder ?? OnnxRuntimeBackend();

  final OnnxRuntimeBackend _detector;
  final OnnxRuntimeBackend _embedder;

  Future<void> openDetector(String path) {
    if (_detector.isOpen) {
      return Future<void>.value();
    }
    return _detector.loadModel(path);
  }

  Future<void> closeDetector() => _detector.close();

  Future<void> openEmbedder(String path) {
    if (_embedder.isOpen) {
      return Future<void>.value();
    }
    return _embedder.loadModel(path);
  }

  Future<void> closeEmbedder() => _embedder.close();

  Future<List<LocatedFace>> detect(Uint8List encoded) async {
    final session = _detector.session;
    if (session == null) {
      throw StateError('YuNet is not loaded.');
    }
    final decoded = img.decodeImage(encoded);
    if (decoded == null) {
      return const [];
    }
    final source = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      source,
      width: 640,
      height: 640,
      interpolation: img.Interpolation.linear,
    );
    final input = _chw(resized, scale: 1, shift: 0);
    final tensor = await OrtValue.fromList(input, [1, 3, 640, 640]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: tensor});
      final values = <String, List<double>>{};
      for (final entry in outputs.entries) {
        values[entry.key] = _flat(await entry.value.asList());
      }
      final faces = decodeYuNet(
        cls8: values['cls_8'] ?? const [],
        obj8: values['obj_8'] ?? const [],
        bbox8: values['bbox_8'] ?? const [],
        cls16: values['cls_16'] ?? const [],
        obj16: values['obj_16'] ?? const [],
        bbox16: values['bbox_16'] ?? const [],
        cls32: values['cls_32'] ?? const [],
        obj32: values['obj_32'] ?? const [],
        bbox32: values['bbox_32'] ?? const [],
      );
      final scaleX = source.width / 640;
      final scaleY = source.height / 640;
      return [
        for (final face in faces)
          LocatedFace(
            x: face.x * scaleX,
            y: face.y * scaleY,
            width: face.width * scaleX,
            height: face.height * scaleY,
            score: face.score,
          ),
      ];
    } finally {
      await tensor.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    }
  }

  Future<List<double>> embed(img.Image source, LocatedFace face) async {
    final session = _embedder.session;
    if (session == null) {
      throw StateError('AdaFace is not loaded.');
    }
    final crop = _crop(source, face);
    final resized = img.copyResize(
      crop,
      width: 112,
      height: 112,
      interpolation: img.Interpolation.linear,
    );
    final input = _chw(resized, scale: 1 / 127.5, shift: 127.5);
    final tensor = await OrtValue.fromList(input, [1, 3, 112, 112]);
    Map<String, OrtValue>? outputs;
    try {
      outputs = await session.run({session.inputNames.first: tensor});
      final vector = _flat(await outputs.values.first.asList());
      if (vector.length < 512) {
        throw StateError('AdaFace returned ${vector.length} values.');
      }
      return normalize(vector.sublist(0, 512));
    } finally {
      await tensor.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    }
  }

  Future<void> close() async {
    await closeDetector();
    await closeEmbedder();
  }
}

img.Image _crop(img.Image source, LocatedFace face) {
  final padX = face.width * 0.15;
  final padY = face.height * 0.15;
  final x = (face.x - padX).round().clamp(0, source.width - 1);
  final y = (face.y - padY).round().clamp(0, source.height - 1);
  final right = (face.x + face.width + padX).round().clamp(x + 1, source.width);
  final bottom = (face.y + face.height + padY).round().clamp(
    y + 1,
    source.height,
  );
  return img.copyCrop(source, x: x, y: y, width: right - x, height: bottom - y);
}

/// BGR channel-first. [shift] is subtracted before dividing by `1/scale`.
List<double> _chw(
  img.Image image, {
  required double scale,
  required double shift,
}) {
  final plane = image.width * image.height;
  final data = List<double>.filled(3 * plane, 0);
  var offset = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final red = (pixel.r.toDouble() - shift) * scale;
      final green = (pixel.g.toDouble() - shift) * scale;
      final blue = (pixel.b.toDouble() - shift) * scale;
      data[offset] = blue;
      data[plane + offset] = green;
      data[2 * plane + offset] = red;
      offset++;
    }
  }
  return data;
}

List<double> _flat(List<dynamic> values) {
  final out = <double>[];
  void walk(dynamic node) {
    if (node is List) {
      for (final item in node) {
        walk(item);
      }
    } else if (node is num) {
      out.add(node.toDouble());
    }
  }

  walk(values);
  return out;
}

/// Exposed for tests that build a synthetic prior response.
double yunetScore(double clsLogit, double objLogit) {
  double sigmoid(double value) {
    if (value > 20) return 1;
    if (value < -20) return 0;
    return 1 / (1 + math.exp(-value));
  }

  return math.sqrt(sigmoid(clsLogit) * sigmoid(objLogit));
}
