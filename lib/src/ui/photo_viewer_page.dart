import 'package:material_ui/material_ui.dart';

import '../data/photo_library.dart';
import '../model/photo_record.dart';
import '../runtime/album_index.dart';
import 'format.dart';

class PhotoViewerPage extends StatelessWidget {
  const PhotoViewerPage({
    required this.photo,
    required this.library,
    this.index,
    this.lookup,
    super.key,
  });

  final PhotoRecord photo;
  final PhotoLibrary library;
  final AlbumIndex? index;
  final PhotoRecord? Function(String id)? lookup;

  @override
  Widget build(BuildContext context) {
    final date = formatPhotoDate(photo.createdAt);
    final title = photo.title.isEmpty ? 'Photo' : photo.title;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (date != null)
              Text(
                date,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (index?.labelFor(photo.id) case final label?)
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (index?.documentFields(photo.id) case final fields?)
              Text(
                fields.entries
                    .take(4)
                    .map((entry) => '${entry.key} ${entry.value}')
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
      bottomNavigationBar: index == null
          ? null
          : SafeArea(
              child: TextButton(
                onPressed: () => _showSimilar(context),
                child: const Text('Similar photos'),
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: library.fullImageOf(photo),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSimilar(BuildContext context) async {
    final current = index;
    if (current == null) {
      return;
    }
    final hits = await current.similar(photo.id);
    if (!context.mounted) {
      return;
    }
    if (hits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Similar photos appear after this one is embedded.'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            for (final hit in hits)
              ListTile(
                title: Text(lookup?.call(hit.photoId)?.title ?? 'Photo'),
                subtitle: Text(hit.label ?? hit.snippet ?? ''),
                onTap: () {
                  final match = lookup?.call(hit.photoId);
                  if (match == null) {
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => PhotoViewerPage(
                        photo: match,
                        library: library,
                        index: current,
                        lookup: lookup,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
