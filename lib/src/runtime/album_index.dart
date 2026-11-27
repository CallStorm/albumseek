import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' hide ModelFile;
import 'package:flutter_edge_ai_llama/flutter_edge_ai_llama.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/photo_library.dart';
import '../docs/document_fields.dart';
import '../engine/face_index.dart';
import '../faces/face_pipeline.dart';
import '../index/cjk_tokenizer.dart';
import '../index/photo_database.dart';
import '../index/rrf.dart';
import '../model/photo_record.dart';
import '../models/model_catalog.dart';
import '../models/model_store.dart';
import '../ocr/ppocr_v6.dart';
import 'index_schedule.dart';
import 'on_device_models.dart';

export 'index_schedule.dart' show IndexStage, indexStatusText, stageLabel;

/// The llama.cpp projector for whichever vision model is about to load.
class ProjectorSlot {
  String? path;
}

/// A ranked photo from keyword search, visual search, or both.
class PersonSummary {
  const PersonSummary({required this.id, required this.photoIds});

  final int id;
  final List<String> photoIds;

  String get title => '人物 $id';
}

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
    FacePipeline? faces,
    SqliteFaceIndex? faceIndex,
    ProjectorSlot? projector,
    this.startupError,
  }) : _ocr = ocr ?? PpOcrV6(),
       _embedder = embedder ?? GemmaEmbedder(),
       _namer = namer ?? QwenVlNamer(),
       _faces = faces ?? FacePipeline(),
       _faceIndex = faceIndex ?? SqliteFaceIndex(_index),
       _projector = projector ?? ProjectorSlot();

  final PhotoLibrary library;
  final ModelStore store;
  final String? startupError;
  final SqlitePhotoIndex _index;
  final PpOcrV6 _ocr;
  final GemmaEmbedder _embedder;
  final QwenVlNamer _namer;
  final FacePipeline _faces;
  final SqliteFaceIndex _faceIndex;
  final ProjectorSlot _projector;

  List<PhotoRecord> _photos = const [];
  Future<void> _chain = Future<void>.value();
  Future<void>? _job;
  var _paused = false;
  var _closed = false;

  IndexStage stage = IndexStage.idle;
  int done = 0;
  int total = 0;
  bool running = false;
  bool searchReady = false;
  bool namingEnabled = true;
  String? message;
  String? activeDownloadId;
  int downloadReceived = 0;
  int? downloadTotal;
  Map<String, String> labels = const {};

  bool get paused => _paused;
  bool get searchModelsReady => store.searchModelsReady;
  bool get namingModelsReady => store.namingModelsReady;
  bool get faceModelsReady => store.faceModelsReady;
  bool get documentModelsReady => store.documentModelsReady;
  bool get hasIndexedPhotos => _index.searchableCount > 0;

  static Future<AlbumIndex?> open(PhotoLibrary library) async {
    try {
      final support = await getApplicationSupportDirectory();
      final models = Directory(p.join(support.path, 'models'));
      await models.create(recursive: true);
      final store = ModelStore(models);
      String? startupError;
      final projector = ProjectorSlot();
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
              projectorResolver: (spec, config) async => projector.path,
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
        projector: projector,
        startupError: startupError,
      );
      await album._faceIndex.open();
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

  /// Stops automatic Qwen naming for this library until [enableNaming].
  void skipNaming() {
    namingEnabled = false;
    notifyListeners();
  }

  void enableNaming() {
    namingEnabled = true;
    notifyListeners();
    if (_photos.isNotEmpty) {
      unawaited(start());
    }
  }

  String get statusText => indexStatusText(
    modelsReady: searchModelsReady,
    running: running,
    paused: _paused,
    stage: stage,
    done: done,
    total: total,
    searchReady: searchReady,
    namingSkipped: !namingEnabled && store.namingModelsReady,
  );

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
          await _namer.close();
          await _faces.close();
          await _ocr.close();
          await _embedder.open(store.fileFor(modelFileById('eg2')).path);
          final vector = await _embedder.embedQuery(query.trim());
          visual = await _index.vectorSearch(vector);
        } catch (error) {
          debugPrint('Albumseek query embedding failed: $error');
        } finally {
          await _embedder.close();
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
    try {
      await runScheduledPass(
        read: _schedule,
        stopped: () => _paused || _closed,
        publish: _publish,
        loadOcr: _loadOcr,
        ocrPhoto: (id) => _locked(() => _readText(id)),
        unloadOcr: _ocr.close,
        loadEmbed: _loadEmbed,
        embedPhoto: (id) => _locked(() => _embed(id)),
        unloadEmbed: _embedder.close,
        loadFaces: _loadFaces,
        facePhoto: (id) => _locked(() => _detectFaces(id)),
        unloadFaces: _faces.close,
        parseDocument: (id) => _locked(() => _parseDocument(id)),
        loadDocument: _loadDocumentModel,
        visionDocument: (id) => _locked(() => _visionDocument(id)),
        unloadDocument: _namer.close,
        loadNamer: _loadNamer,
        namePhoto: (id) => _locked(() => _name(id)),
        unloadNamer: _namer.close,
      );
    } finally {
      running = false;
      if (!_paused && !_closed) {
        stage = IndexStage.idle;
        _publish(_schedule().snapshot(IndexStage.idle));
      }
      notifyListeners();
    }
  }

  IndexSchedule _schedule() {
    final ocrReady =
        store.isReady(modelFileById('ocr-det')) &&
        store.isReady(modelFileById('ocr-rec')) &&
        store.isReady(modelFileById('ocr-dict'));
    return IndexSchedule(
      photoIds: [for (final photo in _photos) photo.id],
      ocrDone: _index.completedOcr(),
      embedDone: _index.completedEmbed(),
      facesDone: _index.completedFaces(),
      docsDone: _index.completedDocs(),
      namesDone: _index.completedNames(),
      textOf: _index.textFor,
      ocrReady: ocrReady,
      embedReady: store.isReady(modelFileById('eg2')),
      faceModelsReady: store.faceModelsReady,
      documentModelsReady: store.documentModelsReady,
      namingModelsReady: store.namingModelsReady,
      namingEnabled: namingEnabled,
    );
  }

  void _publish(IndexSnapshot snapshot) {
    stage = snapshot.stage;
    done = snapshot.done;
    total = snapshot.total;
    searchReady = snapshot.searchReady;
    notifyListeners();
  }

  PhotoRecord? _photo(String id) {
    for (final photo in _photos) {
      if (photo.id == id) {
        return photo;
      }
    }
    return null;
  }

  Future<void> _loadOcr() async {
    await _namer.close();
    await _embedder.close();
    await _faces.close();
    await _ensureOcr();
  }

  Future<void> _loadEmbed() async {
    await _ocr.close();
    await _namer.close();
    await _faces.close();
    await _embedder.open(store.fileFor(modelFileById('eg2')).path);
  }

  Future<void> _loadFaces() async {
    await _ocr.close();
    await _embedder.close();
    await _namer.close();
    await _faces.openDetector(store.fileFor(modelFileById('yunet')).path);
    await _faces.openEmbedder(store.fileFor(modelFileById('adaface')).path);
  }

  Future<void> _loadDocumentModel() {
    return _loadVision(
      modelId: 'paddleocr-vl',
      projectorId: 'paddleocr-mmproj',
    );
  }

  Future<void> _loadNamer() {
    return _loadVision(modelId: 'qwen-vl', projectorId: 'qwen-mmproj');
  }

  Future<void> _loadVision({
    required String modelId,
    required String projectorId,
  }) async {
    await _ocr.close();
    await _embedder.close();
    await _faces.close();
    _projector.path = store.fileFor(modelFileById(projectorId)).path;
    await _namer.open(store.fileFor(modelFileById(modelId)).path);
  }

  Future<void> _readText(String id) async {
    final photo = _photo(id);
    if (photo == null) {
      _index.markOcrFailed(id, 'This photo is no longer in the library.');
      return;
    }
    try {
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
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _embed(String id) async {
    final photo = _photo(id);
    if (photo == null) {
      _index.markEmbedFailed(id, 'This photo is no longer in the library.');
      return;
    }
    try {
      final bytes = await library.imageBytes(photo);
      if (bytes == null) {
        _index.markEmbedFailed(photo.id, 'No image bytes.');
        return;
      }
      final png = await uprightPng(bytes);
      final vector = await _embedder.embedImage(png);
      await _index.upsertEmbedding(photoId: photo.id, embedding: vector);
    } catch (error) {
      debugPrint('Albumseek embed failed for ${photo.id}: $error');
      _index.markEmbedFailed(photo.id, 'This photo could not be embedded.');
    }
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _detectFaces(String id) async {
    final photo = _photo(id);
    if (photo == null) {
      _index.markFacesDone(id);
      return;
    }
    try {
      if (_index.facesDone(photo.id)) {
        return;
      }
      final bytes = await library.imageBytes(photo, maxSide: 1280);
      if (bytes == null) {
        _index.markFacesDone(photo.id);
        return;
      }
      final found = await _faces.detect(bytes);
      final decoded = img.decodeImage(bytes);
      final source = decoded == null ? null : img.bakeOrientation(decoded);
      final embedded = <LocatedFace>[];
      if (source != null && found.isNotEmpty) {
        for (final face in found) {
          final vector = await _faces.embed(source, face);
          embedded.add(face.withEmbedding(vector));
        }
      }
      await _faceIndex.addPhoto(photo.id, embedded);
    } catch (error) {
      debugPrint('Albumseek faces failed for ${photo.id}: $error');
      _index.markFacesDone(photo.id);
    }
  }

  Future<void> _parseDocument(String id) async {
    final ocr = _index.textFor(id) ?? '';
    _storeDocument(id, ocr, parseChineseDocument(ocr));
  }

  Future<void> _visionDocument(String id) async {
    final ocr = _index.textFor(id) ?? '';
    var parsed = parseChineseDocument(ocr);
    try {
      final photo = _photo(id);
      if (photo != null && _namer.isOpen) {
        final bytes = await library.imageBytes(photo, maxSide: 1280);
        if (bytes != null) {
          final text = await _namer.ask(
            await uprightPng(bytes, maxSide: 1280),
            prompt: 'OCR:',
            maxOutputTokens: 512,
          );
          parsed =
              parseChineseDocument(text) ??
              parsed ??
              (text.trim().length >= 12
                  ? ParsedDocument(kind: 'form', fields: {'识别文本': text.trim()})
                  : null);
        }
      }
    } catch (error) {
      debugPrint('Albumseek document read failed for $id: $error');
    }
    _storeDocument(id, ocr, parsed);
  }

  void _storeDocument(String photoId, String ocr, ParsedDocument? parsed) {
    if (parsed == null) {
      _index.markDocDone(photoId);
      return;
    }
    _index.saveDocument(
      photoId: photoId,
      kind: parsed.kind,
      fieldsJson: jsonEncode(parsed.fields),
      ftsBody: cjkIndexText('$ocr\n${parsed.searchableText}'),
    );
  }

  List<PersonSummary> people() {
    final grouped = <int, List<String>>{};
    for (final row in _index.peopleRows()) {
      grouped.putIfAbsent(row.personId, () => <String>[]).add(row.photoId);
    }
    final people = [
      for (final entry in grouped.entries)
        PersonSummary(id: entry.key, photoIds: entry.value),
    ];
    people.sort((a, b) => b.photoIds.length.compareTo(a.photoIds.length));
    return people;
  }

  Map<String, String>? documentFields(String photoId) {
    final row = _index.documentFor(photoId);
    if (row == null) {
      return null;
    }
    final decoded = jsonDecode(row.fieldsJson);
    if (decoded is! Map) {
      return null;
    }
    return {
      for (final entry in decoded.entries) '${entry.key}': '${entry.value}',
    };
  }

  String? documentKind(String photoId) => _index.documentFor(photoId)?.kind;

  Future<void> _name(String id) async {
    final photo = _photo(id);
    if (photo == null) {
      _index.markNameFailed(id, 'This photo is no longer in the library.');
      return;
    }
    try {
      if (!_namer.isOpen) {
        _index.markNameFailed(photo.id, 'The naming model is not loaded.');
        return;
      }
      final bytes = await library.imageBytes(photo, maxSide: 768);
      if (bytes == null) {
        _index.markNameFailed(photo.id, 'No image bytes.');
        return;
      }
      final label = await _namer.label(await uprightPng(bytes, maxSide: 768));
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
  }

  Future<void> _ensureOcr() async {
    if (_ocr.isOpen) {
      return;
    }
    final dict = await File(store.fileFor(modelFileById('ocr-dict')).path)
        .readAsString();
    await _ocr.open(
      detectionPath: store.fileFor(modelFileById('ocr-det')).path,
      recognitionPath: store.fileFor(modelFileById('ocr-rec')).path,
      dictionary: dict,
    );
  }

  void _refreshCounts() {
    _publish(_schedule().snapshot(stage));
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
    unawaited(_faces.close());
    unawaited(_namer.close());
    unawaited(_faceIndex.close());
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
