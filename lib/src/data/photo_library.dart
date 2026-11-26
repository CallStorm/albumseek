import 'package:flutter/widgets.dart';

import '../model/album_summary.dart';
import '../model/photo_record.dart';

/// How much of the on-device image library Albumseek may read.
enum PhotoAccess {
  /// Every image MediaStore will list.
  granted,

  /// Android 14+ selected-photos grant.
  limited,

  /// No library access. The system picker can still return individual files.
  denied,
}

/// One page of images plus the album's reported total.
class LibrarySnapshot {
  const LibrarySnapshot({
    required this.photos,
    required this.totalCount,
    required this.isLastPage,
  });

  final List<PhotoRecord> photos;
  final int totalCount;
  final bool isLastPage;
}

/// Failure the UI can show without parsing a platform exception.
class PhotoLibraryException implements Exception {
  PhotoLibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads images that already live on the phone.
///
/// The device implementation uses MediaStore. Tests use a fake.
abstract class PhotoLibrary {
  Future<PhotoAccess> currentAccess();

  Future<PhotoAccess> requestAccess();

  Future<void> openSystemSettings();

  /// Re-opens the Android 14 selected-photos UI.
  Future<void> expandLimitedSelection();

  Future<void> startWatchingLibrary();

  void addLibraryChangedListener(VoidCallback onChanged);

  void removeLibraryChangedListener(VoidCallback onChanged);

  Future<LibrarySnapshot> loadLibrary({
    required int page,
    required int pageSize,
  });

  Future<List<AlbumSummary>> listAlbums();

  Future<LibrarySnapshot> loadAlbum({
    required String albumId,
    required int page,
    required int pageSize,
  });

  /// System picker fallback. An empty list means the user cancelled.
  Future<List<PhotoRecord>> pickImages();

  Widget thumbnailOf(PhotoRecord photo);

  Widget fullImageOf(PhotoRecord photo);
}
