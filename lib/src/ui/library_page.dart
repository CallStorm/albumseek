import 'package:material_ui/material_ui.dart';

import '../model/photo_record.dart';
import '../runtime/album_index.dart';
import '../state/library_controller.dart';
import 'access_gate.dart';
import 'format.dart';
import 'models_page.dart';
import 'photo_grid.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({required this.controller, this.index, super.key});

  final LibraryController controller;
  final AlbumIndex? index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (!controller.indexing) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AccessGate(
        controller: controller,
        ready: (context) => _LibraryBody(controller: controller, index: index),
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({required this.controller, this.index});

  final LibraryController controller;
  final AlbumIndex? index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.indexing && controller.photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index != null) _IndexBanner(index: index!, controller: controller),
        if (controller.errorMessage != null)
          Material(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(controller.errorMessage!),
            ),
          ),
        if (controller.accessLimited && !controller.usingSystemPicker)
          Material(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Only selected photos are visible.'),
                  ),
                  TextButton(
                    onPressed: controller.selectMorePhotos,
                    child: const Text('Choose more'),
                  ),
                ],
              ),
            ),
          ),
        if (controller.usingSystemPicker)
          Material(
            color: theme.colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Showing photos chosen with the system picker.'),
            ),
          ),
        if (controller.indexing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Reading the library · ${photoCountLabel(controller.indexedCount)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: controller.photos.isEmpty
              ? _EmptyLibrary(controller: controller)
              : PhotoGrid(
                  photos: controller.photos,
                  library: controller.library,
                  onRefresh: controller.refresh,
                  index: index,
                  labelOf: index?.labelFor,
                  lookup: (id) => _findPhoto(controller.photos, id),
                ),
        ),
      ],
    );
  }
}

class _IndexBanner extends StatelessWidget {
  const _IndexBanner({required this.index, required this.controller});

  final AlbumIndex index;
  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: index,
      builder: (context, _) {
        final stage = switch (index.stage) {
          IndexStage.readingText => 'reading text',
          IndexStage.embedding => 'embedding',
          IndexStage.faces => 'finding faces',
          IndexStage.documents => 'reading documents',
          IndexStage.naming => 'naming',
          IndexStage.idle => 'idle',
        };
        final ready = index.searchModelsReady;
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready
                      ? (index.running
                            ? 'Indexing ${index.done} / ${index.total} · $stage'
                            : 'Indexed ${index.done} / ${index.total}')
                      : 'Download on-device models to search text and pictures.',
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => ModelsPage(index: index),
                          ),
                        );
                      },
                      child: const Text('Models'),
                    ),
                    if (ready && index.running && !index.paused)
                      TextButton(
                        onPressed: index.pause,
                        child: const Text('Pause'),
                      ),
                    if (ready && (!index.running || index.paused))
                      TextButton(
                        onPressed: () {
                          index.noteLibrary(controller.photos);
                          index.start();
                        },
                        child: const Text('Index'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

PhotoRecord? _findPhoto(List<PhotoRecord> photos, String id) {
  for (final photo in photos) {
    if (photo.id == id) {
      return photo;
    }
  }
  return null;
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.photo_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No photos to show',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'The library on this phone has no images Albumseek can read.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            child: OutlinedButton(
              onPressed: controller.pickWithSystemPicker,
              child: const Text('Choose photos'),
            ),
          ),
        ],
      ),
    );
  }
}
