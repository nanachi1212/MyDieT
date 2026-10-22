import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/nutrition_calculator.dart';
import '../../../core/nutrition/nutrition_facts.dart';
import '../../../core/nutrition/serving_unit.dart';
import '../../../core/providers.dart';
import '../../foods/data/food_repository.dart';
import '../data/diary_repository.dart';
import '../domain/diary_enums.dart';

/// 輸入份量並即時看到營養，確認後寫入 FoodEntry。
class PortionEditorSheet extends ConsumerStatefulWidget {
  /// 從食物字典新增一筆。
  PortionEditorSheet.add({
    super.key,
    required FoodItem food,
    required this.mealType,
    required this.date,
  }) : name = food.name,
       per100g = food.per100g,
       servingGrams = food.defaultServingGrams,
       servingLabel = food.defaultServingLabel,
       source = food.isEstimated
           ? NutritionSource.databaseEstimated
           : NutritionSource.database,
       foodItemId = food.id,
       entry = null;

  /// 修改既有紀錄的份量，或刪除它。
  ///
  /// 營養由這筆紀錄自己的快照換算，不回頭讀食物字典 —— 字典之後被修正過，
  /// 也不會改到這筆紀錄的數值。
  PortionEditorSheet.edit({super.key, required FoodEntry this.entry})
    : name = entry.displayName,
      // grams 為 0 的舊紀錄無法反推營養，只能刪除
      per100g = entry.grams > 0
          ? entry.facts.scale(100 / entry.grams)
          : NutritionFacts.zero,
      servingGrams = entry.unit == ServingUnit.serving && entry.quantity > 0
          ? entry.grams / entry.quantity
          : null,
      servingLabel = null,
      source = entry.nutritionSource,
      foodItemId = entry.foodItemId,
      mealType = entry.mealType,
      date = entry.date;

  final String name;
  final NutritionFacts per100g;
  final double? servingGrams;
  final String? servingLabel;

  /// 新增時寫進紀錄；編輯時用來顯示估算提示。
  final NutritionSource source;
  final int? foodItemId;
  final MealType mealType;
  final DateTime date;

  /// null = 新增模式。
  final FoodEntry? entry;

  @override
  ConsumerState<PortionEditorSheet> createState() => _PortionEditorSheetState();
}

class _PortionEditorSheetState extends ConsumerState<PortionEditorSheet> {
  late final TextEditingController _quantity;
  late ServingUnit _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _unit = entry.unit;
      _quantity = TextEditingController(text: _format(entry.quantity));
    } else {
      final supportsServing = widget.servingGrams != null;
      _unit = supportsServing ? ServingUnit.serving : ServingUnit.g;
      _quantity = TextEditingController(text: supportsServing ? '1' : '100');
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String? get _estimateNote => switch (widget.source) {
    NutritionSource.databaseEstimated => '複合餐點，營養為估算值，實際依店家而異',
    NutritionSource.aiEstimated => 'AI 估算的營養值，僅供參考',
    _ => null,
  };

  List<ServingUnit> get _units => [
    ServingUnit.g,
    ServingUnit.ml,
    if (widget.servingGrams != null) ServingUnit.serving,
  ];

  String _unitLabel(ServingUnit u) => switch (u) {
    ServingUnit.g => '公克',
    ServingUnit.ml => '毫升',
    ServingUnit.serving => widget.servingLabel ?? '份',
  };

  /// 輸入無效時回 null，UI 顯示提示而不是崩潰。
  ({double grams, NutritionFacts facts})? get _preview {
    final q = double.tryParse(_quantity.text.trim());
    if (q == null || !q.isFinite || q <= 0) return null;
    return NutritionCalculator.forPortion(
      per100g: widget.per100g,
      quantity: q,
      unit: _unit,
      servingGrams: widget.servingGrams,
    );
  }

  Future<void> _save() async {
    final p = _preview;
    if (p == null) return;
    final quantity = double.parse(_quantity.text.trim());
    final repo = ref.read(diaryRepositoryProvider);
    final entry = widget.entry;

    setState(() => _saving = true);
    try {
      if (entry == null) {
        await repo.addEntry(
          date: widget.date,
          mealType: widget.mealType,
          displayName: widget.name,
          quantity: quantity,
          unit: _unit,
          grams: p.grams,
          facts: p.facts,
          foodItemId: widget.foodItemId,
          nutritionSource: widget.source,
        );
      } else {
        await repo.updatePortion(
          entry.id,
          quantity: quantity,
          unit: _unit,
          grams: p.grams,
          facts: p.facts,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除這筆紀錄？'),
        content: Text(widget.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm_delete_button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(diaryRepositoryProvider).deleteEntry(widget.entry!.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final facts = p?.facts.rounded();
    final editing = widget.entry != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name, style: Theme.of(context).textTheme.titleLarge),
            if (_estimateNote case final note?) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('quantity_field'),
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: !editing,
                    decoration: InputDecoration(
                      labelText: '份量',
                      errorText: p == null ? '請輸入大於 0 的數字' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<ServingUnit>(
                  key: const Key('unit_dropdown'),
                  value: _unit,
                  items: [
                    for (final u in _units)
                      DropdownMenuItem(value: u, child: Text(_unitLabel(u))),
                  ],
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ],
            ),
            if (_unit == ServingUnit.serving && widget.servingGrams != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '1 ${_unitLabel(ServingUnit.serving)} '
                  '= ${widget.servingGrams!.round()} 公克',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 20),

            if (facts != null) ...[
              Text(
                key: const Key('preview_calories'),
                '${facts.calories.round()} 大卡',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '共 ${p!.grams.round()} 公克',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _nutrient('蛋白質', facts.protein, 'g'),
              _nutrient('碳水化合物', facts.carbs, 'g'),
              _nutrient('脂肪', facts.fat, 'g'),
              _nutrient('糖', facts.sugar, 'g'),
              _nutrient('膳食纖維', facts.fiber, 'g'),
              _nutrient('鈉', facts.sodium, 'mg'),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('confirm_entry_button'),
                onPressed: (p == null || _saving) ? null : _save,
                child: Text(editing ? '儲存' : '加入'),
              ),
            ),
            if (editing)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const Key('delete_entry_button'),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除這筆'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _saving ? null : _delete,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// null 代表資料不明，顯示「—」而不是 0。
  Widget _nutrient(String label, double? value, String unit) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value == null ? '—' : '${value.toStringAsFixed(1)} $unit'),
      ],
    ),
  );
}
