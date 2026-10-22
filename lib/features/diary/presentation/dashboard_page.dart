import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/nutrition_facts.dart';
import '../../../core/providers.dart';
import '../data/diary_repository.dart';
import '../domain/diary_enums.dart';
import 'add_food_page.dart';

/// 今日：目標／已攝取／剩餘、四個餐別、七項營養素累計與 Macro %。
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateUtils.dateOnly(DateTime.now());
    final entries = ref.watch(dayEntriesProvider(today));
    final target = ref.watch(dayTargetProvider(today)).value?.calorieTarget;

    return Scaffold(
      appBar: AppBar(title: const Text('今日')),
      body: switch (entries) {
        AsyncData(:final value) => _DayView(entries: value, target: target),
        AsyncError(:final error) => Center(child: Text('讀取資料失敗：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/diary/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.entries, required this.target});

  final List<FoodEntry> entries;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(NutritionFacts.zero, (a, e) => a + e.facts);

    return ListView(
      // 底部留空間給 FAB，避免擋住最後一餐的按鈕
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _CalorieCard(eaten: total.calories.round(), target: target),
        const SizedBox(height: 12),
        _NutrientCard(total: total),
        for (final meal in MealType.values)
          _MealCard(
            meal: meal,
            entries: [
              for (final e in entries)
                if (e.mealType == meal) e,
            ],
          ),
      ],
    );
  }
}

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({required this.eaten, required this.target});

  final int eaten;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final t = target;
    final left = t == null ? null : t - eaten;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _stat(context, '目標', t?.toString() ?? '—'),
                _stat(context, '已攝取', '$eaten'),
                _stat(
                  context,
                  left != null && left < 0 ? '超過' : '剩餘',
                  left?.abs().toString() ?? '—',
                  key: const Key('remaining_calories'),
                  color: left != null && left < 0
                      ? theme.colorScheme.error
                      : null,
                ),
              ],
            ),
            if (t != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (eaten / t).clamp(0, 1).toDouble(),
                color: eaten > t ? theme.colorScheme.error : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value, {
    Key? key,
    Color? color,
  }) => Expanded(
    child: Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          key: key,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: color),
        ),
        Text('大卡', style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _NutrientCard extends StatelessWidget {
  const _NutrientCard({required this.total});

  final NutritionFacts total;

  @override
  Widget build(BuildContext context) {
    final m = total.macroPercent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('蛋白質', total.protein, 'g', m.protein),
            _row('碳水化合物', total.carbs, 'g', m.carbs),
            _row('脂肪', total.fat, 'g', m.fat),
            const Divider(),
            _row('糖', total.sugar, 'g'),
            _row('膳食纖維', total.fiber, 'g'),
            _row('鈉', total.sodium, 'mg'),
          ],
        ),
      ),
    );
  }

  /// null 代表資料不明，顯示「—」而不是 0。
  Widget _row(String label, double? value, String unit, [double? percent]) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              key: Key('nutrient_$label'),
              value == null ? '—' : '${value.toStringAsFixed(1)} $unit',
            ),
            if (percent != null)
              SizedBox(
                width: 56,
                child: Text('${percent.round()}%', textAlign: TextAlign.end),
              ),
          ],
        ),
      );
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.entries});

  final MealType meal;
  final List<FoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final kcal = entries.fold(0.0, (a, e) => a + e.calories).round();

    return Card(
      key: Key('meal_${meal.name}'),
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(
              mealTypeLabel(meal),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text('$kcal 大卡'),
            trailing: IconButton(
              tooltip: '新增${mealTypeLabel(meal)}',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => context.push('/diary/add?meal=${meal.name}'),
            ),
          ),
          for (final e in entries)
            ListTile(
              dense: true,
              title: Text(e.displayName),
              subtitle: Text('${e.grams.round()} 公克'),
              trailing: Text('${e.calories.round()} 大卡'),
            ),
        ],
      ),
    );
  }
}
