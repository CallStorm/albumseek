/// On-device search index boundary.
///
/// Later builds will store image and text vectors in sqlite-vec and keywords
/// in SQLite FTS5 with a Chinese tokenizer. This build keeps file names and
/// dates in memory and does not open a database.
abstract interface class LocalIndex {
  Future<void> open();

  Future<void> upsertPhoto(String photoId);

  Future<void> close();
}
