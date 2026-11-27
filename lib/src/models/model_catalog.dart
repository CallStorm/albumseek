/// One file the app downloads or imports. Weights are never inside the APK.
class ModelFile {
  const ModelFile({
    required this.id,
    required this.fileName,
    required this.role,
    required this.license,
    required this.sources,
    this.sha256,
    this.minimumBytes = 1024,
  });

  final String id;
  final String fileName;
  final String role;
  final String license;

  /// Tried in order. The first is the owner's or an official export.
  final List<String> sources;
  final String? sha256;
  final int minimumBytes;

  bool get requiredForSearch =>
      id == 'ocr-det' || id == 'ocr-rec' || id == 'ocr-dict' || id == 'eg2';

  bool get faceModel => id == 'yunet' || id == 'adaface';

  bool get documentModel => id == 'paddleocr-vl' || id == 'paddleocr-mmproj';
}

/// Official files for this build. SHA-256 values are the publisher's.
const List<ModelFile> modelCatalog = <ModelFile>[
  ModelFile(
    id: 'ocr-det',
    fileName: 'PP-OCRv6_det_medium.onnx',
    role: 'PP-OCRv6 medium text detection',
    license: 'Apache-2.0',
    sha256: '92078b7355007ccfffcd4c8cd441a3afd4538904d06881b29a155e1e679907c2',
    minimumBytes: 40 * 1000 * 1000,
    sources: [
      'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/det/PP-OCRv6_det_medium.onnx',
      'https://huggingface.co/haotruong-hitlab/pp-ocrv6-medium-onnx/resolve/main/PP-OCRv6_det_medium.onnx',
    ],
  ),
  ModelFile(
    id: 'ocr-rec',
    fileName: 'PP-OCRv6_rec_medium.onnx',
    role: 'PP-OCRv6 medium text recognition, Simplified Chinese and English',
    license: 'Apache-2.0',
    sha256: 'eef444829dbbe18d7fea59a3f6eb75647518d2b3a9568d27c92e42940204894b',
    minimumBytes: 50 * 1000 * 1000,
    sources: [
      'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/rec/PP-OCRv6_rec_medium.onnx',
      'https://huggingface.co/haotruong-hitlab/pp-ocrv6-medium-onnx/resolve/main/PP-OCRv6_rec_medium.onnx',
    ],
  ),
  ModelFile(
    id: 'ocr-dict',
    fileName: 'ppocrv6_dict.txt',
    role: 'PP-OCRv6 medium character list, 18708 lines',
    license: 'Apache-2.0',
    sha256: 'b5f2bfe2bdd9448429e3e82b51c789775d9b42f2403d082b00662eb77e401c5d',
    minimumBytes: 50 * 1000,
    sources: [
      'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/paddle/PP-OCRv6/rec/PP-OCRv6_rec_medium/ppocrv6_dict.txt',
      'https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/ppocr/utils/dict/ppocrv6_dict.txt',
    ],
  ),
  ModelFile(
    id: 'eg2',
    fileName: 'embeddinggemma-2-text-vision-440m.litertlm',
    role: 'EmbeddingGemma 2 text 270M plus vision 170M, unified 768-d, CPU LiteRT',
    license: 'Apache-2.0',
    minimumBytes: 200 * 1000 * 1000,
    sources: [
      'https://huggingface.co/litert-community/embeddinggemma-2-text-vision-440m-litert-lm/resolve/e301f74d5551b0c2641bd5cb4652a76239d5c5f8/embeddinggemma-2-text-vision-440m.litertlm',
      'https://huggingface.co/litert-community/embeddinggemma-2-text-vision-440m-litert-lm/resolve/main/embeddinggemma-2-text-vision-440m.litertlm',
    ],
  ),
  ModelFile(
    id: 'yunet',
    fileName: 'face_detection_yunet_2023mar.onnx',
    role: 'OpenCV YuNet face detector, 640×640',
    license: 'MIT',
    sha256: '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4',
    minimumBytes: 100 * 1000,
    sources: [
      'https://huggingface.co/opencv/face_detection_yunet/resolve/main/face_detection_yunet_2023mar.onnx',
      'https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx',
    ],
  ),
  ModelFile(
    id: 'adaface',
    fileName: 'adaface_ir_18.onnx',
    role: 'AdaFace IR-18 embeddings, WebFace4M, 512-d, MIT',
    license: 'MIT',
    sha256: '6b6a35772fb636cdd4fa86520c1a259d0c41472a76f70f802b351837a00d9870',
    minimumBytes: 80 * 1000 * 1000,
    sources: [
      'https://github.com/yakhyo/adaface-onnx/releases/download/weights/adaface_ir_18.onnx',
      'https://huggingface.co/yakhyo/uniface-weights/resolve/main/adaface_ir_18.onnx',
    ],
  ),
  ModelFile(
    id: 'paddleocr-vl',
    fileName: 'paddleocr-vl-1-6-Q4_K_M.gguf',
    role: 'PaddleOCR-VL-1.6 0.9B Q4_K_M decoder for structured documents, Apache-2.0',
    license: 'Apache-2.0',
    minimumBytes: 200 * 1000 * 1000,
    sources: [
      'https://huggingface.co/moonbox-dev/PaddleOCR-VL-1.6-GGUF/resolve/main/paddleocr-vl-1-6-Q4_K_M.gguf',
    ],
  ),
  ModelFile(
    id: 'paddleocr-mmproj',
    fileName: 'mmproj-paddleocr-vl-1-6-F16.gguf',
    role: 'PaddleOCR-VL-1.6 vision encoder and projector',
    license: 'Apache-2.0',
    minimumBytes: 600 * 1000 * 1000,
    sources: [
      'https://huggingface.co/moonbox-dev/PaddleOCR-VL-1.6-GGUF/resolve/main/mmproj-paddleocr-vl-1-6-F16.gguf',
    ],
  ),
  ModelFile(
    id: 'qwen-vl',
    fileName: 'Qwen3VL-2B-Instruct-Q4_K_M.gguf',
    role: 'Qwen3-VL-2B-Instruct 4-bit language weights for short labels',
    license: 'Apache-2.0',
    minimumBytes: 900 * 1000 * 1000,
    sources: [
      'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3VL-2B-Instruct-Q4_K_M.gguf',
    ],
  ),
  ModelFile(
    id: 'qwen-mmproj',
    fileName: 'mmproj-Qwen3VL-2B-Instruct-F16.gguf',
    role: 'Qwen3-VL-2B vision encoder and projector',
    license: 'Apache-2.0',
    minimumBytes: 600 * 1000 * 1000,
    sources: [
      'https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-2B-Instruct-F16.gguf',
    ],
  ),
];

/// Search files are required for semantic search. The rest are optional.
String modelSection(ModelFile file) {
  if (file.requiredForSearch) {
    return 'Search';
  }
  if (file.faceModel) {
    return 'Faces, optional';
  }
  if (file.documentModel) {
    return 'Documents, optional';
  }
  return 'Labels, optional';
}

ModelFile modelFileById(String id) {
  return modelCatalog.firstWhere((file) => file.id == id);
}

ModelFile? modelFileByName(String fileName) {
  for (final file in modelCatalog) {
    if (file.fileName == fileName) {
      return file;
    }
  }
  return null;
}
