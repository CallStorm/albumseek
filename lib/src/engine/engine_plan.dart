/// Runtimes the Android project is structured to host later.
///
/// None of these are linked in this build. See [InferenceBackend] and
/// [LocalIndex].
class EnginePlan {
  const EnginePlan({required this.runtime, required this.role});

  final String runtime;
  final String role;
}

const List<EnginePlan> plannedEngines = <EnginePlan>[
  EnginePlan(
    runtime: 'ONNX Runtime',
    role: 'Portable model inference',
  ),
  EnginePlan(
    runtime: 'MNN',
    role: 'Mobile inference, including OCR',
  ),
  EnginePlan(
    runtime: 'llama.cpp',
    role: 'Local text models',
  ),
  EnginePlan(
    runtime: 'MediaPipe / LiteRT',
    role: 'On-device vision tasks',
  ),
];

/// Storage planned for keyword and vector search.
const String plannedIndex =
    'sqlite-vec for vectors and SQLite FTS5 with Chinese tokenization';
