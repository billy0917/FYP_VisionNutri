/// SmartDiet AI - API Client
///
/// Calls AI APIs directly from the app — no local server required.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_diet_ai/core/config/app_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _systemPrompt =
      'You are an expert nutritionist AI. Analyze the food in the image and '
      'respond ONLY with a valid JSON object (no markdown, no extra text) in this exact format: '
      '{"food_name": "name", "calories": 0, "protein": 0, "carbs": 0, "fat": 0, '
      '"reasoning": "brief explanation"}. '
      'All numeric values must be integers. Be conservative when unsure. '
      'The reasoning field MUST be 50 words or fewer.';

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
      'max_tokens': 5000,
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

/// Food analysis result model.
class FoodAnalysisResult {
  final String foodName;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String reasoning;
  final double? confidenceScore;
  
  FoodAnalysisResult({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.reasoning,
    this.confidenceScore,
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
