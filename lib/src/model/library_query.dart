import 'photo_record.dart';

/// How far back a date filter reaches. Bounds are local calendar days.
enum DateScope {
  any,
  today,
  last7Days,
  last30Days,
  thisYear,
}

/// File-name and date filter over photos already loaded on the device.
///
/// This is not OCR or semantic search. It only looks at the file name and
/// the creation time.
class LibraryQuery {
  const LibraryQuery({
    this.filename = '',
    this.dateScope = DateScope.any,
  });

  final String filename;
  final DateScope dateScope;

  LibraryQuery copyWith({String? filename, DateScope? dateScope}) {
    return LibraryQuery(
      filename: filename ?? this.filename,
      dateScope: dateScope ?? this.dateScope,
    );
  }

  List<PhotoRecord> apply(List<PhotoRecord> photos, DateTime now) {
    final needle = filename.trim().toLowerCase();
    final start = _rangeStart(now, dateScope);
    return [
      for (final photo in photos)
        if (_nameMatches(photo.title, needle) && _dateMatches(photo, start))
          photo,
    ];
  }

  static bool _nameMatches(String title, String needle) {
    if (needle.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(needle);
  }

  static bool _dateMatches(PhotoRecord photo, DateTime? start) {
    if (start == null) {
      return true;
    }
    return !photo.createdAt.isBefore(start);
  }

  static DateTime? _rangeStart(DateTime now, DateScope scope) {
    final today = DateTime(now.year, now.month, now.day);
    switch (scope) {
      case DateScope.any:
        return null;
      case DateScope.today:
        return today;
      case DateScope.last7Days:
        return today.subtract(const Duration(days: 6));
      case DateScope.last30Days:
        return today.subtract(const Duration(days: 29));
      case DateScope.thisYear:
        return DateTime(now.year);
    }
  }
}
