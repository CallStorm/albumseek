import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// On-device inference boundary.
///
/// PP-OCRv6 runs through [OnnxRuntimeBackend] on the CPU execution provider.
/// EmbeddingGemma 2 uses LiteRT, and Qwen3-VL-2B uses llama.cpp. Those
/// engines stay behind their own types so only one of them is loaded at a time.
abstract interface class InferenceBackend {
  String get runtimeName;

  Future<void> loadModel(String modelPath);

  Future<void> close();
}

/// One ONNX Runtime session. CPU only, so a phone without NNAPI or a GPU
/// delegate still runs.
class OnnxRuntimeBackend implements InferenceBackend {
  OnnxRuntimeBackend({OnnxRuntime? runtime})
    : _runtime = runtime ?? OnnxRuntime();

  final OnnxRuntime _runtime;
  OrtSession? _session;
  String? _loadedPath;

  @override
  String get runtimeName => 'ONNX Runtime';

  OrtSession? get session => _session;

  bool get isOpen => _session != null;

  @override
  Future<void> loadModel(String modelPath) async {
    if (_session != null && _loadedPath == modelPath) {
      return;
    }
    await _session?.close();
    _session = await _runtime.createSession(
      modelPath,
      options: OrtSessionOptions(
        intraOpNumThreads: 4,
        providers: const [OrtProvider.CPU],
      ),
    );
    _loadedPath = modelPath;
  }

  Future<Map<String, OrtValue>> run(Map<String, OrtValue> inputs) {
    final current = _session;
    if (current == null) {
      throw StateError('ONNX Runtime has no model loaded.');
    }
    return current.run(inputs);
  }

  @override
  Future<void> close() async {
    await _session?.close();
    _session = null;
    _loadedPath = null;
  }
}
