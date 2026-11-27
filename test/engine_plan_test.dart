import 'package:albumseek/src/engine/engine_plan.dart';
import 'package:albumseek/src/engine/face_index.dart';
import 'package:albumseek/src/engine/inference_backend.dart';
import 'package:albumseek/src/engine/local_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('linked runtimes include faces and document reading', () {
    expect(
      plannedEngines
          .where((engine) => engine.linked)
          .map((engine) => engine.runtime),
      ['ONNX Runtime', 'LiteRT', 'llama.cpp'],
    );
    expect(
      plannedEngines.map((engine) => engine.role).join(' '),
      contains('AdaFace'),
    );
    expect(
      plannedEngines.map((engine) => engine.role).join(' '),
      contains('PaddleOCR-VL'),
    );
    expect(plannedIndex, contains('sqlite-vec'));
    expect(plannedIndex, contains('FTS5'));
    expect(plannedIndex, contains('CJK'));

    const InferenceBackend Function(String runtimeName)? inference = null;
    const LocalIndex Function()? index = null;
    const FaceIndex Function()? faces = null;
    expect(inference, isNull);
    expect(index, isNull);
    expect(faces, isNull);
  });
}
