/// Meal thumbnail image widget — loads from local file on mobile, placeholder on web.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Conditional import: dart:io only on non-web
import 'package:smart_diet_ai/features/dashboard/widgets/meal_image_io.dart'
    if (dart.library.html) 'package:smart_diet_ai/features/dashboard/widgets/meal_image_web.dart';

class MealThumbnail extends StatelessWidget {
  final String? localImagePath;
  final String mealType;
  final double size;

  const MealThumbnail({
    super.key,
    this.localImagePath,
    required this.mealType,
    this.size = 64,
  });

  Color _mealTypeColor() {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Colors.amber;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.indigo;
      case 'snack':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }

  IconData _mealTypeIcon() {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _mealTypeColor();

    // Try loading from local file on non-web platforms
    if (!kIsWeb && localImagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: loadMealImage(localImagePath!, size),
        ),
      );
    }

    // Fallback: colored icon with clay feel
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(_mealTypeIcon(), color: color, size: size * 0.5),
    );
  }
}
