import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/nutrition_calculator.dart';
import '../../../core/nutrition/nutrition_facts.dart';
import '../../../core/nutrition/serving_unit.dart';
import '../../../core/providers.dart';
import '../../foods/data/food_repository.dart';
import '../domain/diary_enums.dart';

/// 輸入份量並即時看到營養，確認後寫入 FoodEntry。
class PortionEditorSheet extends ConsumerStatefulWidget {
  const PortionEditorSheet({
    super.key,
    required this.food,
    required this.mealType,
    required this.date,
  });

  final FoodItem food;
  final MealType mealType;
  final DateTime date;

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
    final supportsServing = widget.food.supportsServingUnit;
    _unit = supportsServing ? ServingUnit.serving : ServingUnit.g;
    _quantity = TextEditingController(text: supportsServing ? '1' : '100');
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  List<ServingUnit> get _units => [
    ServingUnit.g,
    ServingUnit.ml,
    if (widget.food.supportsServingUnit) ServingUnit.serving,
  ];

  String _unitLabel(ServingUnit u) => switch (u) {
    ServingUnit.g => '公克',
    ServingUnit.ml => '毫升',
    ServingUnit.serving => widget.food.defaultServingLabel ?? '份',
  };

  /// 輸入無效時回 null，UI 顯示提示而不是崩潰。
  ({double grams, NutritionFacts facts})? get _preview {
    final q = double.tryParse(_quantity.text.trim());
    if (q == null || q < 0) return null;
    return NutritionCalculator.forPortion(
      per100g: widget.food.per100g,
      quantity: q,
      unit: _unit,
      servingGrams: widget.food.defaultServingGrams,
    );
  }

  Future<void> _save() async {
    final p = _preview;
    if (p == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(diaryRepositoryProvider)
          .addEntry(
            date: widget.date,
            mealType: widget.mealType,
            displayName: widget.food.name,
            quantity: double.parse(_quantity.text.trim()),
            unit: _unit,
            grams: p.grams,
            facts: p.facts,
            foodItemId: widget.food.id,
            nutritionSource: NutritionSource.database,
          );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final facts = p?.facts.rounded();

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
            Text(
              widget.food.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.food.isEstimated) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '複合餐點，營養為估算值，實際依店家而異',
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
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '份量',
                      border: const OutlineInputBorder(),
                      errorText: p == null ? '請輸入 0 以上的數字' : null,
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
            if (_unit == ServingUnit.serving &&
                widget.food.defaultServingGrams != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '1 ${_unitLabel(ServingUnit.serving)} '
                  '= ${widget.food.defaultServingGrams!.round()} 公克',
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
                child: const Text('加入'),
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
