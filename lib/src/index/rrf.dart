/// One id after reciprocal rank fusion.
class FusedRank {
  const FusedRank(this.id, this.score);

  final String id;
  final double score;
}

/// Reciprocal rank fusion. [k] is the usual constant 60.
///
/// Lists that are empty are ignored. Rank is 1-based from the head of each
/// list. A higher score is a better match.
List<FusedRank> reciprocalRankFusion(
  List<List<String>> rankings, {
  int k = 60,
}) {
  final scores = <String, double>{};
  for (final ranking in rankings) {
    for (var index = 0; index < ranking.length; index++) {
      final id = ranking[index];
      scores[id] = (scores[id] ?? 0) + 1 / (k + index + 1);
    }
  }
  final fused = [
    for (final entry in scores.entries) FusedRank(entry.key, entry.value),
  ]..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      return a.id.compareTo(b.id);
    });
  return fused;
}
