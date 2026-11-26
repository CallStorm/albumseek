import 'package:material_ui/material_ui.dart';

import '../state/library_controller.dart';
import 'access_gate.dart';
import 'format.dart';
import 'photo_grid.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({required this.controller, super.key});

  final LibraryController controller;

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
        ready: (context) => _LibraryBody(controller: controller),
      ),
    );
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({required this.controller});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.indexing && controller.photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              child: Text(
                'Showing photos chosen with the system picker.',
              ),
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
                ),
        ),
      ],
    );
  }
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
