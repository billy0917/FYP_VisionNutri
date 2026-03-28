/// SmartDiet AI — Profile Screen
///
/// Lets user view and edit their profile: physical stats, nutrition goals,
/// dietary restrictions, and allergies. Data saved to Supabase `profiles`.
library;

import 'package:flutter/material.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // ── Controllers ──────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _targetCalCtrl = TextEditingController();
  final _targetProCtrl = TextEditingController();
  final _targetCarbCtrl = TextEditingController();
  final _targetFatCtrl = TextEditingController();

  // ── Dropdown values ──────────────────────────────────────
  String? _gender;
  String _activityLevel = 'moderately_active';
  String _goalType = 'general_health';

  // ── Multi-select ─────────────────────────────────────────
  final List<String> _selectedRestrictions = [];
  final List<String> _selectedAllergies = [];

  static const _restrictionOptions = [
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Gluten-free',
    'Dairy-free',
    'Halal',
    'Kosher',
    'Keto',
    'Low-carb',
    'Low-sodium',
  ];

  static const _allergyOptions = [
    'Peanuts',
    'Tree nuts',
    'Milk',
    'Eggs',
    'Wheat',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame',
  ];

  static const _genderOptions = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
  };

  static const _activityOptions = {
    'sedentary': 'Sedentary (little or no exercise)',
    'lightly_active': 'Lightly active (1-3 days/week)',
    'moderately_active': 'Moderately active (3-5 days/week)',
    'very_active': 'Very active (6-7 days/week)',
    'extra_active': 'Extra active (physical job + exercise)',
  };

  static const _goalOptions = {
    'general_health': 'General Health',
    'weight_loss': 'Weight Loss',
    'maintenance': 'Maintenance',
    'hypertrophy': 'Muscle Gain / Hypertrophy',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetCalCtrl.dispose();
    _targetProCtrl.dispose();
    _targetCarbCtrl.dispose();
    _targetFatCtrl.dispose();
    super.dispose();
  }

  // ── Load ─────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _nameCtrl.text = profile['display_name'] ?? '';
          _gender = profile['gender'];
          _heightCtrl.text = _numStr(profile['height_cm']);
          _weightCtrl.text = _numStr(profile['weight_kg']);
          _activityLevel =
              profile['activity_level'] ?? 'moderately_active';
          _goalType = profile['goal_type'] ?? 'general_health';
          _targetCalCtrl.text = _numStr(profile['target_calories']);
          _targetProCtrl.text = _numStr(profile['target_protein']);
          _targetCarbCtrl.text = _numStr(profile['target_carbs']);
          _targetFatCtrl.text = _numStr(profile['target_fat']);
          _selectedRestrictions.addAll(
            List<String>.from(profile['dietary_restrictions'] ?? []),
          );
          _selectedAllergies.addAll(
            List<String>.from(profile['allergies'] ?? []),
          );
        });
      }
    } catch (_) {
      // New user — fields stay empty
    }
    if (mounted) setState(() => _isLoading = false);
  }

  static String _numStr(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      return v == v.toInt() ? v.toInt().toString() : v.toString();
    }
    return v.toString();
  }

  // ── Save ─────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'display_name': _nameCtrl.text.trim(),
      'gender': _gender,
      'height_cm': double.tryParse(_heightCtrl.text),
      'weight_kg': double.tryParse(_weightCtrl.text),
      'activity_level': _activityLevel,
      'goal_type': _goalType,
      'target_calories': int.tryParse(_targetCalCtrl.text),
      'target_protein': int.tryParse(_targetProCtrl.text),
      'target_carbs': int.tryParse(_targetCarbCtrl.text),
      'target_fat': int.tryParse(_targetFatCtrl.text),
      'dietary_restrictions': _selectedRestrictions,
      'allergies': _selectedAllergies,
    };

    // Compute BMR / TDEE if we have enough info
    final height = double.tryParse(_heightCtrl.text);
    final weight = double.tryParse(_weightCtrl.text);
    if (height != null && weight != null && _gender != null) {
      // Mifflin-St Jeor
      final bmr = (_gender == 'female')
          ? 10 * weight + 6.25 * height - 5 * 25 - 161 // rough age 25
          : 10 * weight + 6.25 * height - 5 * 25 + 5;
      const multipliers = {
        'sedentary': 1.2,
        'lightly_active': 1.375,
        'moderately_active': 1.55,
        'very_active': 1.725,
        'extra_active': 1.9,
      };
      final tdee = bmr * (multipliers[_activityLevel] ?? 1.55);
      data['bmr'] = bmr.round();
      data['tdee'] = tdee.round();

      // Auto-fill targets if empty
      if (_targetCalCtrl.text.isEmpty) {
        final cal = _goalType == 'weight_loss'
            ? (tdee - 500).round()
            : _goalType == 'hypertrophy'
                ? (tdee + 300).round()
                : tdee.round();
        data['target_calories'] = cal;
        _targetCalCtrl.text = cal.toString();
      }
    }

    try {
      await SupabaseService.updateUserProfile(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader(context, 'Basic Info'),
                  const SizedBox(height: 8),
                  _buildTextField(_nameCtrl, 'Display Name',
                      icon: Icons.person),
                  const SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: 'Gender',
                    value: _gender,
                    items: _genderOptions,
                    onChanged: (v) => setState(() => _gender = v),
                    icon: Icons.wc,
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Physical Stats'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(_heightCtrl, 'Height (cm)',
                            keyboardType: TextInputType.number,
                            icon: Icons.height),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(_weightCtrl, 'Weight (kg)',
                            keyboardType: TextInputType.number,
                            icon: Icons.monitor_weight_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown<String>(
                    label: 'Activity Level',
                    value: _activityLevel,
                    items: _activityOptions,
                    onChanged: (v) =>
                        setState(() => _activityLevel = v ?? _activityLevel),
                    icon: Icons.directions_run,
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Nutrition Goals'),
                  const SizedBox(height: 8),
                  _buildDropdown<String>(
                    label: 'Goal',
                    value: _goalType,
                    items: _goalOptions,
                    onChanged: (v) =>
                        setState(() => _goalType = v ?? _goalType),
                    icon: Icons.flag_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(_targetCalCtrl, 'Target Calories (kcal)',
                      keyboardType: TextInputType.number,
                      icon: Icons.local_fire_department,
                      hint: 'Auto-calculated if empty'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                            _targetProCtrl, 'Protein (g)',
                            keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(
                            _targetCarbCtrl, 'Carbs (g)',
                            keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTextField(_targetFatCtrl, 'Fat (g)',
                            keyboardType: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Dietary Restrictions'),
                  const SizedBox(height: 8),
                  _buildChipSelector(
                    options: _restrictionOptions,
                    selected: _selectedRestrictions,
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader(context, 'Allergies'),
                  const SizedBox(height: 8),
                  _buildChipSelector(
                    options: _allergyOptions,
                    selected: _selectedAllergies,
                  ),
                  const SizedBox(height: 32),

                  // Save button at bottom too
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: ClayColors.primary,
          ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    IconData? icon,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: items.containsKey(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: items.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildChipSelector({
    required List<String> options,
    required List<String> selected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((opt) {
        final isOn = selected.contains(opt);
        return FilterChip(
          label: Text(opt),
          selected: isOn,
          selectedColor: ClayColors.primaryMint,
          checkmarkColor: ClayColors.primaryDeep,
          onSelected: (val) {
            setState(() {
              val ? selected.add(opt) : selected.remove(opt);
            });
          },
        );
      }).toList(),
    );
  }
}
