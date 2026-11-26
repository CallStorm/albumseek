/// One image Albumseek can show.
///
/// This is plain data so search filters can run without a platform plugin.
class PhotoRecord {
  const PhotoRecord({
    required this.id,
    required this.title,
    required this.createdAt,
    this.width = 0,
    this.height = 0,
  });

  /// Stable id from MediaStore, or a picker-local id.
  final String id;

  /// File name, such as `IMG_20260101_120000.jpg`. Empty when the device
  /// does not provide one.
  final String title;

  /// Local creation time. Picked files use the file's last modified time.
  final DateTime createdAt;

  final int width;
  final int height;
}
