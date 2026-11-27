import 'package:material_ui/material_ui.dart';

import '../docs/document_fields.dart';
import '../model/photo_record.dart';
import '../runtime/album_index.dart';
import '../state/library_controller.dart';
import 'access_gate.dart';
import 'album_page.dart';
import 'format.dart';
import 'person_page.dart';

class CollectionsPage extends StatelessWidget {
  const CollectionsPage({required this.controller, this.index, super.key});

  final LibraryController controller;
  final AlbumIndex? index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      body: AccessGate(
        controller: controller,
        ready: (context) =>
            _CollectionsBody(controller: controller, index: index),
      ),
    );
  }
}

class _CollectionsBody extends StatelessWidget {
  const _CollectionsBody({required this.controller, this.index});

  final LibraryController controller;
  final AlbumIndex? index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final albums = controller.albums;
        return ListView(
          children: [
            if (index == null)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('People', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Download YuNet and AdaFace, then index, to group faces.',
                      ),
                    ],
                  ),
                ),
              )
            else
              ListenableBuilder(
                listenable: index!,
                builder: (context, _) {
                  final people = index!.people();
                  final documents = [
                    for (final photo in controller.photos)
                      if (index!.documentKind(photo.id) case final kind?)
                        (photo: photo, kind: kind),
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'People',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (!index!.faceModelsReady)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Text(
                            'Download YuNet and AdaFace from Models, then index.',
                          ),
                        )
                      else if (people.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Text(
                            'No faces yet. Indexing adds people, including group photos.',
                          ),
                        ),
                      for (final person in people)
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(person.title),
                          subtitle: Text(
                            photoCountLabel(person.photoIds.length),
                          ),
                          onTap: () {
                            final photos = [
                              for (final id in person.photoIds)
                                ?_find(controller.photos, id),
                            ];
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => PersonPage(
                                  person: person,
                                  photos: photos,
                                  library: controller.library,
                                  index: index!,
                                ),
                              ),
                            );
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          'Documents',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (documents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Text(
                            'ID cards and household registers show up here after indexing.',
                          ),
                        ),
                      for (final item in documents)
                        ListTile(
                          leading: const Icon(Icons.badge_outlined),
                          title: Text(
                            item.photo.title.isEmpty
                                ? kindLabel(item.kind)
                                : item.photo.title,
                          ),
                          subtitle: Text(
                            index!
                                    .documentFields(item.photo.id)
                                    ?.entries
                                    .map(
                                      (entry) => '${entry.key} ${entry.value}',
                                    )
                                    .take(3)
                                    .join(' · ') ??
                                kindLabel(item.kind),
                          ),
                        ),
                    ],
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Albums', style: theme.textTheme.titleMedium),
            ),
            if (controller.usingSystemPicker)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Allow photo access to list albums from the phone library.',
                ),
              )
            else if (albums.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('No albums were found.'),
              ),
            for (final album in albums)
              ListTile(
                leading: const Icon(Icons.photo_album_outlined),
                title: Text(album.name),
                subtitle: Text(photoCountLabel(album.count)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          AlbumPage(library: controller.library, album: album),
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

PhotoRecord? _find(List<PhotoRecord> photos, String id) {
  for (final photo in photos) {
    if (photo.id == id) {
      return photo;
    }
  }
  return null;
}
