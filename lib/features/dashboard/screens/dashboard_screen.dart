/// SmartDiet AI - Dashboard Screen
/// 
/// Main home screen showing daily stats, gamification, and quick actions.
library;

import 'package:flutter/material.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/features/auth/screens/login_screen.dart';
import 'package:smart_diet_ai/features/camera/screens/camera_screen.dart';
import 'package:smart_diet_ai/features/chat/screens/chat_screen.dart';
import 'package:smart_diet_ai/features/food_entry/screens/manual_food_entry_screen.dart';
import 'package:smart_diet_ai/features/dashboard/widgets/meal_thumbnail.dart';
import 'package:smart_diet_ai/features/dashboard/screens/meal_history_screen.dart';

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
  
  Map<String, dynamic> _gamificationStats = {
    'currentStreak': 0,
    'totalPoints': 0,
    'level': 1,
  };

  List<Map<String, dynamic>> _recentMeals = [];
  bool _isLoading = true;

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
              // TODO: Navigate to profile
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // 每次切換回 Dashboard 都重新載入數據
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
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 手動輸入按鈕
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
                      // 重新載入數據
                      _loadDashboardData();
                    }
                  },
                  child: const Icon(Icons.edit),
                ),
                const SizedBox(height: 12),
                // 拍照按鈕
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

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUser!.id;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // 載入今天的食物記錄
      final foodLogsResponse = await SupabaseService.client
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', startOfDay.toIso8601String())
          .order('logged_at', ascending: false);

      _recentMeals = List<Map<String, dynamic>>.from(foodLogsResponse);

      // 計算今日營養總和
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

      // 載入遊戲化數據
      final gamificationResponse = await SupabaseService.client
          .from('gamification_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

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

        if (gamificationResponse != null) {
          _gamificationStats = {
            'currentStreak': gamificationResponse['current_streak'] ?? 0,
            'totalPoints': gamificationResponse['total_points'] ?? 0,
            'level': gamificationResponse['level'] ?? 1,
          };
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gamification card
            _buildGamificationCard(),
            const SizedBox(height: 16),
            // Daily progress card
            _buildDailyProgressCard(),
            const SizedBox(height: 16),
            // Macros breakdown
            _buildMacrosCard(),
            const SizedBox(height: 16),
            // Recent meals
            _buildRecentMealsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildGamificationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Level ${_gamificationStats['level']}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  value: '${_gamificationStats['currentStreak']}',
                  label: 'Day Streak',
                ),
                _buildStatItem(
                  icon: Icons.stars,
                  iconColor: Colors.amber,
                  value: '${_gamificationStats['totalPoints']}',
                  label: 'Points',
                ),
                _buildStatItem(
                  icon: Icons.restaurant,
                  iconColor: Colors.green,
                  value: '${_dailyStats['mealsLogged']}',
                  label: 'Meals Today',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildDailyProgressCard() {
    final calorieProgress = _dailyStats['calories'] / _dailyStats['targetCalories'];
    final proteinProgress = _dailyStats['protein'] / _dailyStats['targetProtein'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Goals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(
              label: 'Calories',
              current: _dailyStats['calories'],
              target: _dailyStats['targetCalories'],
              progress: calorieProgress,
              color: Colors.orange,
              unit: 'kcal',
            ),
            const SizedBox(height: 12),
            _buildProgressBar(
              label: 'Protein',
              current: _dailyStats['protein'],
              target: _dailyStats['targetProtein'],
              progress: proteinProgress,
              color: Colors.blue,
              unit: 'g',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required num current,
    required int target,
    required double progress,
    required Color color,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${current.toStringAsFixed(current is double ? 1 : 0)} / $target $unit',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Macros Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroCircle(
                  label: 'Protein',
                  value: _dailyStats['protein'],
                  color: Colors.blue,
                ),
                _buildMacroCircle(
                  label: 'Carbs',
                  value: _dailyStats['carbs'],
                  color: Colors.green,
                ),
                _buildMacroCircle(
                  label: 'Fat',
                  value: _dailyStats['fat'],
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCircle({
    required String label,
    required num value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              '${value.toStringAsFixed(1)}g',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildRecentMealsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            // 顯示真實的食物記錄
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
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
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
                    child: _buildMealCard(meal),
                  ),
                );
                widgets.add(const SizedBox(height: 8));

                return widgets;
              }).expand((element) => element),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
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

      // 從本地列表移除並重算統計
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
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
      // 刪除失敗則重新載入回原狀態
      _loadDashboardData();
    }
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
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 圖片縮圖
          MealThumbnail(
            localImagePath: localImagePath,
            mealType: mealType,
            size: 72,
          ),
          const SizedBox(width: 12),
          // 右側內容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 食物名稱 + 時間
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
                // 餐點類型 chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _mealTypeColor(mealType).withValues(alpha: 0.12),
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
                // 卡路里 + 三大營養素
                Row(
                  children: [
                    _buildNutrientBadge('$calories', 'kcal', Colors.orange),
                    const SizedBox(width: 6),
                    _buildNutrientBadge('${protein.toStringAsFixed(1)}g', 'P', Colors.blue),
                    const SizedBox(width: 6),
                    _buildNutrientBadge('${carbs.toStringAsFixed(1)}g', 'C', Colors.green),
                    const SizedBox(width: 6),
                    _buildNutrientBadge('${fat.toStringAsFixed(1)}g', 'F', Colors.red),
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
