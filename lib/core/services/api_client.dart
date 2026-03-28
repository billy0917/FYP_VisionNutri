/// SmartDiet AI - API Client
///
/// Calls AI APIs directly from the app — no local server required.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_diet_ai/core/config/app_config.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/features/benchmark/benchmark_models.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _systemPrompt =
      'You are an expert nutritionist AI. Analyze the food in the image. '
      'First estimate each food item\'s physical dimensions (L×W×H cm) using perspective cues, '
      'plate/bowl/container size, and common object knowledge. '
      'Then estimate volume (mL) and convert to weight using typical food density '
      '(rice ~1.1g/mL, soup ~1.0, meat ~1.05, bread ~0.35, vegetables ~0.6). '
      'Respond ONLY with a valid JSON object (no markdown, no extra text) in this exact format: '
      '{"food_name": "name", "calories": 0, "protein": 0, "carbs": 0, "fat": 0, '
      '"reasoning": "dims ~LxWxH cm → ~V mL → ~Wg"}. '
      'All numeric values must be integers.';

  /// Analyze a food image directly via AI API — no local server needed.
  Future<FoodAnalysisResult> analyzeFood({
    String? imageUrl,
    String? imageBase64,
    String? additionalContext,
  }) async {
    if (imageBase64 == null && imageUrl == null) {
      throw ApiException(statusCode: 400, message: 'No image provided');
    }

    final imageContent = imageBase64 != null
        ? 'data:image/jpeg;base64,$imageBase64'
        : imageUrl!;

    final body = jsonEncode({
      'model': AppConfig.visionModel,
      'max_tokens': 10000,
      'temperature': 0.3,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': additionalContext != null
                  ? 'Analyze this food. Context: $additionalContext'
                  : 'Analyze this food image.',
            },
            {
              'type': 'image_url',
              'image_url': {'url': imageContent},
            },
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(AppConfig.visionApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.visionApiKey}',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'AI API error: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    var content = decoded['choices'][0]['message']['content'] as String;

    // Strip markdown code fences if present
    if (content.contains('```')) {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start != -1 && end != -1) content = content.substring(start, end + 1);
    }

    try {
      final result = jsonDecode(content) as Map<String, dynamic>;
      return FoodAnalysisResult(
        foodName: result['food_name'] as String? ?? 'Unknown food',
        calories: (result['calories'] as num?)?.toInt() ?? 0,
        protein: (result['protein'] as num?)?.toInt() ?? 0,
        carbs: (result['carbs'] as num?)?.toInt() ?? 0,
        fat: (result['fat'] as num?)?.toInt() ?? 0,
        reasoning: result['reasoning'] as String? ?? '',
      );
    } catch (_) {
      // Fallback: extract fields via regex when JSON is truncated
      int? _extractInt(String key) {
        final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(content);
        return m != null ? int.tryParse(m.group(1)!) : null;
      }
      String? _extractStr(String key) {
        final m = RegExp('"$key"\\s*:\\s*"([^"]*)"').firstMatch(content);
        return m?.group(1);
      }
      final foodName = _extractStr('food_name');
      final calories = _extractInt('calories');
      if (foodName != null && calories != null) {
        return FoodAnalysisResult(
          foodName: foodName,
          calories: calories,
          protein: _extractInt('protein') ?? 0,
          carbs: _extractInt('carbs') ?? 0,
          fat: _extractInt('fat') ?? 0,
          reasoning: '',
        );
      }
      throw ApiException(
        statusCode: 500,
        message: 'Failed to parse AI response: $content',
      );
    }
  }
  
  /// RAG-enhanced food analysis pipeline.
  ///
  /// Step 1: Gemini Vision quickly identifies food name from image.
  /// Step 2: text-embedding-3-small embeds name → searches CFS Supabase DB.
  /// Step 3: Gemini Vision (with CFS official data + dimension estimation
  ///         instructions) estimates portion size → calculates final nutrition.
  Future<FoodAnalysisResult> analyzeFoodWithRag({
    required String imageBase64,
    String? cameraInfo,
  }) async {
    final ragSteps = <RagDebugStep>[];

    if (cameraInfo != null && cameraInfo.isNotEmpty) {
      ragSteps.add(RagDebugStep(
        title: 'Camera EXIF Metadata',
        output: cameraInfo,
      ));
    }

    final foodItems = await _identifyFoodName(imageBase64, ragSteps);
    // Chinese names joined for display and Step 3 context
    final foodName = foodItems.map((e) => e.$1).join('、');
    final cfsMatches = await _searchCfsDatabase(foodItems, ragSteps);
    return _analyzeWithContext(
      imageBase64: imageBase64,
      foodName: foodName,
      cfsMatches: cfsMatches,
      ragSteps: ragSteps,
      cameraInfo: cameraInfo,
    );
  }

  /// Step 1: Quick food name extraction from image.
  /// Returns a list of (Chinese name, English name) pairs.
  Future<List<(String chi, String eng)>> _identifyFoodName(
      String imageBase64, List<RagDebugStep> steps) async {
    try {
      final body = jsonEncode({
        'model': AppConfig.visionModel,
        'max_tokens': 8000,
        'temperature': 0.1,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '圖中是什麼食物？每種食物用「繁體中文|English」格式回答，多種食物用頓號分隔。'
                    '只回答格式本身，不要其他文字。'
                    '例子：魚蛋|Fish ball、燒賣|Siu Mai、白飯|Steamed white rice',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
              },
            ],
          },
        ],
      });

      final response = await http.post(
        Uri.parse(AppConfig.visionApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.visionApiKey}',
        },
        body: body,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final raw = (decoded['choices'][0]['message']['content'] as String).trim();
        // Parse "中文|English、中文|English" format
        final items = raw
            .split(RegExp(r'、|,\s*'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) {
              final parts = s.split('|');
              final chi = parts.first.trim();
              final eng = parts.length > 1 ? parts[1].trim() : chi;
              return (chi, eng);
            })
            .toList();
        final displayPairs = items.map((e) => '${e.$1} (${e.$2})').join('、');
        steps.add(RagDebugStep(
          title: 'Step 1 — Food Identification (${AppConfig.visionModel})',
          output: displayPairs,
        ));
        return items;
      }
    } catch (e) {
      steps.add(RagDebugStep(
        title: 'Step 1 — Food Identification',
        output: 'Error: $e',
      ));
    }
    return [('Unknown food', 'Unknown food')];
  }

  /// Step 2: Search CFS Supabase database.
  /// Text search uses Chinese name on food_name_chi.
  /// Vector search fallback uses English name for better embedding accuracy.
  Future<List<Map<String, dynamic>>> _searchCfsDatabase(
      List<(String chi, String eng)> foodItems, List<RagDebugStep> steps) async {
    final allMatches = <Map<String, dynamic>>[];
    final debugParts = <String>[];
    final foodName = foodItems.map((e) => e.$1).join('、');

    try {
      for (final item in foodItems) {
        final chi = item.$1;
        final eng = item.$2;

        // --- A) Text search: Chinese name on food_name_chi only ---
        List<Map<String, dynamic>> hits = [];
        try {
          final textHits = await SupabaseService.client
              .from('cfs_foods')
              .select('food_id, food_name_chi, food_name_eng, energy_kcal, protein_g, carbohydrate_g, fat_g, serving_size')
              .ilike('food_name_chi', '%$chi%')
              .limit(3);
          hits = List<Map<String, dynamic>>.from(textHits as List? ?? []);
          if (hits.isNotEmpty) {
            for (final r in hits) {
              r['similarity'] = 0.8;
            }
            final lines = hits
                .map((m) => '  ${m['food_name_eng'] ?? '?'} (${m['food_name_chi'] ?? '?'})')
                .join('\n');
            debugParts.add('[$chi] text match (chi):\n$lines');
            allMatches.addAll(hits);
            continue; // text hit — skip vector
          }
        } catch (_) {}

        // --- B) Vector search fallback: English name for embedding ---
        try {
          final embedResponse = await http.post(
            Uri.parse(AppConfig.embeddingApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.embeddingApiKey}',
            },
            body: jsonEncode({
              'model': AppConfig.embeddingModel,
              'input': eng,
              'dimensions': AppConfig.embeddingDimensions,
            }),
          ).timeout(const Duration(seconds: 60));

          if (embedResponse.statusCode == 200) {
            final embedData = jsonDecode(embedResponse.body);
            final embedding =
                (embedData['data'][0]['embedding'] as List).cast<double>();
            final response = await SupabaseService.client.rpc('match_cfs_food', params: {
              'query_embedding': embedding,
              'match_count': 3,
              'match_threshold': 0.45,
            });
            hits = List<Map<String, dynamic>>.from(response as List? ?? []);
          }
        } catch (_) {}

        if (hits.isNotEmpty) {
          final lines = hits.map((m) {
            final sim = ((m['similarity'] as num? ?? 0) * 100).toStringAsFixed(1);
            return '  ${m['food_name_eng'] ?? '?'} (${m['food_name_chi'] ?? '?'}) — $sim%';
          }).join('\n');
          debugParts.add('[$chi] vector fallback (eng: "$eng"):\n$lines');
          allMatches.addAll(hits);
        } else {
          debugParts.add('[$chi] No matches (text + vector)');
        }
      }

      // Deduplicate by food_id, highest similarity first
      final seen = <dynamic>{};
      final merged = <Map<String, dynamic>>[];
      for (final m in allMatches
        ..sort((a, b) => ((b['similarity'] as num? ?? 0)
            .compareTo(a['similarity'] as num? ?? 0)))) {
        if (seen.add(m['food_id'])) merged.add(m);
        if (merged.length >= 5) break;
      }

      steps.add(RagDebugStep(
        title: 'Step 2 — CFS Database Search (text → vector)',
        output: 'Query: "$foodName"\n${debugParts.join('\n')}',
      ));
      return merged;
    } catch (e) {
      steps.add(RagDebugStep(
        title: 'Step 2 — CFS Database Search',
        output: 'Error: $e',
      ));
      return [];
    }
  }

  /// Step 3: Final Gemini analysis with CFS official data as context.
  /// Falls back to pure AI estimate if no CFS match found.
  Future<FoodAnalysisResult> _analyzeWithContext({
    required String imageBase64,
    required String foodName,
    required List<Map<String, dynamic>> cfsMatches,
    required List<RagDebugStep> ragSteps,
    String? cameraInfo,
  }) async {
    String systemPrompt;
    String userText;
    String topCfsName = '';

    if (cfsMatches.isNotEmpty) {
      final cfsContext = cfsMatches.map((m) {
        final name = '${m['food_name_eng'] ?? ''} (${m['food_name_chi'] ?? ''})';
        final fatVal = m['fat_g'];
        final fatStr = (fatVal == null || fatVal.toString() == 'null') ? 'not recorded' : '${fatVal}g';
        final per100 = 'Per 100g: ${m['energy_kcal']}kcal, '
            'protein ${m['protein_g']}g, carbs ${m['carbohydrate_g']}g, fat $fatStr';
        final sim = ((m['similarity'] as num? ?? 0) * 100).toStringAsFixed(0);
        return '$name\n$per100 (match $sim%)';
      }).join('\n\n');

      topCfsName = cfsMatches.first['food_name_eng'] as String? ?? foodName;

      final camLine = (cameraInfo != null && cameraInfo.isNotEmpty)
          ? 'Camera metadata: $cameraInfo. '
          : 'Photo taken by a typical smartphone. ';

      // Detect ARCore-measured dimensions to give a more specific instruction.
      final hasArMeasure = cameraInfo != null &&
          cameraInfo.contains('ARCore-measured');

      final measureStep = hasArMeasure
          ? '1. MEASURE: The food\'s physical bounding-box dimensions were measured with ARCore '
            '(see the camera metadata). Use them directly. Note: actual food volume is '
            'typically 50-70% of the rectangular bounding box.\n'
          : '1. MEASURE: Estimate each food item\'s physical dimensions (length × width × height in cm) '
            'using perspective cues, plate/bowl/container size, and common object knowledge.\n';

      systemPrompt =
          'You are a precise nutritionist with expertise in estimating food portions from photos. '
          'The photo shows "$foodName". '
          '$camLine'
          'Use the focal length and any available sensor data to judge the field of view and '
          'real-world scale of objects in the frame. '
          'Below is official nutrition data from the Hong Kong Centre for Food Safety (CFS) — '
          'all values are PER 100g.\n\n'
          'STEP-BY-STEP:\n'
          '$measureStep'
          '2. VOLUME: From the dimensions, estimate the food volume in mL or cm³.\n'
          '3. WEIGHT: Convert volume to weight using typical food density '
          '(e.g. rice ~1.1 g/mL, soup ~1.0, meat ~1.05, bread ~0.35, vegetables ~0.6).\n'
          '4. NUTRITION: Use the CFS per-100g data to calculate total nutrients.\n\n'
          'If a nutrient value is marked "not recorded", estimate it from nutritional knowledge. '
          'Respond ONLY with valid JSON, no markdown, no extra text:\n'
          '{"food_name": "concise name", "calories": integer, "protein": integer, '
          '"carbs": integer, "fat": integer, '
          '"reasoning": "dims ~LxWxH cm → ~V mL → ~Wg, CFS: [name]"}';

      userText = 'CFS official nutrition data (per 100g):\n$cfsContext\n\n'
          'Estimate the portion from the image and calculate total nutrition.';
    } else {
      systemPrompt = _systemPrompt;
      userText = 'Analyze this food image.';
    }

    final body = jsonEncode({
      'model': AppConfig.visionModel,
      'max_tokens': 10000,
      'temperature': 0.3,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userText},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(AppConfig.visionApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.visionApiKey}',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'AI API error: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    var content = decoded['choices'][0]['message']['content'] as String;

    if (content.contains('```')) {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start != -1 && end != -1) content = content.substring(start, end + 1);
    }

    ragSteps.add(RagDebugStep(
      title: 'Step 3 — Nutrition Analysis (${AppConfig.visionModel})',
      output: content,
    ));

    try {
      final result = jsonDecode(content) as Map<String, dynamic>;
      return FoodAnalysisResult(
        foodName: result['food_name'] as String? ?? foodName,
        calories: (result['calories'] as num?)?.toInt() ?? 0,
        protein: (result['protein'] as num?)?.toInt() ?? 0,
        carbs: (result['carbs'] as num?)?.toInt() ?? 0,
        fat: (result['fat'] as num?)?.toInt() ?? 0,
        reasoning: result['reasoning'] as String? ?? '',
        dataSource: cfsMatches.isNotEmpty ? 'cfs_official' : 'ai_estimate',
        cfsMatchName: cfsMatches.isNotEmpty ? topCfsName : null,
        ragSteps: ragSteps,
      );
    } catch (_) {
      int? ext(String key) {
        final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(content);
        return m != null ? int.tryParse(m.group(1)!) : null;
      }
      String? exs(String key) {
        final m = RegExp('"$key"\\s*:\\s*"([^"]*)"').firstMatch(content);
        return m?.group(1);
      }
      return FoodAnalysisResult(
        foodName: exs('food_name') ?? foodName,
        calories: ext('calories') ?? 0,
        protein: ext('protein') ?? 0,
        carbs: ext('carbs') ?? 0,
        fat: ext('fat') ?? 0,
        reasoning: '',
        dataSource: cfsMatches.isNotEmpty ? 'cfs_official' : 'ai_estimate',
        cfsMatchName: cfsMatches.isNotEmpty ? topCfsName : null,
        ragSteps: ragSteps,
      );
    }
  }

  /// Benchmark-specific RAG analysis that returns dimension + weight + nutrition.
  ///
  /// Reuses Steps 1 & 2 from [analyzeFoodWithRag], but Step 3 asks Gemini to
  /// also output width/length/height/volume/weight in the JSON.
  Future<EstimationResult> analyzeFoodForBenchmark({
    required String imageBase64,
    String? cameraInfo,
  }) async {
    final ragSteps = <RagDebugStep>[];
    final foodItems = await _identifyFoodName(imageBase64, ragSteps);
    final foodName = foodItems.map((e) => e.$1).join('、');
    final cfsMatches = await _searchCfsDatabase(foodItems, ragSteps);

    // Build system prompt ── always asks for dimensions + nutrition
    final camLine = (cameraInfo != null && cameraInfo.isNotEmpty)
        ? 'Camera metadata: $cameraInfo. '
        : 'Photo taken by a typical smartphone. ';

    final hasArMeasure =
        cameraInfo != null && cameraInfo.contains('ARCore-measured');

    final measureStep = hasArMeasure
        ? '1. MEASURE: The food\'s physical bounding-box dimensions were measured with ARCore '
          '(see the camera metadata). Use them directly. Note: actual food volume is '
          'typically 50-70% of the rectangular bounding box.\n'
        : '1. MEASURE: Estimate each food item\'s physical dimensions (length × width × height in cm) '
          'using perspective cues, plate/bowl/container size, and common object knowledge.\n';

    String systemPrompt;
    String userText;

    if (cfsMatches.isNotEmpty) {
      final cfsContext = cfsMatches.map((m) {
        final name =
            '${m['food_name_eng'] ?? ''} (${m['food_name_chi'] ?? ''})';
        final fatVal = m['fat_g'];
        final fatStr = (fatVal == null || fatVal.toString() == 'null')
            ? 'not recorded'
            : '${fatVal}g';
        return '$name\nPer 100g: ${m['energy_kcal']}kcal, '
            'protein ${m['protein_g']}g, carbs ${m['carbohydrate_g']}g, fat $fatStr';
      }).join('\n\n');

      systemPrompt =
          'You are a precise nutritionist with expertise in estimating food portions from photos. '
          'The photo shows "$foodName". '
          '$camLine'
          'Use the focal length and any available sensor data to judge the field of view and '
          'real-world scale of objects in the frame. '
          'Below is official nutrition data from the Hong Kong Centre for Food Safety (CFS) — '
          'all values are PER 100g.\n\n'
          'STEP-BY-STEP:\n'
          '$measureStep'
          '2. VOLUME: From the dimensions, estimate the food volume in mL or cm³.\n'
          '3. WEIGHT: Convert volume to weight using typical food density '
          '(e.g. rice ~1.1 g/mL, soup ~1.0, meat ~1.05, bread ~0.35, vegetables ~0.6).\n'
          '4. NUTRITION: Use the CFS per-100g data to calculate total nutrients.\n\n'
          'If a nutrient value is marked "not recorded", estimate it from nutritional knowledge. '
          'Respond ONLY with valid JSON, no markdown, no extra text:\n'
          '{"food_name":"…","width_cm":float,"length_cm":float,"height_cm":float,'
          '"volume_ml":float,"weight_g":float,'
          '"calories":int,"protein":int,"carbs":int,"fat":int,'
          '"reasoning":"dims → vol → weight → nutrition"}';

      userText = 'CFS official nutrition data (per 100g):\n$cfsContext\n\n'
          'Estimate the portion from the image and calculate total nutrition.';
    } else {
      systemPrompt =
          'You are an expert nutritionist AI. Analyze the food in the image. '
          '$camLine'
          'First estimate each food item\'s physical dimensions (L×W×H cm) using perspective cues, '
          'plate/bowl/container size, and common object knowledge. '
          'Then estimate volume (mL) and convert to weight using typical food density '
          '(rice ~1.1g/mL, soup ~1.0, meat ~1.05, bread ~0.35, vegetables ~0.6). '
          'Respond ONLY with valid JSON, no markdown, no extra text:\n'
          '{"food_name":"…","width_cm":float,"length_cm":float,"height_cm":float,'
          '"volume_ml":float,"weight_g":float,'
          '"calories":int,"protein":int,"carbs":int,"fat":int,'
          '"reasoning":"dims → vol → weight → nutrition"}';

      userText = 'Analyze this food image.';
    }

    final body = jsonEncode({
      'model': AppConfig.visionModel,
      'max_tokens': 10000,
      'temperature': 0.3,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userText},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$imageBase64'
              },
            },
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(AppConfig.visionApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.visionApiKey}',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'AI API error: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    var content = decoded['choices'][0]['message']['content'] as String;

    if (content.contains('```')) {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start != -1 && end != -1) content = content.substring(start, end + 1);
    }

    try {
      final r = jsonDecode(content) as Map<String, dynamic>;
      return EstimationResult(
        widthCm: (r['width_cm'] as num?)?.toDouble(),
        lengthCm: (r['length_cm'] as num?)?.toDouble(),
        heightCm: (r['height_cm'] as num?)?.toDouble(),
        volumeMl: (r['volume_ml'] as num?)?.toDouble(),
        weightG: (r['weight_g'] as num?)?.toDouble(),
        calories: (r['calories'] as num?)?.toInt() ?? 0,
        protein: (r['protein'] as num?)?.toInt() ?? 0,
        carbs: (r['carbs'] as num?)?.toInt() ?? 0,
        fat: (r['fat'] as num?)?.toInt() ?? 0,
        reasoning: r['reasoning'] as String? ?? '',
      );
    } catch (_) {
      // Regex fallback for truncated JSON
      double? ed(String key) {
        final m = RegExp('"$key"\\s*:\\s*([\\d.]+)').firstMatch(content);
        return m != null ? double.tryParse(m.group(1)!) : null;
      }

      int? ei(String key) {
        final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(content);
        return m != null ? int.tryParse(m.group(1)!) : null;
      }

      return EstimationResult(
        widthCm: ed('width_cm'),
        lengthCm: ed('length_cm'),
        heightCm: ed('height_cm'),
        volumeMl: ed('volume_ml'),
        weightG: ed('weight_g'),
        calories: ei('calories') ?? 0,
        protein: ei('protein') ?? 0,
        carbs: ei('carbs') ?? 0,
        fat: ei('fat') ?? 0,
        reasoning: '',
      );
    }
  }

  /// Dimension-only estimation for non-food objects (no RAG, no nutrition).
  ///
  /// Asks Gemini to estimate physical dimensions only.
  Future<EstimationResult> estimateDimensionsOnly({
    required String imageBase64,
    String? cameraInfo,
  }) async {
    final camLine = (cameraInfo != null && cameraInfo.isNotEmpty)
        ? 'Camera metadata: $cameraInfo. '
        : 'Photo taken by a typical smartphone. ';

    final hasArMeasure =
        cameraInfo != null && cameraInfo.contains('ARCore-measured');

    final measureStep = hasArMeasure
        ? 'The object\'s bounding-box dimensions were measured with ARCore '
          '(see the camera metadata). Use them directly.'
        : 'Estimate the object\'s physical dimensions (length × width × height in cm) '
          'using perspective cues, nearby objects for scale reference, and common knowledge '
          'about the object\'s typical size.';

    final systemPrompt =
        'You are an expert at estimating physical dimensions of objects from photos. '
        '$camLine'
        'Use the focal length and any available sensor data to judge the field of view and '
        'real-world scale of objects in the frame.\n\n'
        '$measureStep\n\n'
        'Respond ONLY with valid JSON, no markdown, no extra text:\n'
        '{"object_name":"…","width_cm":float,"length_cm":float,"height_cm":float,'
        '"volume_ml":float,"reasoning":"brief explanation of how you estimated"}';

    final body = jsonEncode({
      'model': AppConfig.visionModel,
      'max_tokens': 4000,
      'temperature': 0.3,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': 'Estimate the physical dimensions of the main object in this photo.',
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
            },
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(AppConfig.visionApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.visionApiKey}',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'AI API error: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    var content = decoded['choices'][0]['message']['content'] as String;

    if (content.contains('```')) {
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start != -1 && end != -1) {
        content = content.substring(start, end + 1);
      }
    }

    try {
      final r = jsonDecode(content) as Map<String, dynamic>;
      return EstimationResult(
        widthCm: (r['width_cm'] as num?)?.toDouble(),
        lengthCm: (r['length_cm'] as num?)?.toDouble(),
        heightCm: (r['height_cm'] as num?)?.toDouble(),
        volumeMl: (r['volume_ml'] as num?)?.toDouble(),
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        reasoning: r['reasoning'] as String? ?? '',
      );
    } catch (_) {
      double? ed(String key) {
        final m = RegExp('"$key"\\s*:\\s*([\\d.]+)').firstMatch(content);
        return m != null ? double.tryParse(m.group(1)!) : null;
      }

      return EstimationResult(
        widthCm: ed('width_cm'),
        lengthCm: ed('length_cm'),
        heightCm: ed('height_cm'),
        volumeMl: ed('volume_ml'),
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        reasoning: '',
      );
    }
  }

  /// Send message to RAG chatbot.
  /// TODO: implement direct AI chat call (no backend needed)
  Future<ChatResponse> sendChatMessage({
    required String message,
    String? conversationId,
  }) async {
    // Placeholder — will be replaced with direct AI API call
    throw ApiException(statusCode: 501, message: 'Chat not yet implemented');
  }

  /// Get recipe recommendations.
  /// TODO: implement direct AI call
  Future<List<Recipe>> getRecipeRecommendations({
    int? targetCalories,
    int? targetProtein,
    List<String>? dietaryTags,
  }) async {
    throw ApiException(statusCode: 501, message: 'Recipes not yet implemented');
  }
}

