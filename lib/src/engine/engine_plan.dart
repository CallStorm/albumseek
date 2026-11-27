/// Runtimes this build actually links, plus the face stack left for later.
class EnginePlan {
  const EnginePlan({
    required this.runtime,
    required this.role,
    required this.linked,
  });

  final String runtime;
  final String role;
  final bool linked;
}

const List<EnginePlan> plannedEngines = <EnginePlan>[
  EnginePlan(
    runtime: 'ONNX Runtime',
    role: 'PP-OCRv6 medium OCR on CPU',
    linked: true,
  ),
  EnginePlan(
    runtime: 'LiteRT',
    role: 'EmbeddingGemma 2 text and vision embeddings',
    linked: true,
  ),
  EnginePlan(
    runtime: 'llama.cpp',
    role: 'Qwen3-VL-2B-Instruct labels, unloaded after each photo',
    linked: true,
  ),
  EnginePlan(
    runtime: 'MediaPipe or YuNet + AdaFace',
    role: 'Face clustering, not linked yet',
    linked: false,
  ),
];

/// Storage for keyword and vector search.
const String plannedIndex =
    'sqlite-vec for 768-d vectors and SQLite FTS5 with CJK bigrams';
