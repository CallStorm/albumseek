import 'package:albumseek/src/model/library_query.dart';
import 'package:albumseek/src/model/photo_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 6, 15, 15, 30);
  final photos = <PhotoRecord>[
    _photo('today', 'IMG_A.JPG', DateTime(2026, 6, 15, 1)),
    _photo('week-edge', 'IMG_B.jpg', DateTime(2026, 6, 9)),
    _photo('before-week', 'IMG_C.jpg', DateTime(2026, 6, 8, 23)),
    _photo('month-edge', 'note.png', DateTime(2026, 5, 17)),
    _photo('before-month', 'old.png', DateTime(2026, 5, 16, 12)),
    _photo('year', 'year.jpg', DateTime(2026, 1, 1)),
    _photo('last-year', 'last.jpg', DateTime(2025, 12, 31, 23)),
    _photo('untitled', '', DateTime(2026, 6, 15, 8)),
  ];

  List<String> ids(LibraryQuery query) {
    return query.apply(photos, now).map((photo) => photo.id).toList();
  }

  test('empty file name keeps every photo in the date range', () {
    expect(ids(const LibraryQuery()), [
      'today',
      'week-edge',
      'before-week',
      'month-edge',
      'before-month',
      'year',
      'last-year',
      'untitled',
    ]);
    expect(
      ids(const LibraryQuery(filename: '   ')),
      ids(const LibraryQuery()),
    );
  });

  test('file name match is case-insensitive and ignores surrounding spaces', () {
    expect(ids(const LibraryQuery(filename: ' img_a ')), ['today']);
    expect(ids(const LibraryQuery(filename: 'NOTE')), ['month-edge']);
    expect(ids(const LibraryQuery(filename: 'missing')), isEmpty);
    expect(ids(const LibraryQuery(filename: 'img')), [
      'today',
      'week-edge',
      'before-week',
    ]);
  });

  test('date scopes use local calendar days', () {
    expect(ids(const LibraryQuery(dateScope: DateScope.today)), [
      'today',
      'untitled',
    ]);
    expect(ids(const LibraryQuery(dateScope: DateScope.last7Days)), [
      'today',
      'week-edge',
      'untitled',
    ]);
    expect(ids(const LibraryQuery(dateScope: DateScope.last30Days)), [
      'today',
      'week-edge',
      'before-week',
      'month-edge',
      'untitled',
    ]);
    expect(ids(const LibraryQuery(dateScope: DateScope.thisYear)), [
      'today',
      'week-edge',
      'before-week',
      'month-edge',
      'before-month',
      'year',
      'untitled',
    ]);
  });

  test('file name and date apply together', () {
    expect(
      ids(
        const LibraryQuery(filename: 'img', dateScope: DateScope.today),
      ),
      ['today'],
    );
  });
}

PhotoRecord _photo(String id, String title, DateTime createdAt) {
  return PhotoRecord(id: id, title: title, createdAt: createdAt);
}
