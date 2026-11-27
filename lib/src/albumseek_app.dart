import 'package:material_ui/material_ui.dart';

import 'data/photo_library.dart';
import 'runtime/album_index.dart';
import 'state/library_controller.dart';
import 'ui/albumseek_theme.dart';
import 'ui/shell_page.dart';

class AlbumseekApp extends StatefulWidget {
  const AlbumseekApp({required this.library, this.index, super.key});

  final PhotoLibrary library;
  final AlbumIndex? index;

  @override
  State<AlbumseekApp> createState() => _AlbumseekAppState();
}

class _AlbumseekAppState extends State<AlbumseekApp>
    with WidgetsBindingObserver {
  late final LibraryController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = LibraryController(library: widget.library);
    _controller.addListener(_onLibrary);
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onLibrary);
    _controller.dispose();
    widget.index?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.onAppResumed();
      final index = widget.index;
      if (index != null && index.searchModelsReady) {
        index.start();
      }
    } else if (state == AppLifecycleState.paused) {
      widget.index?.pause();
    }
  }

  void _onLibrary() {
    if (_controller.status == LibraryStatus.ready) {
      widget.index?.noteLibrary(_controller.photos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Albumseek',
      theme: AlbumseekTheme.light(),
      darkTheme: AlbumseekTheme.dark(),
      home: ShellPage(controller: _controller, index: widget.index),
    );
  }
}
