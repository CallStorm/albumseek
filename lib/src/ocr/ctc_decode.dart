/// Greedy CTC decode for PP-OCRv6.
///
/// Index 0 is blank. Indexes `1..dict.length` are the dictionary in order.
/// One extra class, when the model has it, is a space.
String ctcDecode(List<int> ids, List<String> dictionary) {
  final buffer = StringBuffer();
  var previous = -1;
  for (final id in ids) {
    if (id != 0 && id != previous) {
      if (id >= 1 && id <= dictionary.length) {
        buffer.write(dictionary[id - 1]);
      } else if (id == dictionary.length + 1) {
        buffer.write(' ');
      }
    }
    previous = id;
  }
  return buffer.toString();
}

/// Argmax class id for each timestep of a `[time, classes]` row-major matrix.
List<int> ctcArgmax(List<double> scores, int classes) {
  if (classes <= 0) {
    return const [];
  }
  final steps = scores.length ~/ classes;
  final ids = <int>[];
  for (var step = 0; step < steps; step++) {
    var best = 0;
    var bestScore = scores[step * classes];
    for (var cls = 1; cls < classes; cls++) {
      final score = scores[step * classes + cls];
      if (score > bestScore) {
        bestScore = score;
        best = cls;
      }
    }
    ids.add(best);
  }
  return ids;
}
