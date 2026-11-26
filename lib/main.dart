import 'package:flutter/widgets.dart';

import 'src/albumseek_app.dart';
import 'src/data/device_photo_library.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AlbumseekApp(library: DevicePhotoLibrary()));
}
