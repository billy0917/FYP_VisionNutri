/// IO implementation — loads image from local file path.
library;

import 'dart:io';
import 'package:flutter/material.dart';

Widget loadMealImage(String path, double size) {
  return Image.file(
    File(path),
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
  );
}
