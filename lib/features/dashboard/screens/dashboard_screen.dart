/// SmartDiet AI - Dashboard Screen
/// 
/// Main home screen showing daily stats, gamification, and quick actions.
library;

import 'package:flutter/material.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';
import 'package:smart_diet_ai/features/auth/screens/login_screen.dart';
import 'package:smart_diet_ai/features/camera/screens/camera_screen.dart';
import 'package:smart_diet_ai/features/chat/screens/chat_screen.dart';
import 'package:smart_diet_ai/features/food_entry/screens/manual_food_entry_screen.dart';
import 'package:smart_diet_ai/features/dashboard/widgets/meal_thumbnail.dart';
import 'package:smart_diet_ai/features/dashboard/screens/meal_history_screen.dart';
import 'package:smart_diet_ai/features/profile/screens/profile_screen.dart';
import 'package:smart_diet_ai/features/settings/screens/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  
  // Real data from Supabase
  Map<String, dynamic> _dailyStats = {
    'calories': 0,
    'targetCalories': 2000,
    'protein': 0.0,
    'targetProtein': 120,
    'carbs': 0.0,
    'fat': 0.0,
    'mealsLogged': 0,
  };
  
  List<Map<String, dynamic>> _recentMeals = [];
  bool _isLoading = true;

  void _showBottomSnackBar(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration,
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartDiet AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'logout') {
                await SupabaseService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardContent(),
          CameraScreen(
            onSaved: () {
              setState(() => _currentIndex = 0);
              _loadDashboardData();
            },
          ),
          const ChatScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? ClayColors.darkSurfaceCard
              : ClayColors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? ClayColors.darkShadowDark
                  : ClayColors.shadowDark,
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // Reload data when switching back to Dashboard
          if (index == 0) {
            _loadDashboardData();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Log Food',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'AI Chat',
          ),
        ],
      ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Manual entry button
                FloatingActionButton(
                  heroTag: 'manual_entry',
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManualFoodEntryScreen(),
                      ),
                    );
                    if (result == true) {
                      // Reload data
                      _loadDashboardData();
                    }
                  },
                  child: const Icon(Icons.edit),
                ),
                const SizedBox(height: 12),
                // Camera button
                FloatingActionButton.extended(
                  heroTag: 'camera',
                  onPressed: () {
                    setState(() => _currentIndex = 1);
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Log Meal'),
                ),
              ],
            )
          : null,
    );
  }

  /// Hong Kong time (UTC+8).
  static DateTime _hkt() => DateTime.now().toUtc().add(const Duration(hours: 8));

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUser!.id;
      final today = _hkt();
      final startOfDay = DateTime.utc(today.year, today.month, today.day)
          .subtract(const Duration(hours: 8));

      // Load today's food logs
      final foodLogsResponse = await SupabaseService.client
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .order('logged_at', ascending: false);

      _recentMeals = List<Map<String, dynamic>>.from(foodLogsResponse);

      // Calculate daily nutrition totals
      int totalCalories = 0;
      double totalProtein = 0.0;
      double totalCarbs = 0.0;
      double totalFat = 0.0;

      for (var meal in _recentMeals) {
        totalCalories += (meal['calories'] as int?) ?? 0;
        totalProtein += (meal['protein'] as num?)?.toDouble() ?? 0.0;
        totalCarbs += (meal['carbs'] as num?)?.toDouble() ?? 0.0;
        totalFat += (meal['fat'] as num?)?.toDouble() ?? 0.0;
      }

      setState(() {
        _dailyStats = {
          'calories': totalCalories,
          'targetCalories': 2000,
          'protein': totalProtein,
          'targetProtein': 120,
          'carbs': totalCarbs,
          'fat': totalFat,
          'mealsLogged': _recentMeals.length,
        };

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showBottomSnackBar(
          'Failed to load data: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingHeader(),
            const SizedBox(height: 20),
            _buildCalorieHeroCard(),
            const SizedBox(height: 16),
            _buildMacrosCard(),
            const SizedBox(height: 16),
            _buildRecentMealsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    final now = _hkt();
    final hour = now.hour;
    final String greeting;
    if (hour < 12) {
      greeting = 'Good morning!';
    } else if (hour < 18) {
      greeting = 'Good afternoon!';
    } else {
      greeting = 'Good evening!';
    }
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ClayColors.primaryDeep,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ClayColors.primaryLight,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ClayDecoration.badge(color: ClayColors.primary),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant, size: 16, color: ClayColors.primaryDeep),
                const SizedBox(width: 5),
                Text(
                  '${_dailyStats['mealsLogged']} meals today',
                  style: const TextStyle(
                    color: ClayColors.primaryDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieHeroCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calories = _dailyStats['calories'] as int;
    final targetCalories = _dailyStats['targetCalories'] as int;
    final calorieProgress = (calories / targetCalories).clamp(0.0, 1.0);
    final protein = (_dailyStats['protein'] as num).toDouble();
    final targetProtein = _dailyStats['targetProtein'] as int;
    final proteinProgress = (protein / targetProtein).clamp(0.0, 1.0);
    final remaining = (targetCalories - calories).clamp(0, targetCalories);
    final isOverTarget = calories > targetCalories;

    return Container(
      decoration: ClayDecoration.card(isDark: isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Calories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$calories',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ClayColors.calorie,
                      height: 1.0,
                    ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '/ $targetCalories kcal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOverTarget ? 'Over' : 'Remaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                  Text(
                    isOverTarget
                        ? '+${calories - targetCalories}'
                        : '$remaining',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isOverTarget ? ClayColors.error : ClayColors.primary,
                        ),
                  ),
                  Text(
                    'kcal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: calorieProgress,
              minHeight: 14,
              backgroundColor: ClayColors.calorie.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverTarget ? ClayColors.error : ClayColors.calorie,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Protein',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '${protein.toStringAsFixed(1)} / $targetProtein g',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ClayColors.protein,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: proteinProgress,
              minHeight: 8,
              backgroundColor: ClayColors.protein.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(ClayColors.protein),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildMacrosCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: ClayDecoration.card(isDark: isDark),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroCircle(label: 'Carbs', value: _dailyStats['carbs'], color: ClayColors.carbs),
          Container(width: 1, height: 56, color: ClayColors.shadowDark.withValues(alpha: 0.25)),
          _buildMacroCircle(label: 'Protein', value: _dailyStats['protein'], color: ClayColors.protein),
          Container(width: 1, height: 56, color: ClayColors.shadowDark.withValues(alpha: 0.25)),
          _buildMacroCircle(label: 'Fat', value: _dailyStats['fat'], color: ClayColors.fat),
        ],
      ),
    );
  }

  Widget _buildMacroCircle({
    required String label,
    required num value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          'g',
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.65),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildRecentMealsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: ClayDecoration.card(isDark: isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Meals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MealHistoryScreen(),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Show actual food logs
            if (_recentMeals.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No meals logged today',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start logging to track your nutrition!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_recentMeals.length, (index) {
                final meal = _recentMeals[index];
                final mealId = meal['id'] as String?;
                final widgets = <Widget>[];

                widgets.add(
                  Dismissible(
                    key: Key(mealId ?? index.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: ClayColors.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(height: 4),
                          Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, meal['food_name']),
                    onDismissed: (_) => _deleteMeal(mealId, meal),
                    child: GestureDetector(
                      onTap: () => _editMeal(index),
                      child: _buildMealCard(meal),
                    ),
                  ),
                );
                widgets.add(const SizedBox(height: 8));

                return widgets;
              }).expand((element) => element),
          ],
        ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      // Parse UTC timestamp and convert to HKT (UTC+8)
      final dateTime = DateTime.parse(isoString).toUtc().add(const Duration(hours: 8));
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
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

  Future<bool?> _confirmDelete(BuildContext ctx, String? foodName) {
    return showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${foodName ?? 'this meal'}" from your log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeal(String? mealId, Map<String, dynamic> meal) async {
    if (mealId == null) return;
    try {
      await SupabaseService.client
          .from('food_logs')
          .delete()
          .eq('id', mealId);

      // Remove from local list and recalculate stats
      setState(() {
        _recentMeals.removeWhere((m) => m['id'] == mealId);
        final calories = (meal['calories'] as int?) ?? 0;
        final protein = (meal['protein'] as num?)?.toDouble() ?? 0.0;
        final carbs = (meal['carbs'] as num?)?.toDouble() ?? 0.0;
        final fat = (meal['fat'] as num?)?.toDouble() ?? 0.0;
        _dailyStats = {
          ..._dailyStats,
          'calories': ((_dailyStats['calories'] as int) - calories).clamp(0, 99999),
          'protein': ((_dailyStats['protein'] as double) - protein).clamp(0.0, 9999.0),
          'carbs': ((_dailyStats['carbs'] as double) - carbs).clamp(0.0, 9999.0),
          'fat': ((_dailyStats['fat'] as double) - fat).clamp(0.0, 9999.0),
          'mealsLogged': _recentMeals.length,
        };
      });

      if (mounted) {
        _showBottomSnackBar(
          'Meal deleted',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        _showBottomSnackBar(
          'Failed to delete: $e',
          backgroundColor: Colors.red,
        );
      }
      // Reload original state if deletion fails
      _loadDashboardData();
    }
  }

  Future<void> _editMeal(int index) async {
    final meal = _recentMeals[index];
    final mealId = meal['id'] as String?;
    if (mealId == null) return;

    final result = await _showEditNutritionDialog(
      context,
      foodName: meal['food_name'] as String? ?? '',
      calories: (meal['calories'] as int?) ?? 0,
      protein: (meal['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (meal['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (meal['fat'] as num?)?.toDouble() ?? 0.0,
    );
    if (result == null) return;

    try {
      await SupabaseService.client.from('food_logs').update({
        'food_name': result['food_name'],
        'calories': result['calories'],
        'protein': result['protein'],
        'carbs': result['carbs'],
        'fat': result['fat'],
      }).eq('id', mealId);

      _loadDashboardData();

      if (mounted) {
        _showBottomSnackBar(
          'Meal updated',
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _showBottomSnackBar(
          'Failed to update: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  /// Shows a dialog to edit food name and nutrition values.
  /// Returns a Map with the edited values, or null if cancelled.
  static Future<Map<String, dynamic>?> _showEditNutritionDialog(
    BuildContext context, {
    required String foodName,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    final nameCtrl = TextEditingController(text: foodName);
    final calCtrl = TextEditingController(text: calories.toString());
    final proteinCtrl = TextEditingController(text: protein.toStringAsFixed(1));
    final carbsCtrl = TextEditingController(text: carbs.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: fat.toStringAsFixed(1));

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Nutrition'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Food Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: calCtrl,
                decoration: const InputDecoration(labelText: 'Calories (kcal)', suffixText: 'kcal'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: proteinCtrl,
                decoration: const InputDecoration(labelText: 'Protein (g)', suffixText: 'g'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: carbsCtrl,
                decoration: const InputDecoration(labelText: 'Carbs (g)', suffixText: 'g'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fatCtrl,
                decoration: const InputDecoration(labelText: 'Fat (g)', suffixText: 'g'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'food_name': nameCtrl.text.trim().isEmpty ? foodName : nameCtrl.text.trim(),
                'calories': int.tryParse(calCtrl.text) ?? calories,
                'protein': double.tryParse(proteinCtrl.text) ?? protein,
                'carbs': double.tryParse(carbsCtrl.text) ?? carbs,
                'fat': double.tryParse(fatCtrl.text) ?? fat,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ClayDecoration.flat(isDark: isDark, radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image thumbnail
          MealThumbnail(
            localImagePath: localImagePath,
            mealType: mealType,
            size: 72,
          ),
          const SizedBox(width: 12),
          // Right side content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food name + time
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
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined, size: 14, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 4),
                // Meal type chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: ClayDecoration.badge(color: _mealTypeColor(mealType)),
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
                // Calories + macros
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _buildNutrientBadge('$calories', 'kcal', ClayColors.calorie),
                    _buildNutrientBadge('${protein.toStringAsFixed(1)}g', 'P', ClayColors.protein),
                    _buildNutrientBadge('${carbs.toStringAsFixed(1)}g', 'C', ClayColors.carbs),
                    _buildNutrientBadge('${fat.toStringAsFixed(1)}g', 'F', ClayColors.fat),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ClayDecoration.badge(color: color),
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

  Color _mealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return Colors.amber;
      case 'lunch': return Colors.green;
      case 'dinner': return Colors.indigo;
      case 'snack': return Colors.orange;
      default: return Colors.teal;
    }
  }
}
