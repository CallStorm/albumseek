import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../engine/local_index.dart';

/// Official sqlite-vec 0.1.9 Android loadable, packaged as libsqlite_vec.so.
///
/// The pub.dev sqlite_vec plugin's 0.1.7 alpha does not ship sqlite-vec.c, so
/// the app vendors the release builds from asg017/sqlite-vec instead.
DynamicLibrary openSqliteVec() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libsqlite_vec.so');
  }
  throw UnsupportedError('sqlite-vec is packaged for Android.');
}

/// sqlite-vec must be registered before the first database opens.
var _vecReady = false;

void ensureSqliteVec() {
  if (_vecReady) {
    return;
  }
  sqlite3.ensureExtensionLoaded(
    SqliteExtension.inLibrary(openSqliteVec(), 'sqlite3_vec_init'),
  );
  _vecReady = true;
}

/// FTS5 keyword index and a 768-d sqlite-vec table, keyed by photo id.
class SqlitePhotoIndex implements LocalIndex {
  SqlitePhotoIndex(this._db);

  final Database _db;
  static const int dimension = 768;

  static SqlitePhotoIndex openFile(String path) {
    ensureSqliteVec();
    final db = sqlite3.open(path);
    final index = SqlitePhotoIndex(db);
    index._migrate();
    return index;
  }

  @override
  Future<void> open() async {}

