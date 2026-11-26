import 'package:albumseek/src/engine/engine_plan.dart';
import 'package:albumseek/src/engine/inference_backend.dart';
import 'package:albumseek/src/engine/local_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('on-device runtimes and the index stay available to later builds', () {
    expect(plannedEngines.map((engine) => engine.runtime), [
      'ONNX Runtime',
      'MNN',
      'llama.cpp',
      'MediaPipe / LiteRT',
    ]);
    expect(plannedIndex, contains('sqlite-vec'));
    expect(plannedIndex, contains('FTS5'));
    expect(plannedIndex, contains('Chinese'));

    // These types are the extension points. They are not constructed here.
    const InferenceBackend Function(String runtimeName)? inference = null;
    const LocalIndex Function()? index = null;
    expect(inference, isNull);
    expect(index, isNull);
  });
}
