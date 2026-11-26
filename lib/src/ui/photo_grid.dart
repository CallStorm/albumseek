import 'package:material_ui/material_ui.dart';

import '../data/photo_library.dart';
import '../model/photo_record.dart';
import 'photo_viewer_page.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    required this.photos,
    required this.library,
    this.onRefresh,
    super.key,
  });

  final List<PhotoRecord> photos;
  final PhotoLibrary library;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final grid = GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return _PhotoTile(photo: photo, library: library);
      },
    );
    final refresh = onRefresh;
    if (refresh == null) {
      return grid;
    }
    return RefreshIndicator(onRefresh: refresh, child: grid);
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.library});

  final PhotoRecord photo;
  final PhotoLibrary library;

  @override
  Widget build(BuildContext context) {
    final label = photo.title.isEmpty ? 'Photo' : photo.title;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        key: ValueKey<String>(photo.id),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  PhotoViewerPage(photo: photo, library: library),
            ),
          );
        },
        child: ColoredBox(
          color: const Color(0xFFE4E0D8),
          child: library.thumbnailOf(photo),
        ),
      ),
    );
  }
}
