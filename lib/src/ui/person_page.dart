import 'package:material_ui/material_ui.dart';

import '../data/photo_library.dart';
import '../model/photo_record.dart';
import '../runtime/album_index.dart';
import 'format.dart';
import 'photo_grid.dart';

class PersonPage extends StatelessWidget {
  const PersonPage({
    required this.person,
    required this.photos,
    required this.library,
    required this.index,
    super.key,
  });

  final PersonSummary person;
  final List<PhotoRecord> photos;
  final PhotoLibrary library;
  final AlbumIndex index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(person.title)),
      body: photos.isEmpty
          ? const Center(child: Text('No photos for this person.'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '${photoCountLabel(photos.length)}, including group photos',
                  ),
                ),
                Expanded(
                  child: PhotoGrid(
                    photos: photos,
                    library: library,
                    index: index,
                    labelOf: index.labelFor,
                    lookup: (id) => _find(photos, id),
                  ),
                ),
              ],
            ),
    );
  }
}

PhotoRecord? _find(List<PhotoRecord> photos, String id) {
  for (final photo in photos) {
    if (photo.id == id) {
      return photo;
    }
  }
  return null;
}
