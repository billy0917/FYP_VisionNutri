/// SmartDiet AI — Chat Service
///
/// Builds diet context from 30-day records, generates suggestion chips,
/// streams Gemini responses, and optionally triggers CFS RAG for food queries.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_diet_ai/core/config/app_config.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._();
  factory ChatService() => _instance;
  ChatService._();

  // ── 1. Diet Context ──────────────────────────────────────

  /// Fetch 30-day daily_stats + user profile and format as a compact text block
  /// suitable for injection into the Gemini system prompt.
  Future<String> buildDietContext() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return 'User not logged in. No dietary data available.';

    final buf = StringBuffer();

    // --- Profile & targets ---
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (profile != null) {
        final name = profile['display_name'] ?? '';
        final goal = profile['goal_type'] ?? '';
        final tCal = profile['target_calories'];
        final tPro = profile['target_protein'];
        final tCarb = profile['target_carbs'];
        final tFat = profile['target_fat'];
        final restrictions = profile['dietary_restrictions'];
        final allergies = profile['allergies'];
        final gender = profile['gender'] ?? '';
        final height = profile['height_cm'];
        final weight = profile['weight_kg'];
        final activity = profile['activity_level'] ?? '';

        buf.writeln('## User Profile');
        if (name.toString().isNotEmpty) buf.writeln('Name: $name');
        if (gender.toString().isNotEmpty) buf.writeln('Gender: $gender');
        if (height != null) buf.writeln('Height: ${height}cm');
        if (weight != null) buf.writeln('Weight: ${weight}kg');
        if (activity.toString().isNotEmpty) buf.writeln('Activity: $activity');
        if (goal.toString().isNotEmpty) buf.writeln('Goal: $goal');
        if (tCal != null) {
          buf.writeln(
              'Daily targets: ${tCal}kcal, protein ${tPro}g, carbs ${tCarb}g, fat ${tFat}g');
        }
        if (restrictions != null && (restrictions as List).isNotEmpty) {
          buf.writeln('Dietary restrictions: ${restrictions.join(', ')}');
        }
        if (allergies != null && (allergies as List).isNotEmpty) {
          buf.writeln('Allergies: ${allergies.join(', ')}');
        }
        buf.writeln();
      }
    } catch (_) {
      // Profile unavailable — continue without it
    }

    // --- 30-day food logs (raw records) ---
    try {
      final since =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      final rows = await SupabaseService.client
          .from('food_logs')
          .select(
              'food_name, calories, protein, carbs, fat, meal_type, logged_at')
          .eq('user_id', uid)
          .gte('logged_at', since)
          .order('logged_at', ascending: true);

      final logs = List<Map<String, dynamic>>.from(rows as List? ?? []);

      if (logs.isNotEmpty) {
        buf.writeln('## Food Log (last 30 days, ${logs.length} entries)');
        buf.writeln('Date | Meal | Food | Cal | P | C | F');
        for (final l in logs) {
          final date = (l['logged_at'] as String?)?.substring(0, 10) ?? '?';
          final meal = l['meal_type'] ?? '';
          final name = l['food_name'] ?? '?';
          buf.writeln(
            '$date | $meal | $name | '
            '${l['calories'] ?? 0}kcal | ${l['protein'] ?? 0}g | '
            '${l['carbs'] ?? 0}g | ${l['fat'] ?? 0}g',
          );
        }

        // Compute totals per day and averages
        final dailyTotals = <String, Map<String, num>>{};
        for (final l in logs) {
          final date = (l['logged_at'] as String?)?.substring(0, 10) ?? '?';
          final day = dailyTotals.putIfAbsent(
              date, () => {'cal': 0, 'pro': 0, 'carb': 0, 'fat': 0});
          day['cal'] = day['cal']! + (l['calories'] as num? ?? 0);
          day['pro'] = day['pro']! + (l['protein'] as num? ?? 0);
          day['carb'] = day['carb']! + (l['carbs'] as num? ?? 0);
          day['fat'] = day['fat']! + (l['fat'] as num? ?? 0);
        }
        final n = dailyTotals.length;
        final avgCal =
            dailyTotals.values.fold<num>(0, (s, d) => s + d['cal']!) / n;
        final avgPro =
            dailyTotals.values.fold<num>(0, (s, d) => s + d['pro']!) / n;
        final avgCarb =
            dailyTotals.values.fold<num>(0, (s, d) => s + d['carb']!) / n;
        final avgFat =
            dailyTotals.values.fold<num>(0, (s, d) => s + d['fat']!) / n;
        buf.writeln();
        buf.writeln(
          'Daily averages ($n days): ${avgCal.round()}kcal, '
          'protein ${avgPro.round()}g, carbs ${avgCarb.round()}g, '
          'fat ${avgFat.round()}g',
        );
      } else {
        buf.writeln('No food logs in the past 30 days.');
      }
    } catch (_) {
      buf.writeln('Could not load food logs.');
    }

    return buf.toString();
  }

  // ── 2. Suggestion Generation ─────────────────────────────

  /// Ask Gemini to generate 3-4 personalised suggestion questions based on
  /// the user's 30-day dietary context.
  Future<List<String>> generateSuggestions(String dietContext) async {
    const prompt =
        'You are a friendly AI nutritionist. Based on the user data below, '
        'generate exactly 4 short suggested questions (each ≤15 words) the user '
        'might want to ask you. Return ONLY a JSON array of strings, no other text.\n\n';

    try {
      final body = jsonEncode({
        'model': AppConfig.visionModel,
        'max_tokens': 500,
        'temperature': 0.7,
        'messages': [
          {'role': 'system', 'content': prompt + dietContext},
          {'role': 'user', 'content': 'Generate 4 suggested questions.'},
        ],
      });

      final response = await http
          .post(
            Uri.parse(AppConfig.visionApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.visionApiKey}',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        var content =
            decoded['choices'][0]['message']['content'] as String;
        // Strip markdown fences
        content = content.replaceAll(RegExp(r'```json\s*'), '');
        content = content.replaceAll(RegExp(r'```\s*'), '');
        content = content.trim();
        final list = (jsonDecode(content) as List).cast<String>();
        return list.take(4).toList();
      }
    } catch (_) {
      // Fallback below
    }

    return _fallbackSuggestions;
  }

  static const _fallbackSuggestions = [
    'How was my nutrition this week?',
    'What should I eat for dinner?',
    'Am I getting enough protein?',
    'Suggest a healthy snack',
  ];

  // ── 3. RAG Trigger Detection (LLM-based) ──────────────────

  /// Ask Gemini to decide whether the user is asking about a specific food's
  /// nutrition and, if so, extract the clean food name for CFS lookup.
  ///
  /// Returns the food name to search, or null if RAG should not trigger.
  Future<String?> detectFoodQuery(String message) async {
    const prompt =
        'You are a food-query classifier for a nutrition app.\n'
        'Given a user message, decide whether the user is asking about a '
        'SPECIFIC food item\'s nutritional information (calories, protein, '
        'carbs, fat, etc.).\n\n'
        'Rules:\n'
        '- If yes, return the clean food name only (no extra words) in the '
        'original language.\n'
        '- If the message is general advice, greetings, or not about a '
        'specific food, return exactly: null\n\n'
        'Return ONLY a JSON object. Examples:\n'
        '"梅菜扣肉有什麼營養" → {"food":"梅菜扣肉"}\n'
        '"雞蛋有幾多蛋白質" → {"food":"雞蛋"}\n'
        '"How many calories in salmon" → {"food":"salmon"}\n'
        '"今日食左什麼好" → {"food":null}\n'
        '"我應該減肥嗎" → {"food":null}\n'
        '"幫我分析下飲食" → {"food":null}\n';

    try {
      final body = jsonEncode({
        'model': AppConfig.visionModel,
        'max_tokens': 60,
        'temperature': 0,
        'messages': [
          {'role': 'system', 'content': prompt},
          {'role': 'user', 'content': message},
        ],
      });

      final response = await http
          .post(
            Uri.parse(AppConfig.visionApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.visionApiKey}',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        var content =
            decoded['choices'][0]['message']['content'] as String;
        content = content.replaceAll(RegExp(r'```json\s*'), '');
        content = content.replaceAll(RegExp(r'```\s*'), '');
        content = content.trim();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final food = json['food'];
        if (food is String && food.isNotEmpty) return food;
      }
    } catch (_) {
      // On failure, skip RAG — the main chat still works fine without it
    }
    return null;
  }

  // ── 4. CFS Food Search ──────────────────────────────────

  /// Search the CFS database for a food name. Returns formatted context string.
  /// Reuses the same text→vector fallback pattern as the RAG pipeline.
  Future<String?> searchCfsFood(String foodName) async {
    try {
      // A) Text search (Chinese)
      final textHits = await SupabaseService.client
          .from('cfs_foods')
          .select(
              'food_name_chi, food_name_eng, energy_kcal, protein_g, carbohydrate_g, fat_g')
          .ilike('food_name_chi', '%$foodName%')
          .limit(3);

      var hits = List<Map<String, dynamic>>.from(textHits as List? ?? []);

      // B) Vector search fallback
      if (hits.isEmpty) {
        final embedResponse = await http
            .post(
              Uri.parse(AppConfig.embeddingApiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${AppConfig.embeddingApiKey}',
              },
              body: jsonEncode({
                'model': AppConfig.embeddingModel,
                'input': foodName,
                'dimensions': AppConfig.embeddingDimensions,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (embedResponse.statusCode == 200) {
          final embedData = jsonDecode(embedResponse.body);
          final embedding =
              (embedData['data'][0]['embedding'] as List).cast<double>();
          final response =
              await SupabaseService.client.rpc('match_cfs_food', params: {
            'query_embedding': embedding,
            'match_count': 3,
            'match_threshold': 0.45,
          });
          hits = List<Map<String, dynamic>>.from(response as List? ?? []);
        }
      }

      if (hits.isEmpty) return null;

      final buf = StringBuffer();
      buf.writeln(
          '\n[CFS Official Nutrition Data — Hong Kong Centre for Food Safety (香港食物安全中心)]');
      buf.writeln('INSTRUCTION: When using the data below, explicitly cite "according to the Hong Kong Centre for Food Safety (CFS) database" (or 「根據香港食物安全中心數據庫」 if replying in Chinese/Cantonese).');
      for (final m in hits) {
        final name =
            '${m['food_name_eng'] ?? ''} (${m['food_name_chi'] ?? ''})';
        final fat = m['fat_g'];
        final fatStr =
            (fat == null || fat.toString() == 'null') ? 'N/A' : '${fat}g';
        buf.writeln(
          '• $name — per 100g: ${m['energy_kcal']}kcal, '
          'protein ${m['protein_g']}g, carbs ${m['carbohydrate_g']}g, fat $fatStr',
        );
      }
      return buf.toString();
    } catch (_) {
      return null;
    }
  }

  // ── 5. Streaming Chat ───────────────────────────────────

  /// System prompt for the nutritionist chat.
  static String buildSystemPrompt(String dietContext) {
    return 'You are an expert AI nutritionist integrated into the SmartDiet AI app. '
        'You have access to the user\'s real dietary data shown below. '
        'Reference specific dates and numbers when relevant. '
        'Give concise, actionable advice. '
        'When the user message contains CFS nutrition data, always cite the source '
        '(「根據香港食物安全中心數據庫」 in Chinese/Cantonese, or '
        '"according to the Hong Kong Centre for Food Safety (CFS) database" in English). '
        'Reply in the SAME LANGUAGE as the user\'s message.\n\n'
        '$dietContext';
  }

  /// Send a chat message and stream back Gemini's response token by token.
  ///
  /// [messages] is the full conversation history (user + assistant turns).
  /// [dietContext] is injected as the system prompt.
  /// [cfsContext] is optional CFS RAG data appended to the latest user message.
  Stream<String> streamChat({
    required List<Map<String, String>> messages,
    required String dietContext,
    String? cfsContext,
  }) async* {
    final systemPrompt = buildSystemPrompt(dietContext);

    // Build the OpenAI-compatible messages array
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];
    for (final m in messages) {
      apiMessages.add({'role': m['role']!, 'content': m['content']!});
    }

    // Append CFS context to latest user message if available
    if (cfsContext != null && apiMessages.isNotEmpty) {
      final last = apiMessages.last;
      if (last['role'] == 'user') {
        apiMessages.last = {
          'role': 'user',
          'content': '${last['content']}\n\n$cfsContext',
        };
      }
    }

    final body = jsonEncode({
      'model': AppConfig.visionModel,
      'max_tokens': 4000,
      'temperature': 0.6,
      'stream': true,
      'messages': apiMessages,
    });

    final request = http.Request('POST', Uri.parse(AppConfig.visionApiUrl));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AppConfig.visionApiKey}',
    });
    request.body = body;

    final client = http.Client();
    try {
      final streamedResponse =
          await client.send(request).timeout(const Duration(seconds: 90));

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception('API error ${streamedResponse.statusCode}: $errorBody');
      }

      // Buffer for partial SSE lines
      String lineBuffer = '';

      await for (final chunk
          in streamedResponse.stream
              .transform(utf8.decoder)
              .timeout(const Duration(seconds: 60))) {
        lineBuffer += chunk;

        // Process complete lines
        while (lineBuffer.contains('\n')) {
          final idx = lineBuffer.indexOf('\n');
          final line = lineBuffer.substring(0, idx).trim();
          lineBuffer = lineBuffer.substring(idx + 1);

          if (line.isEmpty) continue;
          if (!line.startsWith('data: ')) continue;

          final payload = line.substring(6);
          if (payload == '[DONE]') return;

          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta =
                  choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } catch (_) {
            // Skip malformed SSE lines
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
