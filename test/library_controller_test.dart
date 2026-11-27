import 'package:albumseek/src/data/photo_library.dart';
import 'package:albumseek/src/model/album_summary.dart';
import 'package:albumseek/src/model/library_query.dart';
import 'package:albumseek/src/model/photo_record.dart';
import 'package:albumseek/src/state/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_photo_library.dart';

void main() {
  test('first denial explains access before sending the user to settings', () async {
    final library = FakePhotoLibrary();
    final controller = LibraryController(library: library);
    await controller.start();

    expect(controller.status, LibraryStatus.needsPermission);
    expect(library.requestCount, 0);

    await controller.requestAccess();

    expect(controller.status, LibraryStatus.denied);
    expect(library.requestCount, 1);
    controller.dispose();
  });

  test('granted access pages through the library', () async {
    final library = FakePhotoLibrary()
      ..access = PhotoAccess.granted
      ..albums = const [
        AlbumSummary(id: 'camera', name: 'Camera', count: 3),
      ]
      ..stored = [
        _photo('a'),
        _photo('b'),
        _photo('c'),
      ];
    final controller = LibraryController(library: library, pageSize: 2);
    await controller.start();

    expect(controller.status, LibraryStatus.ready);
    expect(controller.indexing, isFalse);
    expect(controller.photos.map((photo) => photo.id), ['a', 'b', 'c']);
    expect(controller.albums.single.name, 'Camera');
    expect(controller.accessLimited, isFalse);
    expect(library.watchStarts, 1);
    expect(library.loadCalls, 2);
    controller.dispose();
  });

  test('limited access is marked so the UI can offer a wider selection', () async {
    final library = FakePhotoLibrary()
      ..access = PhotoAccess.limited
      ..stored = [_photo('only')];
    final controller = LibraryController(library: library);
    await controller.start();

    expect(controller.accessLimited, isTrue);
    expect(controller.photos.single.id, 'only');
    controller.dispose();
  });

  test('a library read failure stays on the failure screen', () async {
    final library = FakePhotoLibrary()
      ..access = PhotoAccess.granted
      ..failLoad = true;
    final controller = LibraryController(library: library);
    await controller.start();

    expect(controller.status, LibraryStatus.failed);
    expect(controller.errorMessage, 'storage unavailable');
    controller.dispose();
  });

  test('the system picker is the fallback when library access is off', () async {
    final library = FakePhotoLibrary()
      ..pickerResult = [_photo('picked', title: 'scan.jpg')];
    final controller = LibraryController(library: library);
    await controller.start();

    await controller.pickWithSystemPicker();

    expect(controller.status, LibraryStatus.ready);
    expect(controller.usingSystemPicker, isTrue);
    expect(controller.photos.single.title, 'scan.jpg');

    library.pickerResult = const [];
    await controller.pickWithSystemPicker();
    expect(controller.photos.single.title, 'scan.jpg');

    library.failPicker = true;
    await controller.pickWithSystemPicker();
    expect(controller.errorMessage, 'picker unavailable');
    expect(controller.usingSystemPicker, isTrue);
    controller.dispose();
  });

  test('search uses the loaded catalog', () async {
    final library = FakePhotoLibrary()
      ..access = PhotoAccess.granted
      ..stored = [
        _photo('one', title: 'IMG_1.jpg'),
        _photo('two', title: 'Screenshot.png'),
      ];
    final controller = LibraryController(library: library);
    await controller.start();

    final matches = controller.apply(const LibraryQuery(filename: 'img'));
    expect(matches.map((photo) => photo.id), ['one']);
    controller.dispose();
  });

  test('a library change schedules another read', () async {
    final library = FakePhotoLibrary()
      ..access = PhotoAccess.granted
      ..stored = [_photo('a')];
    final controller = LibraryController(
      library: library,
      reloadDebounce: Duration.zero,
    );
    await controller.start();
    final calls = library.loadCalls;

    library.stored = [_photo('a'), _photo('b')];
    library.emitChange();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(library.loadCalls, greaterThan(calls));
    expect(controller.photos.map((photo) => photo.id), ['a', 'b']);
    controller.dispose();
  });
}

PhotoRecord _photo(String id, {String title = 'IMG.jpg'}) {
  return PhotoRecord(
    id: id,
    title: title,
    createdAt: DateTime(2026, 6, 15),
  );
}
