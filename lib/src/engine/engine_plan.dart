/// Runtimes this build links. Face and document weights stay optional downloads.
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
    role: 'PP-OCRv6 medium, YuNet, and AdaFace on CPU',
    linked: true,
  ),
  EnginePlan(
    runtime: 'LiteRT',
    role: 'EmbeddingGemma 2 text and vision embeddings',
    linked: true,
  ),
  EnginePlan(
    runtime: 'llama.cpp',
    role:
        'Qwen3-VL labels and PaddleOCR-VL document fields, one model at a time',
    linked: true,
  ),
];

/// Storage for keyword and vector search.
const String plannedIndex =
    'sqlite-vec for 768-d vectors and SQLite FTS5 with CJK bigrams';
