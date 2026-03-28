library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:smart_diet_ai/core/services/api_client.dart';
import 'package:smart_diet_ai/features/benchmark/benchmark_models.dart';

class BenchmarkService {
  static final BenchmarkService _instance = BenchmarkService._();
  factory BenchmarkService() => _instance;
  BenchmarkService._();

  // ── Storage ──────────────────────────────────────────────

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/benchmark');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<List<BenchmarkItem>> loadAll() async {
    final dir = await _dir();
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    final items = <BenchmarkItem>[];
    for (final f in files) {
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        items.add(BenchmarkItem.fromJson(j));
      } catch (_) {
        // skip corrupt files
      }
    }
    return items;
  }

  Future<void> save(BenchmarkItem item) async {
    final dir = await _dir();
    final f = File('${dir.path}/${item.id}.json');
    await f.writeAsString(jsonEncode(item.toJson()));
  }

  Future<void> delete(String id) async {
    final dir = await _dir();
    final f = File('${dir.path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  // ── Estimation methods ───────────────────────────────────

  /// Method A: Pure Gemini (+ RAG if food; dimensions-only if object).
  Future<EstimationResult> runMethodA(String imageBase64,
      {bool isFood = true}) async {
    if (isFood) return _runBenchmarkRag(imageBase64: imageBase64);
    return ApiClient().estimateDimensionsOnly(imageBase64: imageBase64);
  }

  /// Method B: Gemini + EXIF (+ RAG if food; dimensions-only if object).
  Future<EstimationResult> runMethodB(String imageBase64, String cameraInfo,
      {bool isFood = true}) async {
    if (isFood) {
      return _runBenchmarkRag(
          imageBase64: imageBase64, cameraInfo: cameraInfo);
    }
    return ApiClient()
        .estimateDimensionsOnly(imageBase64: imageBase64, cameraInfo: cameraInfo);
  }

  /// Method C: ARCore dims + Gemini (+ RAG if food).
  Future<EstimationResult> runMethodC(
    String imageBase64,
    String cameraInfo,
    ArMeasurementData arData, {
    bool isFood = true,
  }) async {
    final arContext = '$cameraInfo. ${arData.toPromptContext()}';
    if (isFood) {
      return _runBenchmarkRag(
        imageBase64: imageBase64,
        cameraInfo: arContext,
        arData: arData,
      );
    }
    // For non-food objects, ARCore dimensions are the direct estimate.
    final geminiResult = await ApiClient()
        .estimateDimensionsOnly(imageBase64: imageBase64, cameraInfo: arContext);
    return EstimationResult(
      widthCm: arData.widthCm,
      lengthCm: arData.lengthCm,
      heightCm: arData.heightCm,
      volumeMl: arData.volumeMl,
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      reasoning: geminiResult.reasoning,
    );
  }

  /// Shared RAG pipeline that asks for dimension + nutrition estimates.
  Future<EstimationResult> _runBenchmarkRag({
    required String imageBase64,
    String? cameraInfo,
    ArMeasurementData? arData,
  }) async {
    final result = await ApiClient().analyzeFoodForBenchmark(
      imageBase64: imageBase64,
      cameraInfo: cameraInfo,
    );

    // For Method C, use ARCore dimensions directly instead of Gemini's estimates.
    if (arData != null) {
      return EstimationResult(
        widthCm: arData.widthCm,
        lengthCm: arData.lengthCm,
        heightCm: arData.heightCm,
        volumeMl: arData.volumeMl,
        weightG: result.weightG,
        calories: result.calories,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
        reasoning: result.reasoning,
      );
    }
    return result;
  }

  // ── CSV export ───────────────────────────────────────────

  String exportCsv(List<BenchmarkItem> items) {
    final buf = StringBuffer();
    buf.writeln(
      'id,food_name,is_food,'
      'gt_width_cm,gt_length_cm,gt_height_cm,gt_weight_g,gt_cal,gt_protein,gt_carbs,gt_fat,'
      'a_width_cm,a_length_cm,a_height_cm,a_weight_g,a_cal,a_protein,a_carbs,a_fat,'
      'b_width_cm,b_length_cm,b_height_cm,b_weight_g,b_cal,b_protein,b_carbs,b_fat,'
      'c_width_cm,c_length_cm,c_height_cm,c_weight_g,c_cal,c_protein,c_carbs,c_fat',
    );
    for (final item in items) {
      final gt = item.groundTruth;
      final a = item.methodA;
      final b = item.methodB;
      final c = item.methodC;
      buf.writeln(
        '${_esc(item.id)},${_esc(item.foodName)},${item.isFood},'
        '${gt?.widthCm ?? ''},${gt?.lengthCm ?? ''},${gt?.heightCm ?? ''},${gt?.weightG ?? ''},${gt?.calories ?? ''},${gt?.protein ?? ''},${gt?.carbs ?? ''},${gt?.fat ?? ''},'
        '${a?.widthCm ?? ''},${a?.lengthCm ?? ''},${a?.heightCm ?? ''},${a?.weightG ?? ''},${a?.calories ?? ''},${a?.protein ?? ''},${a?.carbs ?? ''},${a?.fat ?? ''},'
        '${b?.widthCm ?? ''},${b?.lengthCm ?? ''},${b?.heightCm ?? ''},${b?.weightG ?? ''},${b?.calories ?? ''},${b?.protein ?? ''},${b?.carbs ?? ''},${b?.fat ?? ''},'
        '${c?.widthCm ?? ''},${c?.lengthCm ?? ''},${c?.heightCm ?? ''},${c?.weightG ?? ''},${c?.calories ?? ''},${c?.protein ?? ''},${c?.carbs ?? ''},${c?.fat ?? ''}',
      );
    }
    return buf.toString();
  }

  static String _esc(String v) => v.contains(',') ? '"$v"' : v;
}
