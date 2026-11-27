import 'package:material_ui/material_ui.dart';

import '../data/photo_library.dart';
import '../model/album_summary.dart';
import '../model/photo_record.dart';
import 'format.dart';
import 'photo_grid.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({
    required this.library,
    required this.album,
    super.key,
  });

  final PhotoLibrary library;
  final AlbumSummary album;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final List<PhotoRecord> _photos = <PhotoRecord>[];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    if (!_loading || _error != null || _photos.isNotEmpty) {
      setState(() {
        _loading = true;
        _error = null;
        _photos.clear();
      });
    }
    try {
      var page = 0;
      while (mounted && page < 2000) {
        final snapshot = await widget.library.loadAlbum(
          albumId: widget.album.id,
          page: page,
          pageSize: 160,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _photos.addAll(snapshot.photos);
          _loading = !(snapshot.isLastPage || snapshot.photos.isEmpty);
        });
        if (snapshot.isLastPage || snapshot.photos.isEmpty) {
          return;
        }
        page += 1;
      }
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error is PhotoLibraryException
            ? error.message
            : 'That album could not be read.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.name),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null && _photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_loading && _photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_photos.isEmpty) {
      return const Center(child: Text('This album has no photos.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(photoCountLabel(_photos.length)),
        ),
        Expanded(
          child: PhotoGrid(photos: _photos, library: widget.library),
        ),
      ],
    );
  }
}
