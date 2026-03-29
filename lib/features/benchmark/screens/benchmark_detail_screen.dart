library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_diet_ai/features/benchmark/benchmark_models.dart';
import 'package:smart_diet_ai/features/benchmark/benchmark_service.dart';
import 'package:smart_diet_ai/features/camera/screens/ar_measure_screen.dart';

class BenchmarkDetailScreen extends StatefulWidget {
  final BenchmarkItem item;
  const BenchmarkDetailScreen({super.key, required this.item});

  @override
  State<BenchmarkDetailScreen> createState() => _BenchmarkDetailScreenState();
}

class _BenchmarkDetailScreenState extends State<BenchmarkDetailScreen> {
  final _service = BenchmarkService();
  late BenchmarkItem _item;
  Uint8List? _imageBytes;
  late bool _isFood;

  // Ground truth controllers
  final _nameCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  bool _running = false;
  String _runStatus = '';

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _isFood = _item.isFood;
    _nameCtrl.text = _item.foodName;
    final gt = _item.groundTruth;
    if (gt != null) {
      _widthCtrl.text = gt.widthCm.toString();
      _lengthCtrl.text = gt.lengthCm.toString();
      _heightCtrl.text = gt.heightCm.toString();
      _weightCtrl.text = gt.weightG?.toString() ?? '';
      _calCtrl.text = gt.calories?.toString() ?? '';
      _proteinCtrl.text = gt.protein?.toString() ?? '';
      _carbsCtrl.text = gt.carbs?.toString() ?? '';
      _fatCtrl.text = gt.fat?.toString() ?? '';
    }
    _loadImageBytes();
  }

  Future<void> _loadImageBytes() async {
    if (_item.imagePath != null) {
      final file = File(_item.imagePath!);
      if (await file.exists()) {
        _imageBytes = await file.readAsBytes();
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _widthCtrl.dispose();
    _lengthCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  // ── Photo capture ────────────────────────────────────────

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final cameraInfo = await _extractCameraInfo(bytes);

    // Save image locally
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/benchmark_images');
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = '${dir.path}/bm_${_item.id}.jpg';
    await File(path).writeAsBytes(bytes);

    setState(() {
      _imageBytes = bytes;
      _item.imagePath = path;
      _item.cameraInfo = cameraInfo;
    });
    _autoSave();
  }

  Future<String?> _extractCameraInfo(Uint8List bytes) async {
    try {
      final tags = await readExifFromBytes(bytes);
      if (tags.isEmpty) return null;
      final parts = <String>[];

      final fl = tags['EXIF FocalLength'];
      if (fl != null) parts.add('focal length ${fl}mm');
      final fl35Tag = tags['EXIF FocalLengthIn35mmFilm'];
      if (fl35Tag != null) parts.add('35mm equiv ${fl35Tag}mm');
      final fNum = tags['EXIF FNumber'];
      if (fNum != null) parts.add('f/$fNum');
      final iso = tags['EXIF ISOSpeedRatings'];
      if (iso != null) parts.add('ISO $iso');
      final wTag = tags['EXIF ExifImageWidth'] ?? tags['Image ImageWidth'];
      final hTag = tags['EXIF ExifImageLength'] ?? tags['Image ImageLength'];
      if (wTag != null && hTag != null) parts.add('$wTag×${hTag}px');
      final make = tags['Image Make'];
      final model = tags['Image Model'];
      if (make != null || model != null) parts.add('${make ?? ''} ${model ?? ''}'.trim());
      final dist = tags['EXIF SubjectDistance'];
      if (dist != null) parts.add('subject distance ${dist}m');

      // ── FOV calibration block ──────────────────────────────
      // Compute horizontal FOV from 35mm-equivalent focal length and give
      // the model a concrete formula to convert pixel widths → real cm.
      if (fl35Tag != null && wTag != null) {
        final fl35 = double.tryParse(
            fl35Tag.toString().split('/').first.trim());
        final wPx = double.tryParse(wTag.toString());
        if (fl35 != null && fl35 > 0 && wPx != null && wPx > 0) {
          // 35mm full-frame sensor half-width = 18mm
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

  // ── AR measurement ───────────────────────────────────────

  Future<void> _runArMeasurement() async {
    final result = await Navigator.push<FoodMeasurement>(
      context,
      MaterialPageRoute(builder: (_) => const ArMeasureScreen()),
    );
    if (result == null) return;
    setState(() {
      _item.arMeasurement = ArMeasurementData(
        widthCm: result.widthCm,
        lengthCm: result.lengthCm,
        heightCm: result.heightCm,
        volumeMl: result.volumeMl,
      );
    });
    _autoSave();
  }

  // ── Ground truth ─────────────────────────────────────────

  bool _validateGroundTruth() {
    final dimOk = _nameCtrl.text.trim().isNotEmpty &&
        double.tryParse(_widthCtrl.text) != null &&
        double.tryParse(_lengthCtrl.text) != null &&
        double.tryParse(_heightCtrl.text) != null;
    if (!dimOk) return false;
    if (!_isFood) return true; // dimensions only for objects
    // For food: also require weight & nutrition
    return double.tryParse(_weightCtrl.text) != null &&
        int.tryParse(_calCtrl.text) != null &&
        int.tryParse(_proteinCtrl.text) != null &&
        int.tryParse(_carbsCtrl.text) != null &&
        int.tryParse(_fatCtrl.text) != null;
  }

  void _saveGroundTruth() {
    if (!_validateGroundTruth()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFood
            ? 'Please fill all ground truth fields with valid numbers'
            : 'Please fill name and dimensions (W×L×H) with valid numbers')),
      );
      return;
    }
    _item.foodName = _nameCtrl.text.trim();
    _item.isFood = _isFood;
    _item.groundTruth = GroundTruth(
      widthCm: double.parse(_widthCtrl.text),
      lengthCm: double.parse(_lengthCtrl.text),
      heightCm: double.parse(_heightCtrl.text),
      weightG: double.tryParse(_weightCtrl.text),
      calories: int.tryParse(_calCtrl.text),
      protein: int.tryParse(_proteinCtrl.text),
      carbs: int.tryParse(_carbsCtrl.text),
      fat: int.tryParse(_fatCtrl.text),
    );
    _autoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ground truth saved')),
    );
  }

  // ── Run estimation methods ───────────────────────────────

  Future<void> _runAllMethods() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Take a photo first')),
      );
      return;
    }
    if (_item.groundTruth == null) {
      _saveGroundTruth();
      if (_item.groundTruth == null) return;
    }

    setState(() { _running = true; _runStatus = ''; });
    final b64 = base64Encode(_imageBytes!);

    // Method A: Pure Gemini (+ RAG if food)
    try {
      setState(() => _runStatus = _isFood
          ? 'Running Method A (pure Gemini + RAG)...'
          : 'Running Method A (pure Gemini, dims only)...');
      _item.methodA = await _service.runMethodA(b64, isFood: _isFood);
    } catch (e) {
      _item.methodA = EstimationResult(
        calories: 0, protein: 0, carbs: 0, fat: 0,
        reasoning: 'Error: $e',
      );
    }
    await _autoSave();
    if (!mounted) return;

    // Method B: Gemini + EXIF (+ RAG if food)
    try {
      setState(() => _runStatus = _isFood
          ? 'Running Method B (Gemini + EXIF + RAG)...'
          : 'Running Method B (Gemini + EXIF, dims only)...');
      _item.methodB = await _service.runMethodB(b64, _item.cameraInfo ?? '',
          isFood: _isFood);
    } catch (e) {
      _item.methodB = EstimationResult(
        calories: 0, protein: 0, carbs: 0, fat: 0,
        reasoning: 'Error: $e',
      );
    }
    await _autoSave();
    if (!mounted) return;

    // Method C: ARCore + Gemini (+ RAG if food)
    if (_item.arMeasurement != null) {
      try {
        setState(() => _runStatus = _isFood
            ? 'Running Method C (ARCore + Gemini + RAG)...'
            : 'Running Method C (ARCore + Gemini, dims only)...');
        _item.methodC = await _service.runMethodC(
          b64,
          _item.cameraInfo ?? '',
          _item.arMeasurement!,
          isFood: _isFood,
        );
      } catch (e) {
        _item.methodC = EstimationResult(
          calories: 0, protein: 0, carbs: 0, fat: 0,
          reasoning: 'Error: $e',
        );
      }
    } else {
      _item.methodC = EstimationResult(
        calories: 0, protein: 0, carbs: 0, fat: 0,
        reasoning: 'Skipped — no AR measurement available',
      );
    }

    await _autoSave();
    if (mounted) setState(() { _running = false; _runStatus = 'All methods complete'; });
  }

  Future<void> _autoSave() async {
    await _service.save(_item);
    if (mounted) setState(() {});
  }

  // ── Build UI ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_item.foodName.isEmpty ? 'New Item' : _item.foodName),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              _saveGroundTruth();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPhotoSection(),
            const SizedBox(height: 20),
            _buildArSection(),
            const SizedBox(height: 20),
            _buildGroundTruthSection(),
            const SizedBox(height: 20),
            _buildRunSection(),
            const SizedBox(height: 20),
            if (_item.methodA != null || _item.methodB != null || _item.methodC != null)
              _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  // ── Section A: Photo ─────────────────────────────────────

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_imageBytes!, height: 200, fit: BoxFit.cover),
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Icon(Icons.photo_camera, size: 48, color: Colors.grey)),
              ),
            const SizedBox(height: 8),
            if (_item.cameraInfo != null)
              Text(_item.cameraInfo!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_imageBytes != null ? 'Retake Photo' : 'Take Photo'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section B: AR Measurement ────────────────────────────

  Widget _buildArSection() {
    final ar = _item.arMeasurement;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AR Measurement', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (ar != null)
              Text(
                'W: ${ar.widthCm?.toStringAsFixed(1)} cm  '
                'L: ${ar.lengthCm?.toStringAsFixed(1)} cm  '
                'H: ${ar.heightCm?.toStringAsFixed(1)} cm\n'
                'Volume: ~${ar.volumeMl?.round()} mL',
              )
            else
              const Text('Not yet measured', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _runArMeasurement,
              icon: const Icon(Icons.straighten),
              label: Text(ar != null ? 'Re-measure' : 'Run AR Measurement'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section C: Ground Truth ──────────────────────────────

  Widget _buildGroundTruthSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ground Truth', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Food / Object toggle
            Row(children: [
              const Text('Type: '),
              ChoiceChip(
                label: const Text('Food'),
                selected: _isFood,
                onSelected: (v) => setState(() => _isFood = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Object'),
                selected: !_isFood,
                onSelected: (v) => setState(() => _isFood = false),
              ),
            ]),
            const SizedBox(height: 8),
            _textField(_nameCtrl, _isFood ? 'Food name' : 'Object name', TextInputType.text),
            const SizedBox(height: 8),
            Text('Dimensions', style: Theme.of(context).textTheme.labelLarge),
            Row(children: [
              Expanded(child: _numField(_widthCtrl, 'W (cm)')),
              const SizedBox(width: 8),
              Expanded(child: _numField(_lengthCtrl, 'L (cm)')),
              const SizedBox(width: 8),
              Expanded(child: _numField(_heightCtrl, 'H (cm)')),
            ]),
            if (_isFood) ...[
              const SizedBox(height: 8),
              _numField(_weightCtrl, 'Weight (g)'),
              const SizedBox(height: 8),
              Text('Nutrition', style: Theme.of(context).textTheme.labelLarge),
              Row(children: [
                Expanded(child: _numField(_calCtrl, 'Cal')),
                const SizedBox(width: 8),
                Expanded(child: _numField(_proteinCtrl, 'Protein (g)')),
              ]),
              Row(children: [
                Expanded(child: _numField(_carbsCtrl, 'Carbs (g)')),
                const SizedBox(width: 8),
                Expanded(child: _numField(_fatCtrl, 'Fat (g)')),
              ]),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saveGroundTruth,
              child: const Text('Save Ground Truth'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController c, String label, TextInputType type) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  // ── Section D: Run Methods ───────────────────────────────

  Widget _buildRunSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Estimation', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_running) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_runStatus, style: Theme.of(context).textTheme.bodySmall),
            ] else
              ElevatedButton.icon(
                onPressed:
                    (_imageBytes != null) ? _runAllMethods : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run All 3 Methods'),
              ),
            if (_runStatus.isNotEmpty && !_running)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_runStatus,
                    style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Results comparison ───────────────────────────────────

  Widget _buildResultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Results Comparison', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildComparisonTable(),
            if (_item.methodA?.reasoning.isNotEmpty == true) ...[
              const Divider(),
              _reasoningTile('A', _item.methodA!.reasoning),
            ],
            if (_item.methodB?.reasoning.isNotEmpty == true)
              _reasoningTile('B', _item.methodB!.reasoning),
            if (_item.methodC?.reasoning.isNotEmpty == true)
              _reasoningTile('C', _item.methodC!.reasoning),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable() {
    final gt = _item.groundTruth;
    final a = _item.methodA;
    final b = _item.methodB;
    final c = _item.methodC;

    Widget cell(String text, {bool header = false, Color? bg}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        color: bg,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: header ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    String fmt(num? v) => v == null ? '--' : (v is double ? v.toStringAsFixed(1) : v.toString());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(60),
        border: TableBorder.all(color: Colors.grey.shade300),
        children: [
          TableRow(children: [
            cell('', header: true),
            cell('GT', header: true, bg: Colors.grey[100]),
            cell('A', header: true, bg: Colors.blue[50]),
            cell('B', header: true, bg: Colors.orange[50]),
            cell('C', header: true, bg: Colors.green[50]),
          ]),
          _tableRow('W (cm)', gt?.widthCm, a?.widthCm, b?.widthCm, c?.widthCm, cell, fmt),
          _tableRow('L (cm)', gt?.lengthCm, a?.lengthCm, b?.lengthCm, c?.lengthCm, cell, fmt),
          _tableRow('H (cm)', gt?.heightCm, a?.heightCm, b?.heightCm, c?.heightCm, cell, fmt),
          if (_isFood) ...[
            _tableRow('Wt (g)', gt?.weightG, a?.weightG, b?.weightG, c?.weightG, cell, fmt),
            _tableRow('Cal', gt?.calories?.toDouble(), a?.calories.toDouble(), b?.calories.toDouble(), c?.calories.toDouble(), cell, fmt),
            _tableRow('Prot', gt?.protein?.toDouble(), a?.protein.toDouble(), b?.protein.toDouble(), c?.protein.toDouble(), cell, fmt),
            _tableRow('Carb', gt?.carbs?.toDouble(), a?.carbs.toDouble(), b?.carbs.toDouble(), c?.carbs.toDouble(), cell, fmt),
            _tableRow('Fat', gt?.fat?.toDouble(), a?.fat.toDouble(), b?.fat.toDouble(), c?.fat.toDouble(), cell, fmt),
          ],
        ],
      ),
    );
  }

  TableRow _tableRow(
    String label,
    num? gtVal,
    num? aVal,
    num? bVal,
    num? cVal,
    Widget Function(String, {bool header, Color? bg}) cell,
    String Function(num?) fmt,
  ) {
    return TableRow(children: [
      cell(label, header: true),
      cell(fmt(gtVal), bg: Colors.grey[50]),
      cell(fmt(aVal), bg: Colors.blue[50]),
      cell(fmt(bVal), bg: Colors.orange[50]),
      cell(fmt(cVal), bg: Colors.green[50]),
    ]);
  }

  Widget _reasoningTile(String method, String reasoning) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        title: Text('Method $method reasoning', style: const TextStyle(fontSize: 13)),
        childrenPadding: const EdgeInsets.all(8),
        children: [Text(reasoning, style: const TextStyle(fontSize: 12))],
      ),
    );
  }
}
