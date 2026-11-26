import 'package:material_ui/material_ui.dart';

import '../state/library_controller.dart';
import 'access_gate.dart';
import 'album_page.dart';
import 'format.dart';

class CollectionsPage extends StatelessWidget {
  const CollectionsPage({required this.controller, super.key});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      body: AccessGate(
        controller: controller,
        ready: (context) => _CollectionsBody(controller: controller),
      ),
    );
  }
}

class _CollectionsBody extends StatelessWidget {
  const _CollectionsBody({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final albums = controller.albums;
        return ListView(
          children: [
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
                      'Face grouping will run on this phone in a later build.',
                    ),
                  ],
                ),
              ),
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
                      builder: (context) => AlbumPage(
                        library: controller.library,
                        album: album,
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
