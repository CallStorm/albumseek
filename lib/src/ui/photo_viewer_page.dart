import 'package:material_ui/material_ui.dart';

import '../data/photo_library.dart';
import '../model/photo_record.dart';
import 'format.dart';

class PhotoViewerPage extends StatelessWidget {
  const PhotoViewerPage({
    required this.photo,
    required this.library,
    super.key,
  });

  final PhotoRecord photo;
  final PhotoLibrary library;

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
          ],
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
}
