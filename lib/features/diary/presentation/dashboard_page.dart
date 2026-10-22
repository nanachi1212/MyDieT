import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/nutrition_facts.dart';
import '../../../core/providers.dart';
import '../data/diary_repository.dart';
import '../domain/diary_enums.dart';
import 'add_food_page.dart';
import 'portion_editor_sheet.dart';

/// 新增食物頁的路徑，帶上餐別與日期。
String addFoodPath(DateTime date, [MealType? meal]) =>
    '/diary/add?date=${date.toIso8601String().substring(0, 10)}'
    '${meal == null ? '' : '&meal=${meal.name}'}';

/// 每日總覽：目標／已攝取／剩餘、四個餐別、七項營養素累計與 Macro %。
/// 預設今天，可切換到前一天／後一天或任選日期。
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  static const _weekdays = '一二三四五六日';

  void _shift(int days) =>
      setState(() => _date = DateUtils.addDaysToDate(_date, days));

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());
    final entries = ref.watch(dayEntriesProvider(_date));
    final target = ref.watch(dayTargetProvider(_date)).value?.calorieTarget;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          key: const Key('dashboard_date'),
          isToday
              ? '今日'
              : '${_date.month}/${_date.day}（${_weekdays[_date.weekday - 1]}）',
        ),
        actions: [
          IconButton(
            tooltip: '前一天',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shift(-1),
          ),
          IconButton(
            tooltip: '選日期',
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
          IconButton(
            tooltip: '後一天',
            icon: const Icon(Icons.chevron_right),
            // 不記未來的日子
            onPressed: isToday ? null : () => _shift(1),
          ),
        ],
      ),
      body: switch (entries) {
        AsyncData(:final value) => _DayView(
          date: _date,
          entries: value,
          target: target,
        ),
        AsyncError(:final error) => Center(child: Text('讀取資料失敗：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(addFoodPath(_date)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.date,
    required this.entries,
    required this.target,
  });

  final DateTime date;
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
            date: date,
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
  const _MealCard({
    required this.date,
    required this.meal,
    required this.entries,
  });

  final DateTime date;
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
              onPressed: () => context.push(addFoodPath(date, meal)),
            ),
          ),
          for (final e in entries)
            ListTile(
              dense: true,
              title: Text(e.displayName),
              subtitle: Text('${e.grams.round()} 公克'),
              trailing: Text('${e.calories.round()} 大卡'),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => PortionEditorSheet.edit(entry: e),
              ),
            ),
        ],
      ),
    );
  }
}
