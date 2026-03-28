library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_diet_ai/features/benchmark/benchmark_models.dart';

class BenchmarkChartsScreen extends StatelessWidget {
  final List<BenchmarkItem> items;
  const BenchmarkChartsScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Benchmark Charts'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Dimensions'),
            Tab(text: 'Nutrition'),
            Tab(text: 'Summary'),
          ]),
        ),
        body: TabBarView(children: [
          _DimensionTab(items: items),
          _NutritionTab(items: items),
          _SummaryTab(items: items),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Tab 1 – Dimension accuracy (width, length, height)
// ═══════════════════════════════════════════════════════════

class _DimensionTab extends StatelessWidget {
  final List<BenchmarkItem> items;
  const _DimensionTab({required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Width (cm)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _GroupedBarChart(items: items, extractor: _widthExtractor)),
          const SizedBox(height: 24),
          Text('Length (cm)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _GroupedBarChart(items: items, extractor: _lengthExtractor)),
          const SizedBox(height: 24),
          Text('Height (cm)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _GroupedBarChart(items: items, extractor: _heightExtractor)),
          const SizedBox(height: 24),
          _MaeTable(items: items, metrics: _dimensionMetrics),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Tab 2 – Nutrition accuracy (cal, protein, carbs, fat)
// ═══════════════════════════════════════════════════════════

class _NutritionTab extends StatelessWidget {
  final List<BenchmarkItem> items;
  const _NutritionTab({required this.items});

  @override
  Widget build(BuildContext context) {
    final foodItems = items.where((i) => i.isFood).toList();
    if (foodItems.isEmpty) {
      return const Center(child: Text('No food items to compare nutrition.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Calories', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _GroupedBarChart(items: foodItems, extractor: _calExtractor)),
          const SizedBox(height: 24),
          Text('Protein (g)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _GroupedBarChart(items: foodItems, extractor: _proteinExtractor)),
          const SizedBox(height: 24),
          Text('Carbs (g)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _GroupedBarChart(items: foodItems, extractor: _carbsExtractor)),
          const SizedBox(height: 24),
          Text('Fat (g)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _GroupedBarChart(items: foodItems, extractor: _fatExtractor)),
          const SizedBox(height: 24),
          _MaeTable(items: foodItems, metrics: _nutritionMetrics),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Tab 3 – Overall summary
// ═══════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  final List<BenchmarkItem> items;
  const _SummaryTab({required this.items});

  @override
  Widget build(BuildContext context) {
    final foodItems = items.where((i) => i.isFood).toList();
    final hasFood = foodItems.isNotEmpty;

    // Use all metrics for food items, only dimensions for objects
    final dimMetrics = _dimensionMetrics;
    final nutMetrics = hasFood ? _nutritionMetrics : <_MetricDef>[];
    final allMetrics = [...dimMetrics, ...nutMetrics];

    // Determine best method per metric
    final methodWins = {'A': 0, 'B': 0, 'C': 0};
    for (final m in dimMetrics) {
      final maeA = _mae(items, m.gt, m.a);
      final maeB = _mae(items, m.gt, m.b);
      final maeC = _mae(items, m.gt, m.c);
      if (maeA == null && maeB == null && maeC == null) continue;
      final vals = {
        'A': maeA ?? double.infinity,
        'B': maeB ?? double.infinity,
        'C': maeC ?? double.infinity,
      };
      final best = vals.entries.reduce((a, b) => a.value < b.value ? a : b).key;
      methodWins[best] = methodWins[best]! + 1;
    }
    for (final m in nutMetrics) {
      final maeA = _mae(foodItems, m.gt, m.a);
      final maeB = _mae(foodItems, m.gt, m.b);
      final maeC = _mae(foodItems, m.gt, m.c);
      if (maeA == null && maeB == null && maeC == null) continue;
      final vals = {
        'A': maeA ?? double.infinity,
        'B': maeB ?? double.infinity,
        'C': maeC ?? double.infinity,
      };
      final best = vals.entries.reduce((a, b) => a.value < b.value ? a : b).key;
      methodWins[best] = methodWins[best]! + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Overall: ${items.length} items (${foodItems.length} food, ${items.length - foodItems.length} objects)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _SummaryCard(label: 'A – Pure Gemini + RAG', wins: methodWins['A']!, total: allMetrics.length, color: Colors.blue),
          _SummaryCard(label: 'B – Gemini + EXIF + RAG', wins: methodWins['B']!, total: allMetrics.length, color: Colors.orange),
          _SummaryCard(label: 'C – ARCore + Gemini + RAG', wins: methodWins['C']!, total: allMetrics.length, color: Colors.green),
          const SizedBox(height: 24),
          Text('Dimension MAE (all items)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _MaeTable(items: items, metrics: dimMetrics),
          if (hasFood) ...[
            const SizedBox(height: 24),
            Text('Nutrition MAE (food only)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _MaeTable(items: foodItems, metrics: nutMetrics),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int wins;
  final int total;
  final Color color;
  const _SummaryCard({required this.label, required this.wins, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: Text('$wins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        title: Text(label),
        subtitle: Text('Best in $wins / $total metrics'),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Shared: grouped bar chart widget
// ═══════════════════════════════════════════════════════════

typedef _Extractor = ({double? gt, double? a, double? b, double? c}) Function(BenchmarkItem);

class _GroupedBarChart extends StatelessWidget {
  final List<BenchmarkItem> items;
  final _Extractor extractor;
  const _GroupedBarChart({required this.items, required this.extractor});

  @override
  Widget build(BuildContext context) {
    final barGroups = <BarChartGroupData>[];
    double maxVal = 10;

    for (int i = 0; i < items.length; i++) {
      final vals = extractor(items[i]);
      final rods = <BarChartRodData>[
        _rod(vals.gt, Colors.grey),
        _rod(vals.a, Colors.blue),
        _rod(vals.b, Colors.orange),
        _rod(vals.c, Colors.green),
      ];
      for (final r in rods) {
        if (r.toY > maxVal) maxVal = r.toY;
      }
      barGroups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 2));
    }

    return BarChart(
      BarChartData(
        maxY: maxVal * 1.15,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                final name = items[idx].foodName;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    name.length > 6 ? '${name.substring(0, 6)}…' : name,
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) {
              final labels = ['GT', 'A', 'B', 'C'];
              return BarTooltipItem(
                '${labels[ri]}: ${rod.toY.toStringAsFixed(1)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
      ),
    );
  }

  BarChartRodData _rod(double? val, Color color) {
    return BarChartRodData(
      toY: val ?? 0,
      color: val == null ? color.withAlpha(40) : color,
      width: 10,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Shared: MAE / MAPE table
// ═══════════════════════════════════════════════════════════

class _MetricDef {
  final String label;
  final double? Function(BenchmarkItem) gt;
  final double? Function(BenchmarkItem) a;
  final double? Function(BenchmarkItem) b;
  final double? Function(BenchmarkItem) c;
  const _MetricDef(this.label, this.gt, this.a, this.b, this.c);
}

double? _mae(List<BenchmarkItem> items, double? Function(BenchmarkItem) gt,
    double? Function(BenchmarkItem) est) {
  double sum = 0;
  int n = 0;
  for (final item in items) {
    final g = gt(item);
    final e = est(item);
    if (g != null && e != null) {
      sum += (g - e).abs();
      n++;
    }
  }
  return n == 0 ? null : sum / n;
}

double? _mape(List<BenchmarkItem> items, double? Function(BenchmarkItem) gt,
    double? Function(BenchmarkItem) est) {
  double sum = 0;
  int n = 0;
  for (final item in items) {
    final g = gt(item);
    final e = est(item);
    if (g != null && e != null && g != 0) {
      sum += ((g - e).abs() / g.abs());
      n++;
    }
  }
  return n == 0 ? null : (sum / n) * 100;
}

class _MaeTable extends StatelessWidget {
  final List<BenchmarkItem> items;
  final List<_MetricDef> metrics;
  const _MaeTable({required this.items, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[100]),
          children: const [
            _H('Metric'),
            _H('MAE A'),
            _H('MAE B'),
            _H('MAE C'),
            _H('MAPE A'),
            _H('MAPE B'),
            _H('MAPE C'),
          ],
        ),
        for (final m in metrics)
          TableRow(children: [
            _C(m.label),
            _C(_fmtMae(_mae(items, m.gt, m.a))),
            _C(_fmtMae(_mae(items, m.gt, m.b))),
            _C(_fmtMae(_mae(items, m.gt, m.c))),
            _C(_fmtPct(_mape(items, m.gt, m.a))),
            _C(_fmtPct(_mape(items, m.gt, m.b))),
            _C(_fmtPct(_mape(items, m.gt, m.c))),
          ]),
      ],
    );
  }

  String _fmtMae(double? v) => v == null ? '--' : v.toStringAsFixed(1);
  String _fmtPct(double? v) => v == null ? '--' : '${v.toStringAsFixed(0)}%';
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(6), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center));
}

class _C extends StatelessWidget {
  final String text;
  const _C(this.text);
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(6), child: Text(text, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center));
}

// ═══════════════════════════════════════════════════════════
// Extractors for chart & MAE table
// ═══════════════════════════════════════════════════════════

({double? gt, double? a, double? b, double? c}) _widthExtractor(BenchmarkItem i) =>
    (gt: i.groundTruth?.widthCm, a: i.methodA?.widthCm, b: i.methodB?.widthCm, c: i.methodC?.widthCm);

({double? gt, double? a, double? b, double? c}) _lengthExtractor(BenchmarkItem i) =>
    (gt: i.groundTruth?.lengthCm, a: i.methodA?.lengthCm, b: i.methodB?.lengthCm, c: i.methodC?.lengthCm);

({double? gt, double? a, double? b, double? c}) _heightExtractor(BenchmarkItem i) =>
    (gt: i.groundTruth?.heightCm, a: i.methodA?.heightCm, b: i.methodB?.heightCm, c: i.methodC?.heightCm);

({double? gt, double? a, double? b, double? c}) _calExtractor(BenchmarkItem i) =>
    (gt: i.groundTruth?.calories?.toDouble(), a: i.methodA?.calories.toDouble(), b: i.methodB?.calories.toDouble(), c: i.methodC?.calories.toDouble());

({double? gt, double? a, double? b, double? c}) _proteinExtractor(BenchmarkItem i) =>
    (gt: i.groundTruth?.protein?.toDouble(), a: i.methodA?.protein.toDouble(), b: i.methodB?.protein.toDouble(), c: i.methodC?.protein.toDouble());

({double? gt, double? a, double? b, double? c}) _carbsExtractor(BenchmarkItem i) =>
    (gt: i.groundTruth?.carbs?.toDouble(), a: i.methodA?.carbs.toDouble(), b: i.methodB?.carbs.toDouble(), c: i.methodC?.carbs.toDouble());

({double? gt, double? a, double? b, double? c}) _fatExtractor(BenchmarkItem i) =>
    (gt: i.groundTruth?.fat?.toDouble(), a: i.methodA?.fat.toDouble(), b: i.methodB?.fat.toDouble(), c: i.methodC?.fat.toDouble());

final _dimensionMetrics = <_MetricDef>[
  _MetricDef('Width', (i) => i.groundTruth?.widthCm, (i) => i.methodA?.widthCm, (i) => i.methodB?.widthCm, (i) => i.methodC?.widthCm),
  _MetricDef('Length', (i) => i.groundTruth?.lengthCm, (i) => i.methodA?.lengthCm, (i) => i.methodB?.lengthCm, (i) => i.methodC?.lengthCm),
  _MetricDef('Height', (i) => i.groundTruth?.heightCm, (i) => i.methodA?.heightCm, (i) => i.methodB?.heightCm, (i) => i.methodC?.heightCm),
];

final _nutritionMetrics = <_MetricDef>[
  _MetricDef('Calories', (i) => i.groundTruth?.calories?.toDouble(), (i) => i.methodA?.calories.toDouble(), (i) => i.methodB?.calories.toDouble(), (i) => i.methodC?.calories.toDouble()),
  _MetricDef('Protein', (i) => i.groundTruth?.protein?.toDouble(), (i) => i.methodA?.protein.toDouble(), (i) => i.methodB?.protein.toDouble(), (i) => i.methodC?.protein.toDouble()),
  _MetricDef('Carbs', (i) => i.groundTruth?.carbs?.toDouble(), (i) => i.methodA?.carbs.toDouble(), (i) => i.methodB?.carbs.toDouble(), (i) => i.methodC?.carbs.toDouble()),
  _MetricDef('Fat', (i) => i.groundTruth?.fat?.toDouble(), (i) => i.methodA?.fat.toDouble(), (i) => i.methodB?.fat.toDouble(), (i) => i.methodC?.fat.toDouble()),
];
