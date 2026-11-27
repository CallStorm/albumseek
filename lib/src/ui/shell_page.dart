import 'package:material_ui/material_ui.dart';

import '../runtime/album_index.dart';
import '../state/library_controller.dart';
import 'collections_page.dart';
import 'library_page.dart';
import 'search_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({required this.controller, this.index, super.key});

  final LibraryController controller;
  final AlbumIndex? index;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          LibraryPage(controller: widget.controller, index: widget.index),
          SearchPage(controller: widget.controller, index: widget.index),
          CollectionsPage(controller: widget.controller, index: widget.index),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Library',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.photo_album_outlined),
            selectedIcon: Icon(Icons.photo_album),
            label: 'Collections',
          ),
        ],
      ),
    );
  }
}
