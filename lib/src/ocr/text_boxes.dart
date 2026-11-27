/// One text region in probability-map pixels.
class TextBox {
  const TextBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.score,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
  final double score;

  int get width => right - left;
  int get height => bottom - top;
}

/// Connected components on a text-detection map.
///
/// This follows RapidOCR's thresholds (0.3 / 0.5) without OpenCV. Boxes are
/// axis-aligned and padded, which is enough for album photos that are close
/// to upright.
List<TextBox> boxesFromMap(
  List<double> probabilities, {
  required int width,
  required int height,
  double threshold = 0.3,
  double boxThreshold = 0.5,
  int maxBoxes = 40,
}) {
  if (width <= 0 || height <= 0 || probabilities.length < width * height) {
    return const [];
  }
  final mask = List<bool>.generate(width * height, (index) {
    return probabilities[index] > threshold;
  }, growable: false);
  _dilate(mask, width, height);

  final seen = List<bool>.filled(width * height, false);
  final boxes = <TextBox>[];
  final stack = <int>[];
  for (var start = 0; start < mask.length; start++) {
    if (!mask[start] || seen[start]) {
      continue;
    }
    stack.add(start);
    seen[start] = true;
    var count = 0;
    var minX = width;
    var minY = height;
    var maxX = 0;
    var maxY = 0;
    var scoreSum = 0.0;
    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      final x = index % width;
      final y = index ~/ width;
      count++;
      scoreSum += probabilities[index];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      for (final next in _neighbors(x, y, width, height)) {
        if (!seen[next] && mask[next]) {
          seen[next] = true;
          stack.add(next);
        }
      }
    }
    final boxWidth = maxX - minX + 1;
    final boxHeight = maxY - minY + 1;
    if (count < 9 || boxWidth < 3 || boxHeight < 3) {
      continue;
    }
    final score = scoreSum / count;
    if (score < boxThreshold) {
      continue;
    }
    final padX = (boxWidth * 0.08).round() + 1;
    final padY = (boxHeight * 0.18).round() + 1;
    boxes.add(
      TextBox(
        left: (minX - padX).clamp(0, width - 1),
        top: (minY - padY).clamp(0, height - 1),
        right: (maxX + padX + 1).clamp(1, width),
        bottom: (maxY + padY + 1).clamp(1, height),
        score: score,
      ),
    );
    if (boxes.length >= maxBoxes * 3) {
      break;
    }
  }
  boxes.sort((a, b) => b.score.compareTo(a.score));
  final kept = boxes.length <= maxBoxes ? boxes : boxes.sublist(0, maxBoxes);
  kept.sort((a, b) {
    final band = (a.height + b.height) ~/ 2;
    if ((a.top - b.top).abs() > band) {
      return a.top.compareTo(b.top);
    }
    return a.left.compareTo(b.left);
  });
  return kept;
}

void _dilate(List<bool> mask, int width, int height) {
  final source = List<bool>.from(mask);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final index = y * width + x;
      if (source[index]) {
        continue;
      }
      var on = false;
      for (var dy = -1; dy <= 1 && !on; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
            continue;
          }
          if (source[ny * width + nx]) {
            on = true;
            break;
          }
        }
      }
      if (on) {
        mask[index] = true;
      }
    }
  }
}

Iterable<int> _neighbors(int x, int y, int width, int height) sync* {
  if (x > 0) yield y * width + (x - 1);
  if (x + 1 < width) yield y * width + (x + 1);
  if (y > 0) yield (y - 1) * width + x;
  if (y + 1 < height) yield (y + 1) * width + x;
}
