/// SmartDiet AI - Volume Estimation Service
///
/// Calls the backend Depth Anything V2 endpoint to estimate food volume
/// from a single image. The result is injected into the RAG pipeline as
/// additional context for better portion-size estimation.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_diet_ai/core/config/app_config.dart';

/// Parsed result from the Depth Anything V2 volume estimation endpoint.
class VolumeEstimationResult {
  final double volumeMl;
  final double foodAreaCm2;
  final double avgHeightCm;
  final double maxHeightCm;
  final double bboxWidthCm;
  final double bboxLengthCm;
  final double foodPixelRatio;
  final String confidence;

  VolumeEstimationResult({
    required this.volumeMl,
    required this.foodAreaCm2,
    required this.avgHeightCm,
    required this.maxHeightCm,
    required this.bboxWidthCm,
    required this.bboxLengthCm,
    required this.foodPixelRatio,
    required this.confidence,
  });

  factory VolumeEstimationResult.fromJson(Map<String, dynamic> json) {
    return VolumeEstimationResult(
      volumeMl: (json['volume_ml'] as num?)?.toDouble() ?? 0,
      foodAreaCm2: (json['food_area_cm2'] as num?)?.toDouble() ?? 0,
      avgHeightCm: (json['avg_height_cm'] as num?)?.toDouble() ?? 0,
      maxHeightCm: (json['max_height_cm'] as num?)?.toDouble() ?? 0,
      bboxWidthCm: (json['bbox_width_cm'] as num?)?.toDouble() ?? 0,
      bboxLengthCm: (json['bbox_length_cm'] as num?)?.toDouble() ?? 0,
      foodPixelRatio: (json['food_pixel_ratio'] as num?)?.toDouble() ?? 0,
      confidence: json['confidence'] as String? ?? 'none',
    );
  }

  /// Format as a context string suitable for the LLM system prompt.
  String toPromptContext() {
    if (confidence == 'none' || volumeMl <= 0) return '';
    return 'Depth-AI volume estimation: ~${volumeMl.round()} mL, '
        'food area ~${foodAreaCm2.round()} cm², '
        'avg height ~${avgHeightCm.toStringAsFixed(1)} cm, '
        'max height ~${maxHeightCm.toStringAsFixed(1)} cm, '
        'bounding box ~${bboxWidthCm.toStringAsFixed(1)}×${bboxLengthCm.toStringAsFixed(1)} cm. '
        'Confidence: $confidence. '
        'Note: volume is approximate (±30 %).';
  }
}

/// Singleton service that talks to the backend volume estimation endpoint.
class VolumeService {
  static final VolumeService _instance = VolumeService._internal();
  factory VolumeService() => _instance;
  VolumeService._internal();

  /// Estimate food volume from a base64-encoded image.
  Future<VolumeEstimationResult> estimateVolume({
    required String imageBase64,
    double focalLength35mm = 23.0,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig}/volume/estimate'), //delelted .volumeApiUrl
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image_base64': imageBase64,
            'focal_length_35mm': focalLength35mm,
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
        'Volume estimation failed (${response.statusCode}): ${response.body}',
      );
    }

    return VolumeEstimationResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
