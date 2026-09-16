import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// P0 佔位頁。真實 Dashboard 屬於 P1。
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日')),
      body: const Center(child: Text('Dashboard placeholder')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/diary/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
