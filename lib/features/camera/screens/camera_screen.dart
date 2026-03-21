/// SmartDiet AI - Camera Screen
/// 
/// Screen for capturing food images and getting AI analysis.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_diet_ai/core/services/api_client.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';

// dart:io is only used on non-web platforms
import 'package:smart_diet_ai/features/camera/screens/camera_io_helper.dart'
    if (dart.library.html) 'package:smart_diet_ai/features/camera/screens/camera_web_helper.dart';

class CameraScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const CameraScreen({super.key, this.onSaved});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _localImagePath;  // null on web
  bool _isAnalyzing = false;
  FoodAnalysisResult? _analysisResult;
  String? _selectedMealType;

  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Read image bytes
        final bytes = await image.readAsBytes();
        
        // Save to local app directory
        final localPath = await _saveImageLocally(bytes);
        
        setState(() {
          _imageBytes = bytes;
          _localImagePath = localPath;
          _analysisResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Save image to local app directory (skipped on Web)
  Future<String?> _saveImageLocally(Uint8List bytes) async {
    if (kIsWeb) return null; // Web does not support local file system
    return saveImageToLocalStorage(bytes);
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // Encode image as base64 and send to backend
      final base64Image = base64Encode(_imageBytes!);
      final result = await ApiClient().analyzeFoodWithRag(
        imageBase64: base64Image,
      );

      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveFoodLog() async {
    if (_analysisResult == null || _selectedMealType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a meal type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Save to Supabase (only store analysis result, exclude potentially missing fields)
      await SupabaseService.client.from('food_logs').insert({
        'user_id': SupabaseService.currentUser!.id,
        'food_name': _analysisResult!.foodName,
        'calories': _analysisResult!.calories,
        'protein': _analysisResult!.protein,
        'carbs': _analysisResult!.carbs,
        'fat': _analysisResult!.fat,
        'meal_type': _selectedMealType!.toLowerCase(),
        'local_image_path': _localImagePath,
        'ai_reasoning': _analysisResult!.reasoning,
        'logged_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal logged successfully! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        // Notify Dashboard to reload
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Reset state
    setState(() {
      _imageBytes = null;
      _analysisResult = null;
      _selectedMealType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image capture section
            _buildImageSection(),
            const SizedBox(height: 16),

            // Analysis result section
            if (_analysisResult != null) ...[
              _buildAnalysisResultCard(),
              const SizedBox(height: 16),
              _buildMealTypeSelector(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _saveFoodLog,
                icon: const Icon(Icons.save),
                label: const Text('Save to Food Log'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: ClayDecoration.card(isDark: isDark),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Image preview or placeholder
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? ClayColors.darkSurface : ClayColors.surfaceDim,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a photo of your food',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ),
          // Analyze button
          if (_imageBytes != null && _analysisResult == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeImage,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResultCard() {
    final result = _analysisResult!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: ClayDecoration.card(isDark: isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: ClayColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Nutrition Analysis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (result.dataSource == 'cfs_official')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 11, color: Colors.green.shade700),
                        const SizedBox(width: 3),
                        Text(
                          '食安中心官方數據',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'AI Estimate',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              result.foodName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (result.cfsMatchName != null) ...[  
              const SizedBox(height: 4),
              Text(
                'CFS match: ${result.cfsMatchName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Macros grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroItem('Calories', '${result.calories}', 'kcal', ClayColors.calorie),
                _buildMacroItem('Protein', '${result.protein}', 'g', ClayColors.protein),
                _buildMacroItem('Carbs', '${result.carbs}', 'g', ClayColors.carbs),
                _buildMacroItem('Fat', '${result.fat}', 'g', ClayColors.fat),
              ],
            ),
            if (result.reasoning.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'AI Reasoning:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                result.reasoning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
    );
  }

  Widget _buildMacroItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMealTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: ClayDecoration.card(isDark: isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meal Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _mealTypes.map((type) {
                final isSelected = _selectedMealType == type;
                return ChoiceChip(
                  label: Text(
                    type[0].toUpperCase() + type.substring(1),
                    style: TextStyle(
                      color: isSelected ? Colors.white : ClayColors.primaryDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  onSelected: (selected) {
                    setState(() {
                      _selectedMealType = selected ? type : null;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
    );
  }
}
