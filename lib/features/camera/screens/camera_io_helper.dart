/// IO (mobile/desktop) implementation of local image saving.
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> saveImageToLocalStorage(Uint8List bytes) async {
  final directory = await getApplicationDocumentsDirectory();
  final imagePath = '${directory.path}/food_images';
  await Directory(imagePath).create(recursive: true);
  final fileName = 'food_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final file = File('$imagePath/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
