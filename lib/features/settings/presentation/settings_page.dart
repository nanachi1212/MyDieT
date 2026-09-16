import 'package:flutter/material.dart';

/// P0 佔位頁。AI 設定與 Health 設定屬於 P2 / P3。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: const Center(child: Text('Settings placeholder')),
    );
  }
}
