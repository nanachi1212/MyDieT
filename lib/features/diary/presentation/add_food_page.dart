import 'package:flutter/material.dart';

/// P0 佔位頁。食物搜尋與份量輸入屬於 P1。
class AddFoodPage extends StatelessWidget {
  const AddFoodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增食物')),
      body: const Center(child: Text('Add Food placeholder')),
    );
  }
}
