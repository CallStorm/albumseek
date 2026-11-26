import 'package:material_ui/material_ui.dart';

import '../model/library_query.dart';
import '../state/library_controller.dart';
import 'access_gate.dart';
import 'format.dart';
import 'photo_grid.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({required this.controller, super.key});

  final LibraryController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: AccessGate(
        controller: controller,
        ready: (context) => _SearchBody(controller: controller),
      ),
    );
  }
}

class _SearchBody extends StatefulWidget {
  const _SearchBody({required this.controller});

  final LibraryController controller;

  @override
  State<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<_SearchBody> {
  final TextEditingController _text = TextEditingController();
  DateScope _scope = DateScope.any;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final query = LibraryQuery(filename: _text.text, dateScope: _scope);
        final results = controller.apply(query);
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _text,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'File name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  helperText: 'Matches file names and dates on this phone.',
                ),
                onChanged: (_) => setState(() {}),
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
                    ),
            ),
          ],
        );
      },
    );
  }
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
