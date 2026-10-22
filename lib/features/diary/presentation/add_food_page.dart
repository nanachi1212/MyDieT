import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../foods/data/food_repository.dart';
import '../domain/diary_enums.dart';
import 'custom_food_page.dart';
import 'portion_editor_sheet.dart';

String mealTypeLabel(MealType m) => switch (m) {
  MealType.breakfast => '早餐',
  MealType.lunch => '午餐',
  MealType.dinner => '晚餐',
  MealType.snack => '點心',
};

/// 手動新增食物：選餐別 → 搜尋 → 選食物 → 輸入份量 → 加入。
class AddFoodPage extends ConsumerStatefulWidget {
  const AddFoodPage({super.key, this.initialMeal, this.date});

  final MealType? initialMeal;
  final DateTime? date;

  @override
  ConsumerState<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends ConsumerState<AddFoodPage> {
  final _search = TextEditingController();
  late MealType _meal;
  late final DateTime _date;

  List<FoodItem> _results = const [];
  bool _loading = true;
  bool _showingRecent = true;

  @override
  void initState() {
    super.initState();
    _meal = widget.initialMeal ?? _guessMeal(DateTime.now().hour);
    _date = widget.date ?? DateTime.now();
    _loadRecent();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static MealType _guessMeal(int hour) {
    if (hour < 10) return MealType.breakfast;
    if (hour < 15) return MealType.lunch;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  Future<void> _loadRecent() async {
    final items = await ref.read(foodRepositoryProvider).recentlyUsed();
    if (!mounted) return;
    setState(() {
      _results = items;
      _showingRecent = true;
      _loading = false;
    });
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      await _loadRecent();
      return;
    }
    setState(() => _loading = true);
    final items = await ref.read(foodRepositoryProvider).search(query);
    if (!mounted) return;
    setState(() {
      _results = items;
      _showingRecent = false;
      _loading = false;
    });
  }

  Future<void> _openPortionEditor(FoodItem food) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PortionEditorSheet.add(food: food, mealType: _meal, date: _date),
    );

    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加入${mealTypeLabel(_meal)}：${food.name}')),
      );
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _createCustomFood() async {
    final food = await Navigator.of(
      context,
    ).push<FoodItem>(MaterialPageRoute(builder: (_) => const CustomFoodPage()));
    if (food != null && mounted) await _openPortionEditor(food);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增食物')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<MealType>(
              key: const Key('meal_selector'),
              segments: [
                for (final m in MealType.values)
                  ButtonSegment(value: m, label: Text(mealTypeLabel(m))),
              ],
              selected: {_meal},
              onSelectionChanged: (v) => setState(() => _meal = v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('food_search_field'),
              controller: _search,
              decoration: const InputDecoration(
                hintText: '搜尋食物，例如：白飯、雞腿',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _runSearch,
            ),
          ),
          if (_showingRecent && _results.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('最近使用'),
              ),
            ),
          Expanded(child: _buildResults()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('create_custom_food_button'),
                  icon: const Icon(Icons.add),
                  label: const Text('找不到？建立自訂食物'),
                  onPressed: _createCustomFood,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _showingRecent ? '還沒有記錄過任何食物，先搜尋看看' : '找不到符合的食物',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final f = _results[i];
        return ListTile(
          key: Key('food_item_${f.id}'),
          title: Row(
            children: [
              Flexible(child: Text(f.name)),
              if (f.isEstimated) ...[
                const SizedBox(width: 6),
                const _EstimatedChip(),
              ],
            ],
          ),
          subtitle: Text('${f.calories.round()} 大卡 / 100 公克'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPortionEditor(f),
        );
      },
    );
  }
}

class _EstimatedChip extends StatelessWidget {
  const _EstimatedChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      '估算',
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    ),
  );
}
