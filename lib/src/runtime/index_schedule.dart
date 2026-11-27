import '../docs/document_fields.dart';

enum IndexStage { idle, readingText, embedding, faces, documents, naming }

/// What the indexer still has to do, read fresh after every photo.
class IndexSchedule {
  const IndexSchedule({
    required this.photoIds,
    required this.ocrDone,
    required this.embedDone,
    required this.facesDone,
    required this.docsDone,
    required this.namesDone,
    required this.textOf,
    required this.ocrReady,
    required this.embedReady,
    required this.faceModelsReady,
    required this.documentModelsReady,
    required this.namingModelsReady,
    required this.namingEnabled,
  });

  final List<String> photoIds;
  final Set<String> ocrDone;
  final Set<String> embedDone;
  final Set<String> facesDone;
  final Set<String> docsDone;
  final Set<String> namesDone;
  final String? Function(String id) textOf;
  final bool ocrReady;
  final bool embedReady;
  final bool faceModelsReady;
  final bool documentModelsReady;
  final bool namingModelsReady;
  final bool namingEnabled;

  List<String> pendingOcr() => ocrReady ? _missing(ocrDone) : const <String>[];

  List<String> pendingEmbed() =>
      embedReady ? _missing(embedDone) : const <String>[];

  List<String> pendingFaces() =>
      faceModelsReady ? _missing(facesDone) : const <String>[];

  List<String> pendingDocs() {
    if (!ocrReady && !documentModelsReady) {
      return const <String>[];
    }
    return [
      for (final id in photoIds)
        if (ocrDone.contains(id) && !docsDone.contains(id)) id,
    ];
  }

  List<String> pendingNames() => namingModelsReady && namingEnabled
      ? _missing(namesDone)
      : const <String>[];

  /// OCR and embeddings are finished, so keyword and visual search can run.
  bool get searchReady =>
      photoIds.isNotEmpty &&
      ocrReady &&
      embedReady &&
      photoIds.every((id) => ocrDone.contains(id) && embedDone.contains(id));

  bool get namingSkipped =>
      !namingEnabled &&
      namingModelsReady &&
      photoIds.any((id) => !namesDone.contains(id));

  int get searchDone => photoIds
      .where((id) => ocrDone.contains(id) && embedDone.contains(id))
      .length;

  IndexSnapshot snapshot(IndexStage stage) {
    final pending = switch (stage) {
      IndexStage.readingText => pendingOcr(),
      IndexStage.embedding => pendingEmbed(),
      IndexStage.faces => pendingFaces(),
      IndexStage.documents => pendingDocs(),
      IndexStage.naming => pendingNames(),
      IndexStage.idle => const <String>[],
    };
    final done = stage == IndexStage.idle
        ? searchDone
        : photoIds.length - pending.length;
    return IndexSnapshot(
      stage: stage,
      done: done,
      total: photoIds.length,
      searchReady: searchReady,
      namingSkipped: namingSkipped,
    );
  }

  List<String> _missing(Set<String> done) => [
    for (final id in photoIds)
      if (!done.contains(id)) id,
  ];
}

class IndexSnapshot {
  const IndexSnapshot({
    required this.stage,
    required this.done,
    required this.total,
    required this.searchReady,
    required this.namingSkipped,
  });

  final IndexStage stage;
  final int done;
  final int total;
  final bool searchReady;
  final bool namingSkipped;
}

String stageLabel(IndexStage stage) {
  return switch (stage) {
    IndexStage.readingText => 'reading text',
    IndexStage.embedding => 'embedding',
    IndexStage.faces => 'finding faces',
    IndexStage.documents => 'reading documents',
    IndexStage.naming => 'naming',
    IndexStage.idle => 'indexed',
  };
}

/// Banner copy. Counts belong to the active stage, not to OCR-plus-embedding.
String indexStatusText({
  required bool modelsReady,
  required bool running,
  required bool paused,
  required IndexStage stage,
  required int done,
  required int total,
  required bool searchReady,
  required bool namingSkipped,
}) {
  if (!modelsReady) {
    return 'Download on-device models to search text and pictures.';
  }
  if (total == 0) {
    return 'No photos to index.';
  }
  final counts = '$done / $total';
  final label = stageLabel(stage);
  if ((running || paused) && stage != IndexStage.idle) {
    final head = running ? 'Indexing' : 'Paused';
    final line = '$head · $label $counts';
    if (searchReady) {
      return '$line. Search can be used while this continues.';
    }
    return line;
  }
  if (searchReady && namingSkipped) {
    return 'Search is ready. Naming is off.';
  }
  if (searchReady) {
    return 'Search is ready.';
  }
  return 'Indexed $counts';
}

