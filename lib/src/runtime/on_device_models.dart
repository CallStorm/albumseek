import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// EmbeddingGemma 2 text+vision bundle. Loaded only while embedding, then closed.
class GemmaEmbedder {
  EmbeddingModel? _model;

  bool get isOpen => _model != null && !_model!.isClosed;

  Future<void> open(String modelPath) async {
    if (isOpen) {
      return;
    }
    await FlutterEdgeAi.installEmbedder().modelFromFile(modelPath).install();
    _model = await FlutterEdgeAi.getActiveEmbedder(supportImage: true);
  }

  Future<List<double>> embedImage(Uint8List png) {
    final model = _require();
    return model.embed(
      EmbeddingInput.image(png),
      taskType: TaskType.retrievalDocument,
    );
  }

  /// Text queries over an image index are sent without a task prefix.
  Future<List<double>> embedQuery(String text) {
    final model = _require();
    return model.embed(EmbeddingInput.text(text), taskType: TaskType.none);
  }

  EmbeddingModel _require() {
    final model = _model;
    if (model == null || model.isClosed) {
      throw StateError('EmbeddingGemma 2 is not loaded.');
    }
    return model;
  }

  Future<void> close() async {
    final model = _model;
    _model = null;
    if (model != null && !model.isClosed) {
      await model.close();
    }
  }
}

/// One llama.cpp vision model, kept open for a whole indexing pass.
class QwenVlNamer {
  InferenceModel? _model;

  bool get isOpen => _model != null && !_model!.isClosed;

  /// Installs [ggufPath] only when this namer is not already holding a model.
  Future<void> open(String ggufPath) async {
    if (isOpen) {
      return;
    }
    await FlutterEdgeAi.installModel(
      modelType: ModelType.general,
      fileType: ModelFileType.gguf,
    ).fromFile(ggufPath).install();
    _model = await FlutterEdgeAi.getActiveModel(
      maxTokens: 2048,
      supportImage: true,
      preferredBackend: PreferredBackend.cpu,
    );
  }

  Future<String> label(Uint8List png) {
    return ask(
      png,
      prompt: '用不超过8个汉字给这张照片起一个短标题，例如“身份证”或“周末爬山”。只输出标题。',
      maxOutputTokens: 32,
    ).then(cleanLabel);
  }

  /// One image question. The model stays loaded; only the chat is closed.
  Future<String> ask(
    Uint8List png, {
    required String prompt,
    int maxOutputTokens = 512,
  }) async {
    final model = _model;
    if (model == null || model.isClosed) {
      throw StateError('Vision model is not loaded.');
    }
    final chat = await model.openChat(maxOutputTokens: maxOutputTokens);
    try {
      await chat.addQuery(
        Message.withImage(text: prompt, isUser: true, imageBytes: png),
      );
      final buffer = StringBuffer();
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }
      return buffer.toString().trim();
    } finally {
      await chat.close();
    }
  }

  Future<void> close() async {
    final model = _model;
    _model = null;
    if (model != null && !model.isClosed) {
      await model.close();
    }
  }
}

/// First line, without wrapping quotes, capped for a chip.
String cleanLabel(String raw) {
  var text = raw.trim();
  final line = text.split(RegExp(r'[\r\n]')).first.trim();
  text = line.replaceAll(RegExp(r'^[“"\s]+|[”"\s]+$'), '');
  if (text.length > 16) {
    text = text.substring(0, 16);
  }
  return text.trim();
}

/// Upright PNG, long side at most [maxSide]. Flutter applies EXIF orientation.
Future<Uint8List> uprightPng(Uint8List photo, {int maxSide = 1024}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(photo);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final longest = math.max(width, height);
      if (longest <= maxSide) {
        return const ui.TargetImageSize();
      }
      if (width >= height) {
        return ui.TargetImageSize(width: maxSide);
      }
      return ui.TargetImageSize(height: maxSide);
    },
  );
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  buffer.dispose();
  if (png == null) {
    throw StateError('Could not encode a photo for the model.');
  }
  return png.buffer.asUint8List();
}
