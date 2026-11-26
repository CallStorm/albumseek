/// A real album (MediaStore bucket) on the device.
class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.name,
    required this.count,
  });

  final String id;
  final String name;
  final int count;
}