/// API Exception class for error handling.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  
  ApiException({required this.statusCode, required this.message});
  
  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// One step of debug output from the RAG pipeline.
class RagDebugStep {
  final String title;
  final String output;
  RagDebugStep({required this.title, required this.output});
}

/// Food analysis result model.
class FoodAnalysisResult {
  final String foodName;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String reasoning;
  final double? confidenceScore;
  /// 'cfs_official' if matched from CFS database, 'ai_estimate' otherwise.
  final String dataSource;
  /// The matched CFS food name (English), only set when dataSource == 'cfs_official'.
  final String? cfsMatchName;
  /// Debug steps from the RAG pipeline, available after analyzeFoodWithRag().
  final List<RagDebugStep>? ragSteps;

  FoodAnalysisResult({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.reasoning,
    this.confidenceScore,
    this.dataSource = 'ai_estimate',
    this.cfsMatchName,
    this.ragSteps,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    return FoodAnalysisResult(
      foodName: json['food_name'] ?? '',
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
      reasoning: json['reasoning'] ?? '',
      confidenceScore: json['confidence_score']?.toDouble(),
      dataSource: json['data_source'] ?? 'ai_estimate',
      cfsMatchName: json['cfs_match_name'],
    );
  }
}

/// Chat response model.
class ChatResponse {
  final String answer;
  final String? conversationId;
  
  ChatResponse({
    required this.answer,
    this.conversationId,
  });
  
  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      answer: json['answer'] ?? '',
      conversationId: json['conversation_id'],
    );
  }
}

/// Recipe model.
class Recipe {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int? totalCalories;
  final int? totalProtein;
  final int? totalCarbs;
  final int? totalFat;
  final List<dynamic> ingredients;
  final List<dynamic> steps;
  
  Recipe({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.totalCalories,
    this.totalProtein,
    this.totalCarbs,
    this.totalFat,
    this.ingredients = const [],
    this.steps = const [],
  });
  
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      totalCalories: json['total_calories'],
      totalProtein: json['total_protein'],
      totalCarbs: json['total_carbs'],
      totalFat: json['total_fat'],
      ingredients: json['ingredients'] ?? [],
      steps: json['steps'] ?? [],
    );
  }
}
