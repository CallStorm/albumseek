import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../model/album_summary.dart';
import '../model/photo_record.dart';
import 'photo_library.dart';

/// MediaStore library, with the system document picker as a fallback.
///
/// Permissions requested on Android are only those needed to list images:
/// `READ_MEDIA_IMAGES`, `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14 selected
/// photos), and `READ_EXTERNAL_STORAGE` on Android 12 and older. Location,
/// video, and audio permissions are not requested.
///
/// [ImagePicker] is left on its default path, which uses `ACTION_GET_CONTENT`
/// below Android 16. That intent works when the system photo picker is
/// missing, including on Huawei phones without Google Play services. The
/// optional Play services photo-picker metadata merged by the plugin is
/// removed in the app manifest.
class DevicePhotoLibrary implements PhotoLibrary {
  DevicePhotoLibrary({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final Map<String, AssetEntity> _assets = <String, AssetEntity>{};
  final Map<String, String> _files = <String, String>{};
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  AssetPathEntity? _allAlbum;
  var _watching = false;

  static const PermissionRequestOption _imageAccess = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  static final FilterOptionGroup _filter = FilterOptionGroup(
    imageOption: const FilterOption(
      needTitle: true,
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
    orders: const <OrderOption>[OrderOption()],
  );

  @override
  Future<PhotoAccess> currentAccess() {
    return _guard(() async {
      final state = await PhotoManager.getPermissionState(
        requestOption: _imageAccess,
      );
      return _mapAccess(state);
    });
  }

  @override
  Future<PhotoAccess> requestAccess() {
    return _guard(() async {
      final state = await PhotoManager.requestPermissionExtend(
        requestOption: _imageAccess,
      );
      return _mapAccess(state);
    });
  }

  @override
  Future<void> openSystemSettings() {
    return PhotoManager.openSetting();
  }

  @override
  Future<void> expandLimitedSelection() {
    return _guard(() async {
      await PhotoManager.presentLimited(type: RequestType.image);
    });
  }

  @override
  Future<void> startWatchingLibrary() async {
    if (_watching) {
      return;
    }
    _watching = true;
    PhotoManager.addChangeCallback(_onLibraryChanged);
    await PhotoManager.startChangeNotify();
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
    return _guard(() async {
      final album = await _requireAllAlbum(refresh: page == 0);
      return _page(album, page: page, pageSize: pageSize);
    });
  }

  @override
  Future<List<AlbumSummary>> listAlbums() {
    return _guard(() async {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: false,
        onlyAll: false,
        filterOption: _filter,
      );
      final albums = <AlbumSummary>[];
      for (final path in paths) {
        if (path.isAll) {
          continue;
        }
        final count = await path.assetCountAsync;
        if (count <= 0) {
          continue;
        }
        final name = path.name.trim();
        albums.add(
          AlbumSummary(
            id: path.id,
            name: name.isEmpty ? 'Album' : name,
            count: count,
          ),
        );
      }
      albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return albums;
    });
  }

  @override
  Future<LibrarySnapshot> loadAlbum({
    required String albumId,
    required int page,
    required int pageSize,
  }) {
    return _guard(() async {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: _filter,
      );
      AssetPathEntity? album;
      for (final path in paths) {
        if (path.id == albumId) {
          album = path;
          break;
        }
      }
      if (album == null) {
        throw PhotoLibraryException('That album is no longer on this phone.');
      }
      return _page(album, page: page, pageSize: pageSize);
    });
  }

  @override
  Future<List<PhotoRecord>> pickImages() async {
    try {
      final files = await _picker.pickMultiImage(requestFullMetadata: false);
      final photos = <PhotoRecord>[];
      for (final file in files) {
        final modified = await _modifiedOrNow(file.path);
        final id = 'picked:${file.path}';
        _files[id] = file.path;
        photos.add(
          PhotoRecord(
            id: id,
            title: file.name,
            createdAt: modified,
          ),
        );
      }
      return photos;
    } on PlatformException catch (error, stack) {
      debugPrint('Albumseek picker failed: ${error.code} ${error.message}\n$stack');
      throw PhotoLibraryException(
        'The system photo picker is not available on this phone. '
        'Allow photo access in Settings to browse pictures stored on the device.',
      );
    }
  }

  @override
  Widget thumbnailOf(PhotoRecord photo) {
    final asset = _assets[photo.id];
    if (asset != null) {
      return AssetEntityImage(
        asset,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(300),
        thumbnailFormat: ThumbnailFormat.jpeg,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: _brokenImage,
      );
    }
    final path = _files[photo.id];
    if (path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 400,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: _brokenImage,
      );
    }
    return const ColoredBox(color: Color(0xFFE4E0D8));
  }

  @override
  Widget fullImageOf(PhotoRecord photo) {
    final asset = _assets[photo.id];
    if (asset != null) {
      return AssetEntityImage(
        asset,
        isOriginal: true,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        loadingBuilder: _loadingImage,
        errorBuilder: _brokenImage,
      );
    }
    final path = _files[photo.id];
    if (path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: _brokenImage,
      );
    }
    return const Center(child: Icon(Icons.image_not_supported_outlined));
  }

  Future<LibrarySnapshot> _page(
    AssetPathEntity album, {
    required int page,
    required int pageSize,
  }) async {
    final assets = await album.getAssetListPaged(page: page, size: pageSize);
    final total = await album.assetCountAsync;
    final photos = <PhotoRecord>[];
    for (final asset in assets) {
      _assets[asset.id] = asset;
      photos.add(_recordFromAsset(asset));
    }
    return LibrarySnapshot(
      photos: photos,
      totalCount: total,
      isLastPage: assets.length < pageSize,
    );
  }

  Future<AssetPathEntity> _requireAllAlbum({required bool refresh}) async {
    if (refresh) {
      _allAlbum = null;
    }
    final cached = _allAlbum;
    if (cached != null) {
      return cached;
    }
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      onlyAll: true,
      filterOption: _filter,
    );
    if (paths.isEmpty) {
      throw PhotoLibraryException('This phone did not return an image library.');
    }
    _allAlbum = paths.first;
    return paths.first;
  }

  PhotoRecord _recordFromAsset(AssetEntity asset) {
    final title = (asset.title ?? '').trim();
    return PhotoRecord(
      id: asset.id,
      title: title,
      createdAt: asset.createDateTime,
      width: asset.width,
      height: asset.height,
    );
  }

  void _onLibraryChanged(MethodCall call) {
    _allAlbum = null;
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  PhotoAccess _mapAccess(PermissionState state) {
    switch (state) {
      case PermissionState.authorized:
        return PhotoAccess.granted;
      case PermissionState.limited:
        return PhotoAccess.limited;
      case PermissionState.denied:
      case PermissionState.restricted:
      case PermissionState.notDetermined:
        return PhotoAccess.denied;
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PhotoLibraryException {
      rethrow;
    } catch (error, stack) {
      debugPrint('Albumseek photo library failed: $error\n$stack');
      throw PhotoLibraryException('The photo library could not be read.');
    }
  }

  static Future<DateTime> _modifiedOrNow(String path) async {
    try {
      return await File(path).lastModified();
    } catch (_) {
      return DateTime.now();
    }
  }
}

Widget _brokenImage(BuildContext context, Object error, StackTrace? stack) {
  return const ColoredBox(
    color: Color(0xFFE4E0D8),
    child: Center(child: Icon(Icons.image_not_supported_outlined)),
  );
}

Widget _loadingImage(BuildContext context, Widget child, ImageChunkEvent? progress) {
  if (progress == null) {
    return child;
  }
  return const Center(child: CircularProgressIndicator());
}
