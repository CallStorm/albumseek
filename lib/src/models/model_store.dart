import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'model_catalog.dart';

/// Download progress for one model file.
class DownloadProgress {
  const DownloadProgress({
    required this.fileId,
    required this.received,
    required this.total,
  });

  final String fileId;
  final int received;
  final int? total;
}

/// Files under the app support directory. Missing files do not block the UI.
class ModelStore {
  ModelStore(this.directory);

  final Directory directory;

  File fileFor(ModelFile spec) => File(p.join(directory.path, spec.fileName));

  bool isReady(ModelFile spec) {
    final file = fileFor(spec);
    return file.existsSync() && file.lengthSync() >= spec.minimumBytes;
  }

  bool get searchModelsReady =>
      modelCatalog.where((file) => file.requiredForSearch).every(isReady);

  bool get namingModelsReady =>
      isReady(modelFileById('qwen-vl')) &&
      isReady(modelFileById('qwen-mmproj'));

  bool get faceModelsReady =>
      isReady(modelFileById('yunet')) && isReady(modelFileById('adaface'));

  bool get documentModelsReady =>
      isReady(modelFileById('paddleocr-vl')) &&
      isReady(modelFileById('paddleocr-mmproj'));

  Future<void> download(
    ModelFile spec, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    await directory.create(recursive: true);
    Object? lastError;
    for (final source in spec.sources) {
      try {
        await _downloadUrl(spec, source, onProgress);
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw ModelStoreException(
      'Could not download ${spec.fileName}. ${lastError ?? ''}'.trim(),
    );
  }

  Future<void> importFile(ModelFile spec, String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw ModelStoreException('${spec.fileName} was not found.');
    }
    await directory.create(recursive: true);
    final target = fileFor(spec);
    final partial = File('${target.path}.partial');
    await source.copy(partial.path);
    await _finish(spec, partial, target);
  }

  Future<void> _downloadUrl(
    ModelFile spec,
    String source,
    void Function(DownloadProgress progress)? onProgress,
  ) async {
    final target = fileFor(spec);
    final partial = File('${target.path}.partial');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(source));
      request.headers['user-agent'] = 'Albumseek/0.2 (on-device)';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw ModelStoreException(
          '${spec.fileName} returned HTTP ${response.statusCode}.',
        );
      }
      final sink = partial.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(
          DownloadProgress(
            fileId: spec.id,
            received: received,
            total: response.contentLength,
          ),
        );
      }
      await sink.close();
      if (response.contentLength != null &&
          received != response.contentLength) {
        throw ModelStoreException('${spec.fileName} download ended early.');
      }
      await _finish(spec, partial, target);
    } finally {
      client.close();
    }
  }

  Future<void> _finish(ModelFile spec, File partial, File target) async {
    if (partial.lengthSync() < spec.minimumBytes) {
      await partial.delete();
      throw ModelStoreException('${spec.fileName} is smaller than expected.');
    }
    final expected = spec.sha256;
    if (expected != null) {
      final digest = await sha256.bind(partial.openRead()).first;
      if (digest.toString() != expected) {
        await partial.delete();
        throw ModelStoreException(
          '${spec.fileName} did not match its published SHA-256.',
        );
      }
    }
    if (target.existsSync()) {
      await target.delete();
    }
    await partial.rename(target.path);
  }
}

class ModelStoreException implements Exception {
  ModelStoreException(this.message);
  final String message;
  @override
  String toString() => message;
}
