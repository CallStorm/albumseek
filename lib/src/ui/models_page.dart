import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/model_catalog.dart';
import '../runtime/album_index.dart';

class ModelsPage extends StatelessWidget {
  const ModelsPage({required this.index, super.key});

  final AlbumIndex index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On-device models')),
      body: ListenableBuilder(
        listenable: index,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Search, faces, and documents run on this phone. Download or import a file when you want that feature. Weights are not inside the app, and recognition does not call a server.',
                ),
              ),
              if (index.startupError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(index.startupError!),
                ),
              if (index.message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(index.message!),
                ),
              for (var i = 0; i < modelCatalog.length; i++) ...[
                if (i == 0 ||
                    modelSection(modelCatalog[i]) !=
                        modelSection(modelCatalog[i - 1]))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      modelSection(modelCatalog[i]),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                _ModelTile(index: index, spec: modelCatalog[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.index, required this.spec});

  final AlbumIndex index;
  final ModelFile spec;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(spec.fileName),
      subtitle: Text(
        '${spec.role}\n${spec.license}'
        '${index.store.isReady(spec) ? '\nReady' : '\nNot on this phone'}',
      ),
      isThreeLine: true,
      trailing: index.activeDownloadId == spec.id
          ? SizedBox(
              width: 72,
              child: Text(
                index.downloadTotal == null
                    ? '${index.downloadReceived ~/ 1000000} MB'
                    : '${(100 * index.downloadReceived / index.downloadTotal!).round()}%',
                textAlign: TextAlign.end,
              ),
            )
          : PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'download') {
                  await index.download(spec);
                } else {
                  final picked = await FilePicker.pickFiles();
                  final path = picked.isEmpty ? null : picked.single.path;
                  if (path != null) {
                    await index.importFile(spec, path);
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'download', child: Text('Download')),
                PopupMenuItem(value: 'import', child: Text('Import')),
              ],
            ),
    );
  }
}
