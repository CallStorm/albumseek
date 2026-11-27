import 'dart:math' as math;

/// A face in the network's input pixel space.
class YuNetFace {
  const YuNetFace({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double score;
}

/// Decode OpenCV YuNet 2023mar heads.
///
/// Input is 640×640. Each stride has classification, objectness, box, and
/// keypoint tensors laid out row-major over the feature map. Scores are
/// `sqrt(sigmoid(cls) * sigmoid(obj))`, matching OpenCV's FaceDetectorYN.
List<YuNetFace> decodeYuNet({
  required List<double> cls8,
  required List<double> obj8,
  required List<double> bbox8,
  required List<double> cls16,
  required List<double> obj16,
  required List<double> bbox16,
  required List<double> cls32,
  required List<double> obj32,
  required List<double> bbox32,
  int inputSize = 640,
  double scoreThreshold = 0.6,
  double nmsThreshold = 0.3,
  int maxFaces = 20,
}) {
  final faces = <YuNetFace>[
    ..._level(cls8, obj8, bbox8, 8, inputSize, scoreThreshold),
    ..._level(cls16, obj16, bbox16, 16, inputSize, scoreThreshold),
    ..._level(cls32, obj32, bbox32, 32, inputSize, scoreThreshold),
  ];
  faces.sort((a, b) => b.score.compareTo(a.score));
  final kept = <YuNetFace>[];
  for (final face in faces) {
    var overlap = false;
    for (final other in kept) {
      if (_iou(face, other) >= nmsThreshold) {
        overlap = true;
        break;
      }
    }
    if (!overlap) {
      kept.add(face);
    }
    if (kept.length >= maxFaces) {
      break;
    }
  }
  return kept;
}

List<YuNetFace> _level(
  List<double> cls,
  List<double> obj,
  List<double> bbox,
  int stride,
  int inputSize,
  double scoreThreshold,
) {
  final cells = inputSize ~/ stride;
  final count = math.min(cls.length, math.min(obj.length, bbox.length ~/ 4));
  final faces = <YuNetFace>[];
  for (var index = 0; index < count && index < cells * cells; index++) {
    final score = math.sqrt(_sigmoid(cls[index]) * _sigmoid(obj[index]));
    if (score < scoreThreshold) {
      continue;
    }
    final col = index % cells;
    final row = index ~/ cells;
    final cx = (col + 0.5) * stride + bbox[index * 4] * stride;
    final cy = (row + 0.5) * stride + bbox[index * 4 + 1] * stride;
    final width = math.exp(bbox[index * 4 + 2]) * stride;
    final height = math.exp(bbox[index * 4 + 3]) * stride;
    if (width < 8 || height < 8) {
      continue;
    }
    faces.add(
      YuNetFace(
        x: cx - width / 2,
        y: cy - height / 2,
        width: width,
        height: height,
        score: score,
      ),
    );
  }
  return faces;
}

double _sigmoid(double value) {
  if (value > 20) {
    return 1;
  }
  if (value < -20) {
    return 0;
  }
  return 1 / (1 + math.exp(-value));
}

double _iou(YuNetFace a, YuNetFace b) {
  final left = math.max(a.x, b.x);
  final top = math.max(a.y, b.y);
  final right = math.min(a.x + a.width, b.x + b.width);
  final bottom = math.min(a.y + a.height, b.y + b.height);
  final w = right - left;
  final h = bottom - top;
  if (w <= 0 || h <= 0) {
    return 0;
  }
  final inter = w * h;
  final union = a.width * a.height + b.width * b.height - inter;
  if (union <= 0) {
    return 0;
  }
  return inter / union;
}
