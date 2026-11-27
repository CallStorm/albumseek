import 'package:material_ui/material_ui.dart';

import '../data/photo_library.dart';
import '../model/photo_record.dart';
import '../runtime/album_index.dart';
import 'photo_viewer_page.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    required this.photos,
    required this.library,
    this.onRefresh,
    this.labelOf,
    this.index,
    this.lookup,
    super.key,
  });

  final List<PhotoRecord> photos;
  final PhotoLibrary library;
  final Future<void> Function()? onRefresh;
  final String? Function(String photoId)? labelOf;
  final AlbumIndex? index;
  final PhotoRecord? Function(String id)? lookup;

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
      itemBuilder: (context, itemIndex) {
        final photo = photos[itemIndex];
        return _PhotoTile(
          photo: photo,
          library: library,
          label: labelOf?.call(photo.id),
          index: index,
          lookup: lookup,
        );
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
  const _PhotoTile({
    required this.photo,
    required this.library,
    this.label,
    this.index,
    this.lookup,
  });

  final PhotoRecord photo;
  final PhotoLibrary library;
  final String? label;
  final AlbumIndex? index;
  final PhotoRecord? Function(String id)? lookup;

  @override
  Widget build(BuildContext context) {
    final semantics = photo.title.isEmpty ? 'Photo' : photo.title;
    final caption = label;
    return Semantics(
      label: semantics,
      button: true,
      child: GestureDetector(
        key: ValueKey<String>(photo.id),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => PhotoViewerPage(
                photo: photo,
                library: library,
                index: index,
                lookup: lookup,
              ),
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFE4E0D8)),
            library.thumbnailOf(photo),
            if (caption != null && caption.isNotEmpty)
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  color: const Color(0xCC1F5C57),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
