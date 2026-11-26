import 'package:albumseek/src/albumseek_app.dart';
import 'package:albumseek/src/data/photo_library.dart';
import 'package:albumseek/src/model/album_summary.dart';
import 'package:albumseek/src/model/photo_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_photo_library.dart';

void main() {
  testWidgets('permission, grid, file name filter, and albums', (tester) async {
    final library = FakePhotoLibrary();
    await tester.pumpWidget(AlbumseekApp(library: library));
    await _until(tester, find.text('Allow photo access'));

    expect(find.text('Photos stay on this phone').hitTestable(), findsOneWidget);
    expect(find.text('Choose photos').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(find.text('Allow photo access').hitTestable(), findsOneWidget);

    library.access = PhotoAccess.granted;
    library.albums = const [
      AlbumSummary(id: 'camera', name: 'Camera', count: 2),
    ];
    library.stored = [
      PhotoRecord(
        id: 'img',
        title: 'IMG_1.jpg',
        createdAt: DateTime.now(),
      ),
      PhotoRecord(
        id: 'shot',
        title: 'Screenshot.png',
        createdAt: DateTime(2020, 1, 1, 9),
      ),
    ];

    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.tap(find.text('Allow photo access').hitTestable());
    await _until(tester, find.byKey(const ValueKey<String>('img')).hitTestable());
    expect(find.byKey(const ValueKey<String>('shot')).hitTestable(), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'img');
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('img')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('shot')).hitTestable(), findsNothing);
    expect(
      find.text('Matches file names and dates on this phone.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('img')).hitTestable(), findsOneWidget);

    await tester.tap(find.text('Collections'));
    await tester.pump();
    expect(
      find.text('Face grouping will run on this phone in a later build.'),
      findsOneWidget,
    );
    expect(find.text('Camera'), findsOneWidget);

    await tester.tap(find.text('Camera'));
    await _until(tester, find.byKey(const ValueKey<String>('shot')).hitTestable());
    expect(find.byKey(const ValueKey<String>('img')).hitTestable(), findsOneWidget);
  });

  testWidgets('opening settings is offered after access is denied', (tester) async {
    final library = FakePhotoLibrary();
    await tester.pumpWidget(AlbumseekApp(library: library));
    await _until(tester, find.text('Allow photo access'));

    await tester.tap(find.text('Allow photo access').hitTestable());
    await _until(tester, find.text('Open settings').hitTestable());

    await tester.tap(find.text('Open settings').hitTestable());
    await tester.pump();
    expect(library.settingsOpens, 1);
    expect(find.text('Photo access is off'), findsWidgets);
  });
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Could not find $finder');
}