/// One indexing pass. Each resident model is loaded for its stage and unloaded
/// when the stage ends, the user pauses, or naming is turned off.
Future<void> runScheduledPass({
  required IndexSchedule Function() read,
  required bool Function() stopped,
  required void Function(IndexSnapshot snapshot) publish,
  required Future<void> Function() loadOcr,
  required Future<void> Function(String id) ocrPhoto,
  required Future<void> Function() unloadOcr,
  required Future<void> Function() loadEmbed,
  required Future<void> Function(String id) embedPhoto,
  required Future<void> Function() unloadEmbed,
  required Future<void> Function() loadFaces,
  required Future<void> Function(String id) facePhoto,
  required Future<void> Function() unloadFaces,
  required Future<void> Function(String id) parseDocument,
  required Future<void> Function() loadDocument,
  required Future<void> Function(String id) visionDocument,
  required Future<void> Function() unloadDocument,
  required Future<void> Function() loadNamer,
  required Future<void> Function(String id) namePhoto,
  required Future<void> Function() unloadNamer,
}) async {
  await _resident(
    stage: IndexStage.readingText,
    read: read,
    pendingOf: (schedule) => schedule.pendingOcr(),
    stopped: stopped,
    publish: publish,
    load: loadOcr,
    work: ocrPhoto,
    unload: unloadOcr,
  );
  if (stopped()) {
    return;
  }
  await _resident(
    stage: IndexStage.embedding,
    read: read,
    pendingOf: (schedule) => schedule.pendingEmbed(),
    stopped: stopped,
    publish: publish,
    load: loadEmbed,
    work: embedPhoto,
    unload: unloadEmbed,
  );
  if (stopped()) {
    return;
  }
  await _resident(
    stage: IndexStage.faces,
    read: read,
    pendingOf: (schedule) => schedule.pendingFaces(),
    stopped: stopped,
    publish: publish,
    load: loadFaces,
    work: facePhoto,
    unload: unloadFaces,
  );
  if (stopped()) {
    return;
  }
  await _documents(
    read: read,
    stopped: stopped,
    publish: publish,
    parseDocument: parseDocument,
    loadDocument: loadDocument,
    visionDocument: visionDocument,
    unloadDocument: unloadDocument,
  );
  if (stopped()) {
    return;
  }
  final schedule = read();
  if (!schedule.namingEnabled || !schedule.namingModelsReady) {
    return;
  }
  await _resident(
    stage: IndexStage.naming,
    read: read,
    pendingOf: (schedule) => schedule.pendingNames(),
    stopped: stopped,
    publish: publish,
    load: loadNamer,
    work: namePhoto,
    unload: unloadNamer,
    continueStage: () => read().namingEnabled,
  );
}

Future<void> _resident({
  required IndexStage stage,
  required IndexSchedule Function() read,
  required List<String> Function(IndexSchedule schedule) pendingOf,
  required bool Function() stopped,
  required void Function(IndexSnapshot snapshot) publish,
  required Future<void> Function() load,
  required Future<void> Function(String id) work,
  required Future<void> Function() unload,
  bool Function()? continueStage,
}) async {
  if (pendingOf(read()).isEmpty) {
    return;
  }
  if (continueStage != null && !continueStage()) {
    return;
  }
  publish(read().snapshot(stage));
  try {
    await load();
    while (true) {
      if (stopped()) {
        return;
      }
      if (continueStage != null && !continueStage()) {
        return;
      }
      final pending = pendingOf(read());
      if (pending.isEmpty) {
        return;
      }
      await load();
      await work(pending.first);
      publish(read().snapshot(stage));
    }
  } finally {
    await unload();
  }
}

Future<void> _documents({
  required IndexSchedule Function() read,
  required bool Function() stopped,
  required void Function(IndexSnapshot snapshot) publish,
  required Future<void> Function(String id) parseDocument,
  required Future<void> Function() loadDocument,
  required Future<void> Function(String id) visionDocument,
  required Future<void> Function() unloadDocument,
}) async {
  if (read().pendingDocs().isEmpty) {
    return;
  }
  publish(read().snapshot(IndexStage.documents));
  final queued = List<String>.of(read().pendingDocs());
  for (final id in queued) {
    if (stopped()) {
      return;
    }
    final schedule = read();
    if (!schedule.pendingDocs().contains(id)) {
      continue;
    }
    final text = schedule.textOf(id) ?? '';
    if (needsDocumentVision(text) && schedule.documentModelsReady) {
      continue;
    }
    await parseDocument(id);
    publish(read().snapshot(IndexStage.documents));
  }
  if (stopped()) {
    return;
  }
  final schedule = read();
  final vision = [
    for (final id in schedule.pendingDocs())
      if (needsDocumentVision(schedule.textOf(id) ?? '')) id,
  ];
  if (vision.isEmpty || !schedule.documentModelsReady) {
    return;
  }
  try {
    await loadDocument();
    for (final id in vision) {
      if (stopped()) {
        return;
      }
      await loadDocument();
      await visionDocument(id);
      publish(read().snapshot(IndexStage.documents));
    }
  } finally {
    await unloadDocument();
  }
}
