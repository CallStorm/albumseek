import 'package:albumseek/src/docs/document_fields.dart';
import 'package:albumseek/src/runtime/index_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('banner counts the active stage and says when search is ready', () {
    expect(
      indexStatusText(
        modelsReady: true,
        running: true,
        paused: false,
        stage: IndexStage.readingText,
        done: 12,
        total: 340,
        searchReady: false,
        namingSkipped: false,
      ),
      'Indexing · reading text 12 / 340',
    );
    expect(
      indexStatusText(
        modelsReady: true,
        running: true,
        paused: false,
        stage: IndexStage.embedding,
        done: 2,
        total: 2,
        searchReady: false,
        namingSkipped: false,
      ),
      'Indexing · embedding 2 / 2',
    );
    expect(
      indexStatusText(
        modelsReady: true,
        running: true,
        paused: false,
        stage: IndexStage.naming,
        done: 2,
        total: 2,
        searchReady: true,
        namingSkipped: false,
      ),
      'Indexing · naming 2 / 2. Search can be used while this continues.',
    );
  });

  test(
    'document vision ignores a screenshot that only contains 证, 户, or 表',
    () {
      const screenshot = '这是一张截图，里面有凭证、用户和表格';
      expect(parseChineseDocument(screenshot), isNull);
      expect(needsDocumentVision(screenshot), isFalse);
      expect(needsDocumentVision('聊天里提到证件和户口'), isFalse);

      const card = '''
姓名 张伟
性别 男
民族 汉
出生 1990年1月2日
住址 北京市朝阳区某路1号
公民身份号码 110101199001021234
''';
      expect(needsDocumentVision(card), isTrue);
      expect(needsDocumentVision('封面 居民户口簿'), isTrue);
      expect(
        needsDocumentVision('''
单位: 示例公司
编号: A-19
'''),
        isTrue,
      );
    },
  );

  test('each stage loads its model once, and naming can be skipped', () async {
    final library = _Library()
      ..texts['shot'] = '这是一张截图，里面有凭证、用户和表格'
      ..texts['card'] = '''
姓名 张伟
公民身份号码 110101199001021234
'''
      ..texts['hike'] = '周末爬山';
    final loads = _Loads();
    final seen = <IndexSnapshot>[];

    await runScheduledPass(
      read: library.schedule,
      stopped: () => false,
      publish: seen.add,
      loadOcr: loads.ocr.ensure,
      ocrPhoto: library.finishOcr,
      unloadOcr: loads.ocr.release,
      loadEmbed: loads.embed.ensure,
      embedPhoto: library.finishEmbed,
      unloadEmbed: loads.embed.release,
      loadFaces: loads.faces.ensure,
      facePhoto: library.finishFaces,
      unloadFaces: loads.faces.release,
      parseDocument: library.finishDoc,
      loadDocument: loads.vision.ensure,
      visionDocument: (id) async {
        loads.visionIds.add(id);
        library.docsDone.add(id);
      },
      unloadDocument: loads.vision.release,
      loadNamer: loads.namer.ensure,
      namePhoto: library.finishName,
      unloadNamer: loads.namer.release,
    );

    expect(loads.ocr.loads, 1);
    expect(loads.embed.loads, 1);
    expect(loads.faces.loads, 1);
    expect(loads.vision.loads, 1);
    expect(loads.visionIds, ['card']);
    expect(loads.namer.loads, 1);
    expect(library.namesDone, {'shot', 'card', 'hike'});
    expect(seen.first.stage, IndexStage.readingText);
    expect(seen.first.done, 0);
    expect(seen.first.total, 3);
    expect(seen.map((snapshot) => snapshot.stage).toSet(), {
      IndexStage.readingText,
      IndexStage.embedding,
      IndexStage.faces,
      IndexStage.documents,
      IndexStage.naming,
    });
    expect(seen.last.searchReady, isTrue);
    expect(
      indexStatusText(
        modelsReady: true,
        running: true,
        paused: false,
        stage: seen.last.stage,
        done: seen.last.done,
        total: seen.last.total,
        searchReady: seen.last.searchReady,
        namingSkipped: false,
      ),
      contains('Search can be used while this continues.'),
    );

    final again = _Loads();
    library.facesDone.addAll(library.ids);
    await runScheduledPass(
      read: library.schedule,
      stopped: () => false,
      publish: (_) {},
      loadOcr: again.ocr.ensure,
      ocrPhoto: library.finishOcr,
      unloadOcr: again.ocr.release,
      loadEmbed: again.embed.ensure,
      embedPhoto: library.finishEmbed,
      unloadEmbed: again.embed.release,
      loadFaces: again.faces.ensure,
      facePhoto: library.finishFaces,
      unloadFaces: again.faces.release,
      parseDocument: library.finishDoc,
      loadDocument: again.vision.ensure,
      visionDocument: (_) async {},
      unloadDocument: again.vision.release,
      loadNamer: again.namer.ensure,
      namePhoto: library.finishName,
      unloadNamer: again.namer.release,
    );
    expect(again.ocr.loads, 0);
    expect(again.embed.loads, 0);
    expect(again.faces.loads, 0);
    expect(again.vision.loads, 0);
    expect(again.namer.loads, 0);
  });

  test('skipping naming never loads the namer', () async {
    final library = _Library()..namingEnabled = false;
    final loads = _Loads();
    await runScheduledPass(
      read: library.schedule,
      stopped: () => false,
      publish: (_) {},
      loadOcr: loads.ocr.ensure,
      ocrPhoto: library.finishOcr,
      unloadOcr: loads.ocr.release,
      loadEmbed: loads.embed.ensure,
      embedPhoto: library.finishEmbed,
      unloadEmbed: loads.embed.release,
      loadFaces: loads.faces.ensure,
      facePhoto: library.finishFaces,
      unloadFaces: loads.faces.release,
      parseDocument: library.finishDoc,
      loadDocument: loads.vision.ensure,
      visionDocument: (_) async {},
      unloadDocument: loads.vision.release,
      loadNamer: loads.namer.ensure,
      namePhoto: library.finishName,
      unloadNamer: loads.namer.release,
    );
    expect(loads.namer.loads, 0);
    expect(library.namesDone, isEmpty);
    expect(library.schedule().searchReady, isTrue);
    expect(library.schedule().namingSkipped, isTrue);
    expect(
      indexStatusText(
        modelsReady: true,
        running: false,
        paused: false,
        stage: IndexStage.idle,
        done: 3,
        total: 3,
        searchReady: true,
        namingSkipped: true,
      ),
      'Search is ready. Naming is off.',
    );
  });
}

