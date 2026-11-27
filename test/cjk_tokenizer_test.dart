import 'package:albumseek/src/index/cjk_tokenizer.dart';
import 'package:albumseek/src/index/rrf.dart';
import 'package:albumseek/src/models/model_catalog.dart';
import 'package:albumseek/src/ocr/ctc_decode.dart';
import 'package:albumseek/src/ocr/text_boxes.dart';
import 'package:albumseek/src/runtime/on_device_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chinese queries become overlapping bigrams', () {
    expect(cjkTokens('身份证'), ['身份', '份证']);
    expect(cjkMatchQuery('身份证'), '"身份" AND "份证"');
    expect(cjkTokens('山'), ['山']);
    expect(cjkTokens('IMG_12 and 发票'), ['img', '12', 'and', '发票']);
  });

  test('reciprocal rank fusion prefers items ranked by both lists', () {
    final fused = reciprocalRankFusion([
      ['a', 'b'],
      ['b', 'c'],
    ]);
    expect(fused.first.id, 'b');
    expect(fused.map((rank) => rank.id), containsAll(['a', 'c']));
  });

  test('CTC drops blanks and repeated classes', () {
    expect(ctcDecode(const [0, 1, 1, 0, 2], const ['身', '份']), '身份');
    expect(ctcArgmax(const [0.1, 0.9, 0.8, 0.2], 2), [1, 0]);
  });

  test('a bright blob on the detection map becomes a box', () {
    final map = List<double>.filled(20 * 10, 0);
    for (var y = 2; y < 6; y++) {
      for (var x = 3; x < 12; x++) {
        map[y * 20 + x] = 0.95;
      }
    }
    final boxes = boxesFromMap(map, width: 20, height: 10);
    expect(boxes, isNotEmpty);
    expect(boxes.first.left, lessThan(5));
    expect(boxes.first.right, greaterThan(10));
  });

  test('model files are the medium OCR stack and EmbeddingGemma 2', () {
    final det = modelFileById('ocr-det');
    expect(det.fileName, 'PP-OCRv6_det_medium.onnx');
    expect(det.license, 'Apache-2.0');
    expect(det.sha256, startsWith('92078b73'));
    expect(modelFileById('ocr-rec').fileName, contains('medium'));
    expect(modelFileByName('ppocrv6_dict.txt')!.sha256, startsWith('b5f2bfe2'));
    expect(modelFileById('eg2').fileName, contains('440m'));
    expect(modelFileById('qwen-vl').fileName, contains('Q4_K_M'));
    expect(modelFileById('qwen-mmproj').fileName, contains('mmproj'));
    expect(
      modelFileById('yunet').fileName,
      'face_detection_yunet_2023mar.onnx',
    );
    expect(modelFileById('yunet').license, 'MIT');
    expect(modelFileById('adaface').fileName, 'adaface_ir_18.onnx');
    expect(modelFileById('adaface').license, 'MIT');
    expect(modelFileById('paddleocr-vl').fileName, contains('Q4_K_M'));
    expect(modelFileById('paddleocr-vl').license, 'Apache-2.0');
    expect(
      modelFileById('paddleocr-mmproj').fileName,
      contains('mmproj-paddleocr'),
    );
    expect(
      modelCatalog.every(
        (file) => file.license == 'Apache-2.0' || file.license == 'MIT',
      ),
      isTrue,
    );
    expect(modelCatalog.where((file) => file.requiredForSearch), hasLength(4));
    expect(modelFileById('yunet').requiredForSearch, isFalse);
  });

  test('a model label keeps the first short line', () {
    expect(cleanLabel('  “周末爬山”\n说明'), '周末爬山');
  });
}
