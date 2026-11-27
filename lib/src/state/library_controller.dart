import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/photo_library.dart';
import '../model/album_summary.dart';
import '../model/library_query.dart';
import '../model/photo_record.dart';

/// What the shell should show for the photo library.
enum LibraryStatus {
  checking,
  needsPermission,
  denied,
  ready,
  failed,
}

/// Owns permission, paging, and the in-memory catalog the search screen filters.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required this.library,
    DateTime Function()? now,
    this.pageSize = 160,
    this.reloadDebounce = const Duration(milliseconds: 400),
  }) : _now = now ?? DateTime.now;

  final PhotoLibrary library;
  final DateTime Function() _now;

  /// Page size for MediaStore reads. Tests use a small value.
  final int pageSize;

  /// How long to wait after a media-library change before reloading.
  final Duration reloadDebounce;

  LibraryStatus status = LibraryStatus.checking;
  List<PhotoRecord> photos = const <PhotoRecord>[];
  List<AlbumSummary> albums = const <AlbumSummary>[];
  bool indexing = false;
  bool accessLimited = false;
  bool usingSystemPicker = false;
  String? errorMessage;
  int indexedCount = 0;
  int? totalCount;

  PhotoAccess? _access;
  var _started = false;
  var _permissionRequested = false;
  var _pickerOpen = false;
  var _generation = 0;
  Timer? _debounce;

  List<PhotoRecord> apply(LibraryQuery query) {
    return query.apply(photos, _now());
  }

  Future<void> start() async {
    if (!_started) {
      _started = true;
      library.addLibraryChangedListener(_onLibraryChanged);
    }
    await refresh();
  }

  /// Re-reads access, then the library when access allows it.
  Future<void> refresh() async {
    try {
      _access = await library.currentAccess();
      await _applyAccess();
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> requestAccess() async {
    status = LibraryStatus.checking;
    errorMessage = null;
    notifyListeners();
    try {
      _access = await library.requestAccess();
      _permissionRequested = true;
      await _applyAccess();
    } catch (error) {
      _permissionRequested = true;
      _fail(error);
    }
  }

  Future<void> openSettings() {
    return library.openSystemSettings();
  }

  Future<void> selectMorePhotos() async {
    try {
      await library.expandLimitedSelection();
      await _indexAll();
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> pickWithSystemPicker() async {
    final generation = ++_generation;
    _pickerOpen = true;
    errorMessage = null;
    notifyListeners();
    try {
      final picked = await library.pickImages();
      if (generation != _generation) {
        return;
      }
      if (picked.isEmpty) {
        return;
      }
      photos = List<PhotoRecord>.unmodifiable(picked);
      albums = const <AlbumSummary>[];
      indexedCount = picked.length;
      totalCount = picked.length;
      indexing = false;
      accessLimited = false;
      usingSystemPicker = true;
      status = LibraryStatus.ready;
      errorMessage = null;
      notifyListeners();
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      errorMessage = error is PhotoLibraryException
          ? error.message
          : 'The system photo picker could not be opened.';
      if (status != LibraryStatus.ready && status != LibraryStatus.failed) {
        status = _permissionRequested
            ? LibraryStatus.denied
            : LibraryStatus.needsPermission;
      }
      notifyListeners();
    } finally {
      _pickerOpen = false;
    }
  }

  /// Called when the app returns to the foreground.
  ///
  /// Skipped while the system picker is open so a resume does not wipe the
  /// photos the user just chose.
  Future<void> onAppResumed() async {
    if (_pickerOpen || status == LibraryStatus.checking) {
      return;
    }
    await refresh();
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    if (_started) {
      library.removeLibraryChangedListener(_onLibraryChanged);
    }
    super.dispose();
  }

  Future<void> _applyAccess() async {
    accessLimited = _access == PhotoAccess.limited;
    if (_access == PhotoAccess.granted || _access == PhotoAccess.limited) {
      await library.startWatchingLibrary();
      await _indexAll();
      return;
    }
    indexing = false;
    usingSystemPicker = false;
    photos = const <PhotoRecord>[];
    albums = const <AlbumSummary>[];
    indexedCount = 0;
    totalCount = null;
    status = _permissionRequested
        ? LibraryStatus.denied
        : LibraryStatus.needsPermission;
    notifyListeners();
  }

  Future<void> _indexAll() async {
    final generation = ++_generation;
    indexing = true;
    errorMessage = null;
    accessLimited = _access == PhotoAccess.limited;
    status = LibraryStatus.ready;
    notifyListeners();
    try {
      final albumList = await library.listAlbums();
      if (generation != _generation) {
        return;
      }
      albums = albumList;
      final loaded = <PhotoRecord>[];
      var page = 0;
      while (page < 2000) {
        final snapshot = await library.loadLibrary(
          page: page,
          pageSize: pageSize,
        );
        if (generation != _generation) {
          return;
        }
        loaded.addAll(snapshot.photos);
        photos = List<PhotoRecord>.unmodifiable(loaded);
        indexedCount = loaded.length;
        totalCount = snapshot.totalCount;
        usingSystemPicker = false;
        final done =
            snapshot.isLastPage ||
            snapshot.photos.isEmpty ||
            (snapshot.totalCount > 0 && loaded.length >= snapshot.totalCount);
        indexing = !done;
        notifyListeners();
        if (done) {
          return;
        }
        page += 1;
      }
      indexing = false;
      notifyListeners();
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      _fail(error);
    }
  }

  void _onLibraryChanged() {
    if (_pickerOpen || usingSystemPicker) {
      return;
    }
    if (_access != PhotoAccess.granted && _access != PhotoAccess.limited) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(reloadDebounce, () {
      unawaited(_indexAll());
    });
  }

  void _fail(Object error) {
    debugPrint('Albumseek library error: $error');
    indexing = false;
    status = LibraryStatus.failed;
    errorMessage = error is PhotoLibraryException
        ? error.message
        : 'The photo library could not be read.';
    notifyListeners();
  }
}