  void _migrate() {
    _db.execute('PRAGMA journal_mode = WAL;');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS photos (
        id INTEGER PRIMARY KEY,
        photo_id TEXT NOT NULL UNIQUE,
        ocr_text TEXT,
        label TEXT,
        ocr_done INTEGER NOT NULL DEFAULT 0,
        embedded INTEGER NOT NULL DEFAULT 0,
        named INTEGER NOT NULL DEFAULT 0,
        error TEXT
      )
    ''');
    _db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS photo_fts USING fts5(
        photo_id UNINDEXED,
        body,
        tokenize = "unicode61 remove_diacritics 0"
      )
    ''');
    _db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS photo_vec USING vec0(
        embedding float[$dimension] distance_metric=cosine
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS faces (
        id INTEGER PRIMARY KEY,
        photo_id TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        w REAL NOT NULL,
        h REAL NOT NULL,
        embedding TEXT NOT NULL,
        person_id INTEGER NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        photo_id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        fields_json TEXT NOT NULL
      )
    ''');
    _try('ALTER TABLE photos ADD COLUMN faces_done INTEGER NOT NULL DEFAULT 0');
    _try('ALTER TABLE photos ADD COLUMN doc_done INTEGER NOT NULL DEFAULT 0');
  }

  void _try(String sql) {
    try {
      _db.execute(sql);
    } catch (_) {
      // The column already exists on databases created with this schema.
    }
  }

  int? idFor(String photoId) {
    final rows = _db.select('SELECT id FROM photos WHERE photo_id = ?', [
      photoId,
    ]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as int;
  }

  int ensureRow(String photoId) {
    final existing = idFor(photoId);
    if (existing != null) {
      return existing;
    }
    _db.execute('INSERT INTO photos(photo_id) VALUES (?)', [photoId]);
    return _db.lastInsertRowId;
  }

  int get searchableCount {
    final rows = _db.select(
      'SELECT COUNT(*) AS n FROM photos WHERE ocr_done = 1 OR embedded = 1',
    );
    return rows.first['n'] as int;
  }

  Set<String> completedOcr() => _ids('ocr_done = 1');

  Set<String> completedEmbed() => _ids('embedded = 1');

  Set<String> completedNames() => _ids('named = 1');

  Set<String> _ids(String where) {
    final rows = _db.select('SELECT photo_id FROM photos WHERE $where');
    return {for (final row in rows) row['photo_id'] as String};
  }

  String? labelFor(String photoId) {
    final rows = _db.select('SELECT label FROM photos WHERE photo_id = ?', [
      photoId,
    ]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['label'] as String?;
  }

  String? textFor(String photoId) {
    final rows = _db.select('SELECT ocr_text FROM photos WHERE photo_id = ?', [
      photoId,
    ]);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['ocr_text'] as String?;
  }

  Map<String, String> labelsById() {
    final rows = _db.select(
      "SELECT photo_id, label FROM photos WHERE label IS NOT NULL AND label != ''",
    );
    return {
      for (final row in rows) row['photo_id'] as String: row['label'] as String,
    };
  }

  @override
  Future<void> upsertText({
    required String photoId,
    required String text,
    String? ftsBody,
    String? label,
  }) async {
    final id = ensureRow(photoId);
    _db.execute(
      '''
      UPDATE photos
      SET ocr_text = ?, ocr_done = 1, error = NULL
      WHERE id = ?
      ''',
      [text, id],
    );
    if (label != null) {
      _db.execute('UPDATE photos SET label = ?, named = 1 WHERE id = ?', [
        label,
        id,
      ]);
    }
    _db.execute('DELETE FROM photo_fts WHERE rowid = ?', [id]);
    _db.execute(
      'INSERT INTO photo_fts(rowid, photo_id, body) VALUES (?, ?, ?)',
      [id, photoId, ftsBody ?? text],
    );
  }

  void markOcrFailed(String photoId, String message) {
    final id = ensureRow(photoId);
    _db.execute('UPDATE photos SET ocr_done = 1, error = ? WHERE id = ?', [
      message,
      id,
    ]);
  }

  @override
  Future<void> upsertEmbedding({
    required String photoId,
    required List<double> embedding,
  }) async {
    if (embedding.length != dimension) {
      throw ArgumentError(
        'Expected $dimension dimensions, got ${embedding.length}.',
      );
    }
    final id = ensureRow(photoId);
    _db.execute('DELETE FROM photo_vec WHERE rowid = ?', [id]);
    _db.execute(
      'INSERT INTO photo_vec(rowid, embedding) VALUES (?, vec_f32(?))',
      [id, jsonEncode(embedding)],
    );
    _db.execute('UPDATE photos SET embedded = 1 WHERE id = ?', [id]);
  }

  void markEmbedFailed(String photoId, String message) {
    final id = ensureRow(photoId);
    _db.execute('UPDATE photos SET embedded = 1, error = ? WHERE id = ?', [
      message,
      id,
    ]);
  }

  void saveLabel(String photoId, String label) {
    final id = ensureRow(photoId);
    _db.execute(
      'UPDATE photos SET label = ?, named = 1, error = NULL WHERE id = ?',
      [label, id],
    );
  }

  void markNameFailed(String photoId, String message) {
    final id = ensureRow(photoId);
    _db.execute('UPDATE photos SET named = 1, error = ? WHERE id = ?', [
      message,
      id,
    ]);
  }

  @override
  Future<List<String>> keywordSearch(String ftsMatch, {int limit = 30}) async {
    if (ftsMatch.trim().isEmpty) {
      return const [];
    }
    final rows = _db.select(
      '''
      SELECT photo_id FROM photo_fts
      WHERE photo_fts MATCH ?
      LIMIT ?
      ''',
      [ftsMatch, limit],
    );
    return [for (final row in rows) row['photo_id'] as String];
  }

  @override
  Future<List<String>> vectorSearch(
    List<double> embedding, {
    int limit = 30,
  }) async {
    if (embedding.length != dimension) {
      return const [];
    }
    final rows = _db.select(
      '''
      SELECT rowid
      FROM photo_vec
      WHERE embedding MATCH vec_f32(?) AND k = ?
      ORDER BY distance
      ''',
      [jsonEncode(embedding), limit],
    );
    final ids = <String>[];
    for (final row in rows) {
      final id = row['rowid'] as int;
      final found = _db.select('SELECT photo_id FROM photos WHERE id = ?', [
        id,
      ]);
      if (found.isNotEmpty) {
        ids.add(found.first['photo_id'] as String);
      }
    }
    return ids;
  }

  List<double>? embeddingFor(String photoId) {
    final id = idFor(photoId);
    if (id == null) {
      return null;
    }
    final rows = _db.select(
      'SELECT vec_to_json(embedding) AS json FROM photo_vec WHERE rowid = ?',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(rows.first['json'] as String);
    if (decoded is! List) {
      return null;
    }
    return [for (final value in decoded) (value as num).toDouble()];
  }

  bool facesDone(String photoId) {
    final rows = _db.select(
      'SELECT faces_done FROM photos WHERE photo_id = ?',
      [photoId],
    );
    if (rows.isEmpty) {
      return false;
    }
    return (rows.first['faces_done'] as int? ?? 0) == 1;
  }

  bool docDone(String photoId) {
    final rows = _db.select('SELECT doc_done FROM photos WHERE photo_id = ?', [
      photoId,
    ]);
    if (rows.isEmpty) {
      return false;
    }
    return (rows.first['doc_done'] as int? ?? 0) == 1;
  }

  Set<String> completedFaces() => _ids('faces_done = 1');

  Set<String> completedDocs() => _ids('doc_done = 1');

  void insertFace({
    required String photoId,
    required double x,
    required double y,
    required double width,
    required double height,
    required List<double> embedding,
    required int personId,
  }) {
    ensureRow(photoId);
    _db.execute(
      '''
      INSERT INTO faces(photo_id, x, y, w, h, embedding, person_id)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [photoId, x, y, width, height, jsonEncode(embedding), personId],
    );
  }

  void markFacesDone(String photoId) {
    ensureRow(photoId);
    _db.execute('UPDATE photos SET faces_done = 1 WHERE photo_id = ?', [
      photoId,
    ]);
  }

  void markDocDone(String photoId) {
    ensureRow(photoId);
    _db.execute('UPDATE photos SET doc_done = 1 WHERE photo_id = ?', [photoId]);
  }

  List<({int personId, List<double> embedding})> faceSamples() {
    final rows = _db.select('SELECT person_id, embedding FROM faces');
    final samples = <({int personId, List<double> embedding})>[];
    for (final row in rows) {
      final decoded = jsonDecode(row['embedding'] as String);
      if (decoded is! List) {
        continue;
      }
      samples.add((
        personId: row['person_id'] as int,
        embedding: [for (final value in decoded) (value as num).toDouble()],
      ));
    }
    return samples;
  }

  List<({int personId, String photoId, int count})> peopleRows() {
    final rows = _db.select('''
      SELECT person_id, photo_id, COUNT(*) AS n
      FROM faces
      GROUP BY person_id, photo_id
      ORDER BY person_id, photo_id
    ''');
    return [
      for (final row in rows)
        (
          personId: row['person_id'] as int,
          photoId: row['photo_id'] as String,
          count: row['n'] as int,
        ),
    ];
  }

  List<List<String>> peopleClusters() {
    final grouped = <int, List<String>>{};
    for (final row in peopleRows()) {
      grouped.putIfAbsent(row.personId, () => <String>[]).add(row.photoId);
    }
    return grouped.values.toList();
  }

  void saveDocument({
    required String photoId,
    required String kind,
    required String fieldsJson,
    required String ftsBody,
  }) {
    final id = ensureRow(photoId);
    _db.execute(
      '''
      INSERT INTO documents(photo_id, kind, fields_json)
      VALUES (?, ?, ?)
      ON CONFLICT(photo_id) DO UPDATE SET
        kind = excluded.kind,
        fields_json = excluded.fields_json
      ''',
      [photoId, kind, fieldsJson],
    );
    _db.execute('DELETE FROM photo_fts WHERE rowid = ?', [id]);
    _db.execute(
      'INSERT INTO photo_fts(rowid, photo_id, body) VALUES (?, ?, ?)',
      [id, photoId, ftsBody],
    );
    _db.execute('UPDATE photos SET doc_done = 1 WHERE photo_id = ?', [photoId]);
  }

  ({String kind, String fieldsJson})? documentFor(String photoId) {
    final rows = _db.select(
      'SELECT kind, fields_json FROM documents WHERE photo_id = ?',
      [photoId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return (
      kind: rows.first['kind'] as String,
      fieldsJson: rows.first['fields_json'] as String,
    );
  }

  @override
  Future<void> close() async {
    _db.close();
  }
}
