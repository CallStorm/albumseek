/// On-device search index.
///
/// Vectors live in sqlite-vec. OCR text lives in FTS5 after CJK bigram
/// tokenization, not SQLite's default English tokenizer.
abstract interface class LocalIndex {
  Future<void> open();

  Future<void> upsertText({
    required String photoId,
    required String text,
    String? ftsBody,
    String? label,
  });

  Future<void> upsertEmbedding({
    required String photoId,
    required List<double> embedding,
  });

  Future<List<String>> keywordSearch(String ftsMatch, {int limit = 30});

  Future<List<String>> vectorSearch(
    List<double> embedding, {
    int limit = 30,
  });

  Future<void> close();
}
