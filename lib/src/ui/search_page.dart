import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../model/library_query.dart';
import '../model/photo_record.dart';
import '../runtime/album_index.dart';
import '../state/library_controller.dart';
import 'access_gate.dart';
import 'format.dart';
import 'photo_grid.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({required this.controller, this.index, super.key});

  final LibraryController controller;
  final AlbumIndex? index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: AccessGate(
        controller: controller,
        ready: (context) =>
            _SearchBody(controller: controller, index: index),
      ),
    );
  }
}

class _SearchBody extends StatefulWidget {
  const _SearchBody({required this.controller, this.index});

  final LibraryController controller;
  final AlbumIndex? index;

  @override
  State<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<_SearchBody> {
  final TextEditingController _text = TextEditingController();
  DateScope _scope = DateScope.any;
  Timer? _debounce;
  List<SearchHit> _hits = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _queryChanged() {
    setState(() {});
    _debounce?.cancel();
    final index = widget.index;
    final text = _text.text.trim();
    if (index == null || text.isEmpty) {
      _hits = const [];
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final hits = await index.search(text);
      if (!mounted || _text.text.trim() != text) {
        return;
      }
      setState(() => _hits = hits);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final query = LibraryQuery(filename: _text.text, dateScope: _scope);
        final filenameResults = controller.apply(query);
        final indexed = _indexedResults(controller.photos, filenameResults);
        final results = indexed ?? filenameResults;
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'File name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  helperText: widget.index == null
                      ? 'Matches file names and dates on this phone.'
                      : 'Matches file names, dates, text in photos, and descriptions.',
                ),
                onChanged: (_) => _queryChanged(),
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final scope in DateScope.values) ...[
                    FilterChip(
                      label: Text(_scopeLabel(scope)),
                      selected: _scope == scope,
                      onSelected: (_) => setState(() => _scope = scope),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                controller.indexing
                    ? '${photoCountLabel(results.length)} so far'
                    : photoCountLabel(results.length),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No photos match this filter.'))
                  : PhotoGrid(
                      photos: results,
                      library: controller.library,
                      index: widget.index,
                      labelOf: widget.index?.labelFor,
                      lookup: (id) => _find(controller.photos, id),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<PhotoRecord>? _indexedResults(
    List<PhotoRecord> photos,
    List<PhotoRecord> filenameResults,
  ) {
    final index = widget.index;
    if (index == null ||
        _text.text.trim().isEmpty ||
        !index.hasIndexedPhotos) {
      return null;
    }
    final byId = {for (final photo in photos) photo.id: photo};
    final matched = <PhotoRecord>[];
    for (final hit in _hits) {
      final photo = byId[hit.photoId];
      if (photo == null || !_inScope(photo)) {
        continue;
      }
      matched.add(photo);
    }
    if (matched.isEmpty) {
      return filenameResults;
    }
    return matched;
  }

  bool _inScope(PhotoRecord photo) {
    return LibraryQuery(
      dateScope: _scope,
    ).apply([photo], DateTime.now()).isNotEmpty;
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

String _scopeLabel(DateScope scope) {
  switch (scope) {
    case DateScope.any:
      return 'Any time';
    case DateScope.today:
      return 'Today';
    case DateScope.last7Days:
      return '7 days';
    case DateScope.last30Days:
      return '30 days';
    case DateScope.thisYear:
      return 'This year';
  }
}
