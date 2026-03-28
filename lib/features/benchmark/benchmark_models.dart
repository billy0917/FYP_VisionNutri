library;

/// Data models for the benchmark comparison feature.
///
/// Compares three food estimation methods:
///   A – Pure Gemini (image only) + RAG
///   B – Gemini + camera EXIF + RAG
///   C – ARCore dimensions + Gemini + RAG

class GroundTruth {
  final double widthCm;
  final double lengthCm;
  final double heightCm;
  final double? weightG;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;

  GroundTruth({
    required this.widthCm,
    required this.lengthCm,
    required this.heightCm,
    this.weightG,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  Map<String, dynamic> toJson() => {
        'widthCm': widthCm,
        'lengthCm': lengthCm,
        'heightCm': heightCm,
        'weightG': weightG,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory GroundTruth.fromJson(Map<String, dynamic> j) => GroundTruth(
        widthCm: (j['widthCm'] as num).toDouble(),
        lengthCm: (j['lengthCm'] as num).toDouble(),
        heightCm: (j['heightCm'] as num).toDouble(),
        weightG: (j['weightG'] as num?)?.toDouble(),
        calories: (j['calories'] as num?)?.toInt(),
        protein: (j['protein'] as num?)?.toInt(),
        carbs: (j['carbs'] as num?)?.toInt(),
        fat: (j['fat'] as num?)?.toInt(),
      );
}

class EstimationResult {
  final double? widthCm;
  final double? lengthCm;
  final double? heightCm;
  final double? volumeMl;
  final double? weightG;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String reasoning;

  EstimationResult({
    this.widthCm,
    this.lengthCm,
    this.heightCm,
    this.volumeMl,
    this.weightG,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.reasoning = '',
  });

  Map<String, dynamic> toJson() => {
        'widthCm': widthCm,
        'lengthCm': lengthCm,
        'heightCm': heightCm,
        'volumeMl': volumeMl,
        'weightG': weightG,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'reasoning': reasoning,
      };

  factory EstimationResult.fromJson(Map<String, dynamic> j) =>
      EstimationResult(
        widthCm: (j['widthCm'] as num?)?.toDouble(),
        lengthCm: (j['lengthCm'] as num?)?.toDouble(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        volumeMl: (j['volumeMl'] as num?)?.toDouble(),
        weightG: (j['weightG'] as num?)?.toDouble(),
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        protein: (j['protein'] as num?)?.toInt() ?? 0,
        carbs: (j['carbs'] as num?)?.toInt() ?? 0,
        fat: (j['fat'] as num?)?.toInt() ?? 0,
        reasoning: j['reasoning'] as String? ?? '',
      );
}

class ArMeasurementData {
  final double? widthCm;
  final double? lengthCm;
  final double? heightCm;
  final double? volumeMl;

  ArMeasurementData({this.widthCm, this.lengthCm, this.heightCm, this.volumeMl});

  Map<String, dynamic> toJson() => {
        'widthCm': widthCm,
        'lengthCm': lengthCm,
        'heightCm': heightCm,
        'volumeMl': volumeMl,
      };

  factory ArMeasurementData.fromJson(Map<String, dynamic> j) =>
      ArMeasurementData(
        widthCm: (j['widthCm'] as num?)?.toDouble(),
        lengthCm: (j['lengthCm'] as num?)?.toDouble(),
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        volumeMl: (j['volumeMl'] as num?)?.toDouble(),
      );

  String toPromptContext() =>
      'ARCore-measured bounding-box dimensions: '
      'width ${widthCm?.toStringAsFixed(1)} cm, '
      'length ${lengthCm?.toStringAsFixed(1)} cm, '
      'height ${heightCm?.toStringAsFixed(1)} cm, '
      'bbox volume ~${volumeMl?.round()} mL.';
}

enum BenchmarkStatus { draft, complete }

class BenchmarkItem {
  final String id;
  final DateTime createdAt;
  String foodName;
  bool isFood;
  String? imagePath;
  String? cameraInfo;
  GroundTruth? groundTruth;
  ArMeasurementData? arMeasurement;
  EstimationResult? methodA; // Pure Gemini (+ RAG if food)
  EstimationResult? methodB; // Gemini + EXIF (+ RAG if food)
  EstimationResult? methodC; // ARCore + Gemini (+ RAG if food)

  BenchmarkStatus get status =>
      (groundTruth != null &&
              methodA != null &&
              methodB != null &&
              methodC != null)
          ? BenchmarkStatus.complete
          : BenchmarkStatus.draft;

  BenchmarkItem({
    required this.id,
    required this.createdAt,
    this.foodName = '',
    this.isFood = true,
    this.imagePath,
    this.cameraInfo,
    this.groundTruth,
    this.arMeasurement,
    this.methodA,
    this.methodB,
    this.methodC,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'foodName': foodName,
        'isFood': isFood,
        'imagePath': imagePath,
        'cameraInfo': cameraInfo,
        'groundTruth': groundTruth?.toJson(),
        'arMeasurement': arMeasurement?.toJson(),
        'methodA': methodA?.toJson(),
        'methodB': methodB?.toJson(),
        'methodC': methodC?.toJson(),
      };

  factory BenchmarkItem.fromJson(Map<String, dynamic> j) => BenchmarkItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        foodName: j['foodName'] as String? ?? '',
        isFood: j['isFood'] as bool? ?? true,
        imagePath: j['imagePath'] as String?,
        cameraInfo: j['cameraInfo'] as String?,
        groundTruth: j['groundTruth'] != null
            ? GroundTruth.fromJson(j['groundTruth'] as Map<String, dynamic>)
            : null,
        arMeasurement: j['arMeasurement'] != null
            ? ArMeasurementData.fromJson(
                j['arMeasurement'] as Map<String, dynamic>)
            : null,
        methodA: j['methodA'] != null
            ? EstimationResult.fromJson(j['methodA'] as Map<String, dynamic>)
            : null,
        methodB: j['methodB'] != null
            ? EstimationResult.fromJson(j['methodB'] as Map<String, dynamic>)
            : null,
        methodC: j['methodC'] != null
            ? EstimationResult.fromJson(j['methodC'] as Map<String, dynamic>)
            : null,
      );
}
