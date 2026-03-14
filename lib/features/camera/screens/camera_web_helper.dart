/// Web stub — local file system is not available on web.
library;

import 'dart:typed_data';

Future<String?> saveImageToLocalStorage(Uint8List bytes) async {
  // Web does not support local file storage; images are kept in memory only.
  return null;
}
