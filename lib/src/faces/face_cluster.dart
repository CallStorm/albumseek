import 'dart:math' as math;

/// One stored face used to grow people clusters.
class FaceSample {
  const FaceSample({required this.personId, required this.embedding});

  final int personId;
  final List<double> embedding;
}

/// Running sum of embeddings for one person.
class PersonDraft {
  PersonDraft({required this.id, required this.sum, required this.count});

  final int id;
  final List<double> sum;
  int count;

  List<double> get centroid => normalize(sum);
}

/// Assigns a new face to an existing person or starts a new one.
///
/// [threshold] is cosine similarity of L2-normalized embeddings. Faces already
/// stored keep their person id; only new embeddings are assigned.
class FaceRoster {
  FaceRoster({this.threshold = 0.4, List<PersonDraft>? people})
    : people = people ?? <PersonDraft>[];

  final double threshold;
  final List<PersonDraft> people;
  var _nextId = 1;

  static FaceRoster fromSamples(
    List<FaceSample> samples, {
    double threshold = 0.4,
  }) {
    final grouped = <int, PersonDraft>{};
    for (final sample in samples) {
      final draft = grouped.putIfAbsent(
        sample.personId,
        () => PersonDraft(
          id: sample.personId,
          sum: List<double>.filled(sample.embedding.length, 0),
          count: 0,
        ),
      );
      final vector = normalize(sample.embedding);
      for (var i = 0; i < vector.length; i++) {
        draft.sum[i] += vector[i];
      }
      draft.count += 1;
    }
    final roster = FaceRoster(
      threshold: threshold,
      people: grouped.values.toList(),
    );
    final maxId = grouped.keys.fold<int>(0, math.max);
    roster._nextId = maxId + 1;
    return roster;
  }

  /// Returns the person id for [embedding].
  int add(List<double> embedding) {
    final vector = normalize(embedding);
    var bestId = -1;
    var best = threshold;
    for (final person in people) {
      final score = dot(vector, person.centroid);
      if (score >= best) {
        best = score;
        bestId = person.id;
      }
    }
    if (bestId == -1) {
      final id = _nextId++;
      people.add(PersonDraft(id: id, sum: List<double>.of(vector), count: 1));
      return id;
    }
    final person = people.firstWhere((item) => item.id == bestId);
    for (var i = 0; i < vector.length; i++) {
      person.sum[i] += vector[i];
    }
    person.count += 1;
    return bestId;
  }
}

List<double> normalize(List<double> values) {
  var sum = 0.0;
  for (final value in values) {
    sum += value * value;
  }
  final norm = math.sqrt(sum);
  if (norm == 0) {
    return List<double>.from(values);
  }
  return [for (final value in values) value / norm];
}

double dot(List<double> a, List<double> b) {
  final n = math.min(a.length, b.length);
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}
