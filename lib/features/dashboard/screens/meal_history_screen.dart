/// SmartDiet AI - Meal History Screen
///
/// Shows all historical meal records grouped by date.
library;

import 'package:flutter/material.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/features/dashboard/widgets/meal_thumbnail.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  List<Map<String, dynamic>> _allMeals = [];
  bool _isLoading = true;
  String? _error;

  // Group meals by date string (e.g. "Monday, Mar 15")
  Map<String, List<Map<String, dynamic>>> get _groupedMeals {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final meal in _allMeals) {
      final dateKey = _dateLabel(meal['logged_at'] as String?);
      grouped.putIfAbsent(dateKey, () => []).add(meal);
    }
    return grouped;
  }

  List<String> get _sortedDateKeys {
    final keys = _groupedMeals.keys.toList();
    // Sort newest first (relies on date label sort via raw dates in meals)
    keys.sort((a, b) {
      final aDate = _parseDateFromLabel(a);
      final bDate = _parseDateFromLabel(b);
      return bDate.compareTo(aDate);
    });
    return keys;
  }

  // Keep raw date -> label mapping for sorting
  final Map<String, DateTime> _dateKeyToDateTime = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = SupabaseService.currentUser!.id;

      final response = await SupabaseService.client
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .order('logged_at', ascending: false);

      setState(() {
        _allMeals = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _dateLabel(String? isoString) {
    if (isoString == null) return 'Unknown Date';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final mealDay = DateTime(dt.year, dt.month, dt.day);

      // Cache for sorting
      const daysOfWeek = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];

      String label;
      if (mealDay == today) {
        label = 'Today, ${months[dt.month - 1]} ${dt.day}';
      } else if (mealDay == yesterday) {
        label = 'Yesterday, ${months[dt.month - 1]} ${dt.day}';
      } else {
        label = '${daysOfWeek[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
        if (dt.year != now.year) {
          label += ' ${dt.year}';
        }
      }
      _dateKeyToDateTime[label] = mealDay;
      return label;
    } catch (e) {
      return 'Unknown Date';
    }
  }

  DateTime _parseDateFromLabel(String label) {
    return _dateKeyToDateTime[label] ?? DateTime(2000);
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  String _formatMealType(String? mealType) {
    if (mealType == null) return '';
    return mealType[0].toUpperCase() + mealType.substring(1);
  }

  Color _mealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return Colors.amber;
      case 'lunch': return Colors.green;
      case 'dinner': return Colors.indigo;
      case 'snack': return Colors.orange;
      default: return Colors.teal;
    }
  }

  // Calculate total calories for a group of meals
  int _groupCalories(List<Map<String, dynamic>> meals) {
    return meals.fold(0, (sum, m) => sum + ((m['calories'] as int?) ?? 0));
  }

  Future<bool?> _confirmDelete(String? foodName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${foodName ?? 'this meal'}" from your log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeal(String? mealId) async {
    if (mealId == null) return;
    try {
      await SupabaseService.client
          .from('food_logs')
          .delete()
          .eq('id', mealId);

      setState(() {
        _allMeals.removeWhere((m) => m['id'] == mealId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal deleted'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Failed to load history', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadHistory, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_allMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No meal history yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log your first meal to see it here!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sortedDateKeys.length,
        itemBuilder: (context, index) {
          final dateKey = _sortedDateKeys[index];
          final meals = _groupedMeals[dateKey]!;
          return _buildDateGroup(dateKey, meals);
        },
      ),
    );
  }

  Widget _buildDateGroup(String dateLabel, List<Map<String, dynamic>> meals) {
    final totalCal = _groupCalories(meals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalCal kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Meal cards for this date
        ...meals.map((meal) {
          final mealId = meal['id'] as String?;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: Key(mealId ?? meal.hashCode.toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.white),
                    SizedBox(height: 4),
                    Text('Delete',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              confirmDismiss: (_) => _confirmDelete(meal['food_name'] as String?),
              onDismissed: (_) => _deleteMeal(mealId),
              child: _buildMealCard(meal),
            ),
          );
        }),
        const Divider(height: 16),
      ],
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final mealType = meal['meal_type'] as String? ?? 'snack';
    final foodName = meal['food_name'] as String? ?? 'Unknown Food';
    final calories = meal['calories'] as int? ?? 0;
    final protein = (meal['protein'] as num?)?.toDouble() ?? 0.0;
    final carbs = (meal['carbs'] as num?)?.toDouble() ?? 0.0;
    final fat = (meal['fat'] as num?)?.toDouble() ?? 0.0;
    final localImagePath = meal['local_image_path'] as String?;
    final time = _formatTime(meal['logged_at']);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MealThumbnail(
            localImagePath: localImagePath,
            mealType: mealType,
            size: 72,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        foodName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        _mealTypeColor(mealType).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatMealType(mealType),
                    style: TextStyle(
                      fontSize: 11,
                      color: _mealTypeColor(mealType),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildNutrientBadge('$calories', 'kcal', Colors.orange),
                    const SizedBox(width: 6),
                    _buildNutrientBadge(
                        '${protein.toStringAsFixed(1)}g', 'P', Colors.blue),
                    const SizedBox(width: 6),
                    _buildNutrientBadge(
                        '${carbs.toStringAsFixed(1)}g', 'C', Colors.green),
                    const SizedBox(width: 6),
                    _buildNutrientBadge(
                        '${fat.toStringAsFixed(1)}g', 'F', Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 11,
          color: color.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
