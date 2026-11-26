import 'package:material_ui/material_ui.dart';

import 'data/photo_library.dart';
import 'state/library_controller.dart';
import 'ui/albumseek_theme.dart';
import 'ui/shell_page.dart';

class AlbumseekApp extends StatefulWidget {
  const AlbumseekApp({required this.library, super.key});

  final PhotoLibrary library;

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
    _controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Albumseek',
      theme: AlbumseekTheme.light(),
      darkTheme: AlbumseekTheme.dark(),
      home: ShellPage(controller: _controller),
    );
  }
}
