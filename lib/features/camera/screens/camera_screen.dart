/// SmartDiet AI - Camera Screen
///
/// Screen for capturing food images and getting AI analysis.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:exif/exif.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_diet_ai/core/services/api_client.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/core/services/volume_service.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';
import 'package:smart_diet_ai/features/camera/screens/ar_measure_screen.dart';

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
  String? _localImagePath; // null on web
  bool _isAnalyzing = false;
  bool _isPreparingSegmentation = false;
  FoodAnalysisResult? _analysisResult;
  String? _selectedMealType;
  String? _cameraInfo; // EXIF-derived description for LLM
  ArMeasurement? _arMeasurement; // ARCore measurement result
  VolumeEstimationResult? _segmentationResult;
  double? _previewAspectRatio;

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

        // Extract EXIF metadata for the LLM
        final camInfo = await _extractCameraInfo(bytes);

        // Save to local app directory
        final localPath = await _saveImageLocally(bytes);

        setState(() {
          _imageBytes = bytes;
          _localImagePath = localPath;
          _analysisResult = null;
          _selectedMealType = null;
          _cameraInfo = camInfo;
          _arMeasurement = null;
          _segmentationResult = null;
          _previewAspectRatio = null;
        });

        final aspectRatio = await _readImageAspectRatio(bytes);
        if (mounted && _imageBytes == bytes) {
          setState(() {
            _previewAspectRatio = aspectRatio;
          });
        }
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

  Future<void> _prepareSegmentationPreview(Uint8List bytes) async {
    setState(() {
      _isPreparingSegmentation = true;
    });

    try {
      final result = await VolumeService().estimateVolume(imageBytes: bytes);
      if (!mounted || _imageBytes != bytes) {
        return;
      }
      setState(() {
        _segmentationResult = result.hasEstimate ? result : null;
      });
    } catch (_) {
      if (!mounted || _imageBytes != bytes) {
        return;
      }
      setState(() {
        _segmentationResult = null;
      });
    } finally {
      if (mounted && _imageBytes == bytes) {
        setState(() {
          _isPreparingSegmentation = false;
        });
      }
    }
  }

  Future<double> _readImageAspectRatio(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      return descriptor.width / descriptor.height;
    } finally {
      buffer.dispose();
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // Encode image as base64 and send to AI
      final base64Image = base64Encode(_imageBytes!);

      // Build combined camera context
      String? fullCameraInfo;
      final parts = <String>[];
      if (_cameraInfo != null) parts.add(_cameraInfo!);
      if (_arMeasurement != null) parts.add(_arMeasurement!.toPromptContext());
      if (parts.isNotEmpty) fullCameraInfo = parts.join('. ');

      final result = await ApiClient().analyzeFoodWithRag(
        imageBase64: base64Image,
        cameraInfo: fullCameraInfo,
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
      _cameraInfo = null;
      _arMeasurement = null;
      _segmentationResult = null;
      _previewAspectRatio = null;
    });
  }

  /// Extract useful EXIF camera metadata and format as a one-line LLM context.
  /// Also computes horizontal FOV from 35mm equiv focal length and appends an
  /// OPTICS block so the model can calibrate its dimension estimates (Method B).
  Future<String?> _extractCameraInfo(Uint8List bytes) async {
    try {
      final tags = await readExifFromBytes(bytes);
      if (tags.isEmpty) return null;

      final parts = <String>[];

      // Focal length (actual mm)
      final fl = tags['EXIF FocalLength'];
      if (fl != null) parts.add('focal length ${fl}mm');

      // 35mm equivalent focal length
      final fl35Tag = tags['EXIF FocalLengthIn35mmFilm'];
      if (fl35Tag != null) parts.add('35mm equiv ${fl35Tag}mm');

      // Aperture
      final fNum = tags['EXIF FNumber'];
      if (fNum != null) parts.add('f/$fNum');

      // ISO
      final iso = tags['EXIF ISOSpeedRatings'];
      if (iso != null) parts.add('ISO $iso');

      // Image dimensions
      final wTag = tags['EXIF ExifImageWidth'] ?? tags['Image ImageWidth'];
      final h = tags['EXIF ExifImageLength'] ?? tags['Image ImageLength'];
      if (wTag != null && h != null) parts.add('$wTag×${h}px');

      // Camera make/model
      final make = tags['Image Make'];
      final model = tags['Image Model'];
      if (make != null || model != null) {
        parts.add('${make ?? ''} ${model ?? ''}'.trim());
      }

      // Subject distance (if available — rare but very useful)
      final dist = tags['EXIF SubjectDistance'];
      if (dist != null) parts.add('subject distance ${dist}m');

      // FOV calibration block (Method B) — computed from 35mm equiv focal length
      if (fl35Tag != null && wTag != null) {
        final fl35 = double.tryParse(fl35Tag.toString().split('/').first.trim());
        final wPx = double.tryParse(wTag.toString());
        if (fl35 != null && fl35 > 0 && wPx != null && wPx > 0) {
          final fovRad = 2 * math.atan(18.0 / fl35);
          final fovDeg = fovRad * 180 / math.pi;
          final degPerPx = fovDeg / wPx;
          parts.add(
            'OPTICS: horizontal FOV=${fovDeg.toStringAsFixed(1)}°, '
            '${wPx.toInt()}px wide → '
            '${degPerPx.toStringAsFixed(4)}°/px. '
            'To convert food container width: '
            'estimate subject distance D_cm from scene depth cues, '
            'then real_width_cm = '
            '2 × D_cm × tan(container_width_px × ${degPerPx.toStringAsFixed(4)} × π/360). '
            'Use this formula in step 1 to calibrate your dimension estimates.',
          );
        }
      }

      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
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
    final previewAspectRatio = _previewAspectRatio ?? 4 / 3;
    return Container(
      decoration: ClayDecoration.card(isDark: isDark),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Image preview or placeholder
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? ClayColors.darkSurface : ClayColors.surfaceDim,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: _imageBytes != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: previewAspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isDark
                                ? ClayColors.darkSurface
                                : Colors.white.withAlpha(217),
                          ),
                          child: Image.memory(
                            _imageBytes!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 250,
                    child: Column(
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
          // Measurement button (shown after photo is taken)
          if (_imageBytes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: OutlinedButton.icon(
                onPressed: _launchMeasure,
                icon: const Icon(Icons.straighten, color: Colors.deepPurple),
                label: Text(
                  _arMeasurement == null
                      ? '📏 尺寸量測 Size Measurement (optional)'
                      : '📏 重新量測 Re-measure',
                  style: const TextStyle(color: Colors.deepPurple),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.deepPurple),
                ),
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

          // Measurement display
          if (_arMeasurement != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      color: Colors.deepPurple.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_arMeasurement!.widthCm?.toStringAsFixed(1)} × '
                        '${_arMeasurement!.lengthCm?.toStringAsFixed(1)} × '
                        '${_arMeasurement!.heightCm?.toStringAsFixed(1)} cm  →  '
                        '~${_arMeasurement!.volumeMl?.round()} mL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _arMeasurement = null),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentationStatus() {
    final result = _segmentationResult;
    if (_isPreparingSegmentation) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Mask preview is being prepared on-device.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    if (result == null || !result.hasEstimate) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No usable mask was detected for this image.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Mask preview: ${result.confidence} confidence, ${(result.foodPixelRatio * 100).toStringAsFixed(0)}% foreground coverage.',
        style: TextStyle(
          fontSize: 12,
          color: result.confidence == 'high'
              ? Colors.green.shade700
              : Colors.blueGrey.shade700,
          fontWeight: FontWeight.w600,
        ),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (result.dataSource == 'cfs_official')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 11,
                        color: Colors.green.shade700,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AI Estimate',
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.foodName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
              _buildMacroItem(
                'Calories',
                '${result.calories}',
                'kcal',
                ClayColors.calorie,
              ),
              _buildMacroItem(
                'Protein',
                '${result.protein}',
                'g',
                ClayColors.protein,
              ),
              _buildMacroItem(
                'Carbs',
                '${result.carbs}',
                'g',
                ClayColors.carbs,
              ),
              _buildMacroItem('Fat', '${result.fat}', 'g', ClayColors.fat),
            ],
          ),
          if (result.reasoning.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'AI Reasoning:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              result.reasoning,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
          if (result.ragSteps != null && result.ragSteps!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '🔍 RAG Pipeline Details',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[700],
                  ),
                ),
                children: result.ragSteps!
                    .map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[600],
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: SelectableText(
                                step.output,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: Colors.grey[800],
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
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
        Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

  /// Launch the AR measurement screen.
  Future<void> _launchMeasure() async {
    final result = await Navigator.of(context).push<FoodMeasurement>(
      MaterialPageRoute(builder: (_) => const ArMeasureScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _arMeasurement = result;
        _analysisResult = null;
        _selectedMealType = null;
      });
    }
  }
}
