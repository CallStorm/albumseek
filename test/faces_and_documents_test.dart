import 'package:albumseek/src/docs/document_fields.dart';
import 'package:albumseek/src/faces/face_cluster.dart';
import 'package:albumseek/src/faces/yunet_decode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('YuNet keeps a high-score cell and drops a weak one', () {
    final faces = decodeYuNet(
      cls8: [8, -8],
      obj8: [8, 8],
      bbox8: [0, 0, 0.2, 0.2, 0, 0, 0.2, 0.2],
      cls16: const [],
      obj16: const [],
      bbox16: const [],
      cls32: const [],
      obj32: const [],
      bbox32: const [],
    );
    expect(faces, hasLength(1));
    expect(faces.single.score, greaterThan(0.9));
    expect(faces.single.width, greaterThan(8));
  });

  test('YuNet non-maximum suppression merges overlapping boxes', () {
    final faces = decodeYuNet(
      cls8: [8, 8],
      obj8: [8, 8],
      bbox8: [0, 0, 1, 1, 0.1, 0.1, 1, 1],
      cls16: const [],
      obj16: const [],
      bbox16: const [],
      cls32: const [],
      obj32: const [],
      bbox32: const [],
    );
    expect(faces, hasLength(1));
  });

  test(
    'the same person stays together and a different face starts a new one',
    () {
      final roster = FaceRoster();
      final first = roster.add([1, 0, 0]);
      final same = roster.add([0.95, 0.05, 0]);
      final other = roster.add([0, 1, 0]);
      expect(same, first);
      expect(other, isNot(first));
    },
  );

  test('re-indexing reuses stored embeddings instead of new person ids', () {
    final stored = FaceRoster();
    final person = stored.add([1, 0, 0]);
    final again = FaceRoster.fromSamples([
      FaceSample(personId: person, embedding: [1, 0, 0]),
    ]);
    expect(again.add([0.96, 0.02, 0]), person);
    expect(again.add([0, 0, 1]), isNot(person));
  });

  test(
    'an identity card and a household register become structured fields',
    () {
      final card = parseChineseDocument('''
姓名 张伟
性别 男
民族 汉
出生 1990年1月2日
住址 北京市朝阳区某路1号
公民身份号码 110101199001021234
''');
      expect(card?.kind, 'id_card');
      expect(card?.fields['姓名'], '张伟');
      expect(card?.fields['公民身份号码'], '110101199001021234');
      expect(card?.searchableText, contains('身份证'));

      final household = parseChineseDocument('''
户主姓名 李娜
户号 001234
与户主关系 户主
姓名 李娜
住址 上海市浦东新区某街2号
''');
      expect(household?.kind, 'household');
      expect(household?.fields['户主姓名'], '李娜');
      expect(household?.fields['户号'], '001234');
      expect(kindLabel('household'), '户口本');
    },
  );

  test('a labeled form is kept when it is not an identity document', () {
    final form = parseChineseDocument('''
单位: 示例公司
编号: A-19
日期: 2024年5月1日
''');
    expect(form?.kind, 'form');
    expect(form?.fields['单位'], '示例公司');
    expect(parseChineseDocument('周末爬山'), isNull);
  });
}
