import 'package:flutter/widgets.dart';

import 'src/albumseek_app.dart';
import 'src/data/device_photo_library.dart';
import 'src/runtime/album_index.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final library = DevicePhotoLibrary();
  final index = await AlbumIndex.open(library);
  runApp(AlbumseekApp(library: library, index: index));
}
