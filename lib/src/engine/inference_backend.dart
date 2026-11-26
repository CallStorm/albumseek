/// On-device inference boundary.
///
/// Later Android builds will attach a native runtime behind this type:
/// ONNX Runtime, MNN, llama.cpp, or MediaPipe / LiteRT. This build does not
/// download weights or run a model.
abstract interface class InferenceBackend {
  String get runtimeName;

  Future<void> loadModel(String modelPath);

  Future<void> close();
}
