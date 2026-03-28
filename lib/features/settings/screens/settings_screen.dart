library;

import 'package:flutter/material.dart';
import 'package:smart_diet_ai/features/benchmark/screens/benchmark_list_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Benchmark Test'),
            subtitle: const Text('Compare estimation methods A / B / C'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BenchmarkListScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