class _Gate {
  int loads = 0;
  var _open = false;

  Future<void> ensure() async {
    if (_open) {
      return;
    }
    _open = true;
    loads += 1;
  }

  Future<void> release() async {
    _open = false;
  }
}

class _Loads {
  final ocr = _Gate();
  final embed = _Gate();
  final faces = _Gate();
  final vision = _Gate();
  final namer = _Gate();
  final visionIds = <String>[];
}

class _Library {
  final ids = ['shot', 'card', 'hike'];
  final texts = <String, String>{};
  final ocrDone = <String>{};
  final embedDone = <String>{};
  final facesDone = <String>{};
  final docsDone = <String>{};
  final namesDone = <String>{};
  var namingEnabled = true;

  IndexSchedule schedule() {
    return IndexSchedule(
      photoIds: ids,
      ocrDone: ocrDone,
      embedDone: embedDone,
      facesDone: facesDone,
      docsDone: docsDone,
      namesDone: namesDone,
      textOf: (id) => texts[id],
      ocrReady: true,
      embedReady: true,
      faceModelsReady: true,
      documentModelsReady: true,
      namingModelsReady: true,
      namingEnabled: namingEnabled,
    );
  }

  Future<void> finishOcr(String id) async => ocrDone.add(id);

  Future<void> finishEmbed(String id) async => embedDone.add(id);

  Future<void> finishFaces(String id) async => facesDone.add(id);

  Future<void> finishDoc(String id) async => docsDone.add(id);

  Future<void> finishName(String id) async => namesDone.add(id);
}
