import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' hide ModelFile;
import 'package:flutter_edge_ai_llama/flutter_edge_ai_llama.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/photo_library.dart';
import '../index/cjk_tokenizer.dart';
import '../index/photo_database.dart';
import '../index/rrf.dart';
import '../model/photo_record.dart';
import '../models/model_catalog.dart';
import '../models/model_store.dart';
import '../ocr/ppocr_v6.dart';
import 'on_device_models.dart';

enum IndexStage { idle, readingText, embedding, naming }

/// A ranked photo from keyword search, visual search, or both.
class SearchHit {
  const SearchHit({
    required this.photoId,
    required this.score,
    this.snippet,
    this.label,
  });

  final String photoId;
  final double score;
  final String? snippet;
  final String? label;
}

/// Downloads models, indexes photos, and searches them. The photo grid does
/// not wait on this object.
class AlbumIndex extends ChangeNotifier {
  AlbumIndex({
    required this.library,
    required this.store,
    required this._index,
    PpOcrV6? ocr,
    GemmaEmbedder? embedder,
    QwenVlNamer? namer,
    this.startupError,
  }) : _ocr = ocr ?? PpOcrV6(),
       _embedder = embedder ?? GemmaEmbedder(),
       _namer = namer ?? QwenVlNamer();

  final PhotoLibrary library;
  final ModelStore store;
  final String? startupError;
  final SqlitePhotoIndex _index;
  final PpOcrV6 _ocr;
  final GemmaEmbedder _embedder;
  final QwenVlNamer _namer;

  List<PhotoRecord> _photos = const [];
  Future<void> _chain = Future<void>.value();
  Future<void>? _job;
  var _paused = false;
  var _closed = false;

  IndexStage stage = IndexStage.idle;
  int done = 0;
  int total = 0;
  bool running = false;
  String? message;
  String? activeDownloadId;
  int downloadReceived = 0;
  int? downloadTotal;
  Map<String, String> labels = const {};

  bool get paused => _paused;
  bool get searchModelsReady => store.searchModelsReady;
  bool get namingModelsReady => store.namingModelsReady;
  bool get hasIndexedPhotos => _index.searchableCount > 0;

  static Future<AlbumIndex?> open(PhotoLibrary library) async {
    try {
      final support = await getApplicationSupportDirectory();
      final models = Directory(p.join(support.path, 'models'));
      await models.create(recursive: true);
      final store = ModelStore(models);
      String? startupError;
      SqlitePhotoIndex? index;
      try {
        index = SqlitePhotoIndex.openFile(p.join(support.path, 'albumseek.db'));
      } catch (error) {
        startupError = 'The search index could not be opened.';
        debugPrint('Albumseek index open failed: $error');
      }
      if (index == null) {
        return null;
      }
      try {
        await FlutterEdgeAi.initialize(
          embeddingBackends: const [LiteRtEmbeddingBackend()],
          inferenceEngines: [
            LlamaEngineProvider(
              projectorResolver: (spec, config) async {
                final projector = store.fileFor(modelFileById('qwen-mmproj'));
                if (store.isReady(modelFileById('qwen-mmproj'))) {
                  return projector.path;
                }
                return null;
              },
            ),
          ],
        );
      } catch (error) {
        startupError = 'On-device runtimes did not start.';
        debugPrint('Albumseek runtime init failed: $error');
      }
      final album = AlbumIndex(
        library: library,
        store: store,
        index: index,
        startupError: startupError,
      );
      album.labels = index.labelsById();
      return album;
    } catch (error) {
      debugPrint('Albumseek model store failed: $error');
      return null;
    }
  }

  void noteLibrary(List<PhotoRecord> photos) {
    _photos = photos;
    _refreshCounts();
    notifyListeners();
    if (!_paused && store.searchModelsReady) {
      unawaited(start());
    }
  }

  void pause() {
    _paused = true;
    notifyListeners();
  }

  Future<void> start() {
    _paused = false;
    _job ??= _run().whenComplete(() {
      _job = null;
    });
    return _job!;
  }

  Future<void> download(ModelFile spec) async {
    activeDownloadId = spec.id;
    downloadReceived = 0;
    downloadTotal = null;
    message = null;
    notifyListeners();
    try {
      await store.download(
        spec,
        onProgress: (progress) {
          downloadReceived = progress.received;
          downloadTotal = progress.total;
          notifyListeners();
        },
      );
      if (store.searchModelsReady && _photos.isNotEmpty) {
        unawaited(start());
      }
    } on ModelStoreException catch (error) {
      message = error.message;
    } finally {
      activeDownloadId = null;
      notifyListeners();
    }
  }

  Future<void> importFile(ModelFile spec, String path) async {
    try {
      await store.importFile(spec, path);
      message = null;
      if (store.searchModelsReady && _photos.isNotEmpty) {
        unawaited(start());
      }
    } on ModelStoreException catch (error) {
      message = error.message;
    }
    notifyListeners();
  }

  Future<List<SearchHit>> search(String query) {
    return _locked(() async {
      final match = cjkMatchQuery(query);
      final keyword = match == null
          ? const <String>[]
          : await _index.keywordSearch(match);
      var visual = const <String>[];
      if (query.trim().isNotEmpty && store.isReady(modelFileById('eg2'))) {
        try {
          await _ocr.close();
          await _embedder.open(store.fileFor(modelFileById('eg2')).path);
          final vector = await _embedder.embedQuery(query.trim());
          visual = await _index.vectorSearch(vector);
        } catch (error) {
          debugPrint('Albumseek query embedding failed: $error');
        }
      }
      final fused = reciprocalRankFusion([keyword, visual]);
      return [
        for (final rank in fused)
          SearchHit(
            photoId: rank.id,
            score: rank.score,
            snippet: _snippet(_index.textFor(rank.id)),
            label: _index.labelFor(rank.id),
          ),
      ];
    });
  }

