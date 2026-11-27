import 'dart:typed_data';

import 'package:albumseek/src/data/photo_library.dart';
import 'package:albumseek/src/model/album_summary.dart';
import 'package:albumseek/src/model/photo_record.dart';
import 'package:material_ui/material_ui.dart';

class FakePhotoLibrary implements PhotoLibrary {
  PhotoAccess access = PhotoAccess.denied;
  List<PhotoRecord> stored = <PhotoRecord>[];
  List<AlbumSummary> albums = <AlbumSummary>[];
  List<PhotoRecord> pickerResult = <PhotoRecord>[];
  bool failLoad = false;
  bool failPicker = false;
  int requestCount = 0;
  int settingsOpens = 0;
  int limitedOpens = 0;
  int watchStarts = 0;
  int loadCalls = 0;

  final List<VoidCallback> _listeners = <VoidCallback>[];

  void emitChange() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  @override
  Future<PhotoAccess> currentAccess() async => access;

  @override
  Future<PhotoAccess> requestAccess() async {
    requestCount += 1;
    return access;
  }

  @override
  Future<void> openSystemSettings() async {
    settingsOpens += 1;
  }

  @override
  Future<void> expandLimitedSelection() async {
    limitedOpens += 1;
  }

  @override
  Future<void> startWatchingLibrary() async {
    watchStarts += 1;
  }

  @override
  void addLibraryChangedListener(VoidCallback onChanged) {
    _listeners.add(onChanged);
  }

  @override
  void removeLibraryChangedListener(VoidCallback onChanged) {
    _listeners.remove(onChanged);
  }

  @override
  Future<LibrarySnapshot> loadLibrary({
    required int page,
    required int pageSize,
  }) {
    return _page(page: page, pageSize: pageSize);
  }

  @override
  Future<LibrarySnapshot> loadAlbum({
    required String albumId,
    required int page,
    required int pageSize,
  }) {
    return _page(page: page, pageSize: pageSize);
  }

  @override
  Future<List<AlbumSummary>> listAlbums() async {
    if (failLoad) {
      throw PhotoLibraryException('storage unavailable');
    }
    return albums;
  }

  @override
  Future<Uint8List?> imageBytes(PhotoRecord photo, {int maxSide = 1600}) async {
    return null;
  }

  @override
  Future<List<PhotoRecord>> pickImages() async {
    if (failPicker) {
      throw PhotoLibraryException('picker unavailable');
    }
    return pickerResult;
  }

  @override
  Widget thumbnailOf(PhotoRecord photo) {
    return const ColoredBox(color: Color(0xFFD9D3CB));
  }

  @override
  Widget fullImageOf(PhotoRecord photo) {
    return const ColoredBox(color: Color(0xFF111111));
  }

  Future<LibrarySnapshot> _page({
    required int page,
    required int pageSize,
  }) async {
    loadCalls += 1;
    if (failLoad) {
      throw PhotoLibraryException('storage unavailable');
    }
    final start = page * pageSize;
    if (start >= stored.length) {
      return LibrarySnapshot(
        photos: const <PhotoRecord>[],
        totalCount: stored.length,
        isLastPage: true,
      );
    }
    final end = start + pageSize > stored.length
        ? stored.length
        : start + pageSize;
    return LibrarySnapshot(
      photos: stored.sublist(start, end),
      totalCount: stored.length,
      isLastPage: end >= stored.length,
    );
  }
}
