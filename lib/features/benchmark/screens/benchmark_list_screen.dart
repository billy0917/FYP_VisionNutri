library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_diet_ai/features/benchmark/benchmark_models.dart';
import 'package:smart_diet_ai/features/benchmark/benchmark_service.dart';
import 'package:smart_diet_ai/features/benchmark/screens/benchmark_detail_screen.dart';
import 'package:smart_diet_ai/features/benchmark/screens/benchmark_charts_screen.dart';

class BenchmarkListScreen extends StatefulWidget {
  const BenchmarkListScreen({super.key});

  @override
  State<BenchmarkListScreen> createState() => _BenchmarkListScreenState();
}

class _BenchmarkListScreenState extends State<BenchmarkListScreen> {
  final _service = BenchmarkService();
  List<BenchmarkItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.loadAll();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _createNew() async {
    final item = BenchmarkItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
    );
    await _service.save(item);
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BenchmarkDetailScreen(item: item)),
    );
    if (changed == true || true) _load(); // always reload
  }

  Future<void> _openItem(BenchmarkItem item) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BenchmarkDetailScreen(item: item)),
    );
    _load();
  }

  Future<void> _deleteItem(BenchmarkItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "${item.foodName.isEmpty ? 'Untitled' : item.foodName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _service.delete(item.id);
      _load();
    }
  }

  Future<void> _exportCsv() async {
    final csv = _service.exportCsv(_items);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/benchmark_results.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'SmartDiet AI Benchmark Results',
    );
  }

  @override
  Widget build(BuildContext context) {
    final completeCount = _items.where((e) => e.status == BenchmarkStatus.complete).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Benchmark Test'),
        actions: [
          if (_items.length >= 2)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Charts',
              onPressed: () {
                final completed = _items.where((e) => e.status == BenchmarkStatus.complete).toList();
                if (completed.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Need at least 2 completed items for charts')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BenchmarkChartsScreen(items: completed)),
                );
              },
            ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No benchmark items yet', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('Tap + to add your first food item'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${_items.length} items · $completeCount complete',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _buildTile(_items[i]),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNew,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTile(BenchmarkItem item) {
    final isComplete = item.status == BenchmarkStatus.complete;
    final subtitle = [
      item.isFood ? '🍽️ Food' : '📦 Object',
      if (item.arMeasurement != null) 'AR ✓',
      if (item.groundTruth != null) 'GT ✓',
      if (item.methodA != null) 'A ✓',
      if (item.methodB != null) 'B ✓',
      if (item.methodC != null) 'C ✓',
    ].join(' · ');

    return ListTile(
      leading: item.imagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(item.imagePath!),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image, size: 48),
              ),
            )
          : const Icon(Icons.photo_outlined, size: 48),
      title: Text(
        item.foodName.isEmpty ? 'Untitled' : item.foodName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle.isEmpty ? 'Draft' : subtitle),
      trailing: Icon(
        isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isComplete ? Colors.green : Colors.grey,
      ),
      onTap: () => _openItem(item),
      onLongPress: () => _deleteItem(item),
    );
  }
}
