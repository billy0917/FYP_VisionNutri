/// SmartDiet AI - Manual Food Entry Screen
/// 
/// Screen for manually entering food nutritional information.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';

class ManualFoodEntryScreen extends StatefulWidget {
  const ManualFoodEntryScreen({super.key});

  @override
  State<ManualFoodEntryScreen> createState() => _ManualFoodEntryScreenState();
}

class _ManualFoodEntryScreenState extends State<ManualFoodEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  
  String? _selectedMealType;
  bool _isSaving = false;

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _saveFoodLog() async {
    if (!_formKey.currentState!.validate() || _selectedMealType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select meal type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await SupabaseService.client.from('food_logs').insert({
        'user_id': SupabaseService.currentUser!.id,
        'food_name': _foodNameController.text.trim(),
        'calories': int.parse(_caloriesController.text),
        'protein': double.parse(_proteinController.text),
        'carbs': double.parse(_carbsController.text),
        'fat': double.parse(_fatController.text),
        'meal_type': _selectedMealType,
        'logged_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food logged successfully! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return and notify saved
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Food Entry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Food name
              TextFormField(
                controller: _foodNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Food Name *',
                  hintText: 'e.g., Grilled Chicken Breast',
                  prefixIcon: Icon(Icons.restaurant),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter food name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Calories
              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Calories (kcal) *',
                  hintText: 'e.g., 250',
                  prefixIcon: Icon(Icons.local_fire_department),
                  suffixText: 'kcal',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter calories';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Protein, Carbs, Fat (one row, three fields)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Protein *',
                        hintText: '0',
                        suffixText: 'g',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Carbs *',
                        hintText: '0',
                        suffixText: 'g',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Fat *',
                        hintText: '0',
                        suffixText: 'g',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Meal type selector
              const Text(
                'Meal Type *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveFoodLog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Food Log',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),

              // Hint text
              Text(
                'Tip: You can also use the camera to scan food and get automatic nutritional estimates.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