  Future<List<SearchHit>> similar(String photoId) {
    return _locked(() async {
      final vector = _index.embeddingFor(photoId);
      if (vector == null) {
        return const <SearchHit>[];
      }
      final ids = await _index.vectorSearch(vector, limit: 12);
      return [
        for (final id in ids)
          if (id != photoId)
            SearchHit(
              photoId: id,
              score: 0,
              label: _index.labelFor(id),
              snippet: _snippet(_index.textFor(id)),
            ),
      ];
    });
  }

  String? labelFor(String photoId) => labels[photoId];

  Future<void> _run() async {
    running = true;
    notifyListeners();
    while (!_closed && !_paused) {
      final ocrPhoto = _next(
        _index.completedOcr(),
        store.isReady(modelFileById('ocr-det')),
      );
      if (ocrPhoto != null) {
        await _locked(() => _readText(ocrPhoto));
        continue;
      }
      final embedPhoto = _next(
        _index.completedEmbed(),
        store.isReady(modelFileById('eg2')),
      );
      if (embedPhoto != null) {
        await _locked(() => _embed(embedPhoto));
        continue;
      }
      final namePhoto = _next(
        _index.completedNames(),
        store.namingModelsReady,
      );
      if (namePhoto != null) {
        await _locked(() => _name(namePhoto));
        continue;
      }
      break;
    }
    running = false;
    stage = IndexStage.idle;
    _refreshCounts();
    notifyListeners();
  }

  PhotoRecord? _next(Set<String> doneIds, bool enabled) {
    if (!enabled) {
      return null;
    }
    for (final photo in _photos) {
      if (!doneIds.contains(photo.id)) {
        return photo;
      }
    }
    return null;
  }

  Future<void> _readText(PhotoRecord photo) async {
    stage = IndexStage.readingText;
    _refreshCounts();
    notifyListeners();
    try {
      await _embedder.close();
      await _ensureOcr();
      final bytes = await library.imageBytes(photo);
      final text = bytes == null ? '' : await _ocr.recognize(bytes);
      await _index.upsertText(
        photoId: photo.id,
        text: text.trim(),
        ftsBody: cjkIndexText(text),
      );
    } catch (error) {
      debugPrint('Albumseek OCR failed for ${photo.id}: $error');
      _index.markOcrFailed(photo.id, 'This photo could not be read.');
    }
    _refreshCounts();
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _embed(PhotoRecord photo) async {
    stage = IndexStage.embedding;
    notifyListeners();
    try {
      await _ocr.close();
      final bytes = await library.imageBytes(photo);
      if (bytes == null) {
        _index.markEmbedFailed(photo.id, 'No image bytes.');
        return;
      }
      final png = await uprightPng(bytes);
      await _embedder.open(store.fileFor(modelFileById('eg2')).path);
      final vector = await _embedder.embedImage(png);
      await _index.upsertEmbedding(photoId: photo.id, embedding: vector);
    } catch (error) {
      debugPrint('Albumseek embed failed for ${photo.id}: $error');
      _index.markEmbedFailed(photo.id, 'This photo could not be embedded.');
    }
    _refreshCounts();
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _name(PhotoRecord photo) async {
    stage = IndexStage.naming;
    notifyListeners();
    try {
      await _ocr.close();
      await _embedder.close();
      final bytes = await library.imageBytes(photo, maxSide: 768);
      if (bytes == null) {
        _index.markNameFailed(photo.id, 'No image bytes.');
        return;
      }
      final png = await uprightPng(bytes, maxSide: 768);
      await _namer.install(store.fileFor(modelFileById('qwen-vl')).path);
      final label = await _namer.label(png);
      if (label.isEmpty) {
        _index.markNameFailed(photo.id, 'No label.');
      } else {
        _index.saveLabel(photo.id, label);
        labels = _index.labelsById();
      }
    } catch (error) {
      debugPrint('Albumseek naming failed for ${photo.id}: $error');
      _index.markNameFailed(photo.id, 'This photo was not labeled.');
    }
    _refreshCounts();
    notifyListeners();
  }

  Future<void> _ensureOcr() async {
    if (_ocr.isOpen) {
      return;
    }
    final dict = await File(
      store.fileFor(modelFileById('ocr-dict')).path,
    ).readAsString();
    await _ocr.open(
      detectionPath: store.fileFor(modelFileById('ocr-det')).path,
      recognitionPath: store.fileFor(modelFileById('ocr-rec')).path,
      dictionary: dict,
    );
  }

  void _refreshCounts() {
    final ocrDone = _index.completedOcr();
    final embedded = _index.completedEmbed();
    total = _photos.length;
    done = _photos
        .where((photo) => ocrDone.contains(photo.id) && embedded.contains(photo.id))
        .length;
  }

  Future<T> _locked<T>(Future<T> Function() body) {
    final run = _chain.catchError((Object _) {}).then((_) => body());
    _chain = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  void dispose() {
    _closed = true;
    _paused = true;
    unawaited(_ocr.close());
    unawaited(_embedder.close());
    unawaited(_index.close());
    super.dispose();
  }
}

String? _snippet(String? text) {
  if (text == null) {
    return null;
  }
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.isEmpty) {
    return null;
  }
  if (flat.length <= 80) {
    return flat;
  }
  return '${flat.substring(0, 80)}…';
}
