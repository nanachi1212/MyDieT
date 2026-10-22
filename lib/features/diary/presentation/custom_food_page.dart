import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/nutrition_facts.dart';
import '../../../core/providers.dart';
import '../domain/diary_enums.dart';

/// 建立使用者自訂食物。所有數值都是「每 100 公克」。
class CustomFoodPage extends ConsumerStatefulWidget {
  const CustomFoodPage({super.key});

  @override
  ConsumerState<CustomFoodPage> createState() => _CustomFoodPageState();
}

class _CustomFoodPageState extends ConsumerState<CustomFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _sugar = TextEditingController();
  final _fiber = TextEditingController();
  final _sodium = TextEditingController();

  FoodCategory _category = FoodCategory.other;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _calories,
      _protein,
      _carbs,
      _fat,
      _sugar,
      _fiber,
      _sodium,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String categoryLabel(FoodCategory c) => switch (c) {
    FoodCategory.grains => '全穀雜糧',
    FoodCategory.protein => '豆魚蛋肉',
    FoodCategory.vegetables => '蔬菜',
    FoodCategory.fruits => '水果',
    FoodCategory.dairy => '乳品',
    FoodCategory.fatsAndNuts => '油脂與堅果',
    FoodCategory.other => '其他',
  };

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? '必填' : _optional(v);

  String? _optional(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null || !d.isFinite) return '請輸入數字';
    if (d < 0) return '不可為負數';
    return null;
  }

  /// 留空 = 不知道，存成 null，不會變成 0。
  double? _parseOptional(TextEditingController c) =>
      double.tryParse(c.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final food = await ref
          .read(foodRepositoryProvider)
          .createCustom(
            name: _name.text,
            category: _category,
            per100g: NutritionFacts(
              calories: double.parse(_calories.text.trim()),
              protein: double.parse(_protein.text.trim()),
              carbs: double.parse(_carbs.text.trim()),
              fat: double.parse(_fat.text.trim()),
              sugar: _parseOptional(_sugar),
              fiber: _parseOptional(_fiber),
              sodium: _parseOptional(_sodium),
            ),
          );
      if (mounted) Navigator.pop<FoodItem>(context, food);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立自訂食物')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('custom_name_field'),
              controller: _name,
              decoration: const InputDecoration(labelText: '食物名稱'),
              validator: (v) => (v ?? '').trim().isEmpty ? '請輸入食物名稱' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<FoodCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '食物分類'),
              items: [
                for (final c in FoodCategory.values)
                  DropdownMenuItem(value: c, child: Text(categoryLabel(c))),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 24),

            Text(
              '以下數值都是「每 100 公克」的含量',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),

            _field('custom_calories_field', _calories, '熱量', 'kcal', _required),
            _field('custom_protein_field', _protein, '蛋白質', 'g', _required),
            _field('custom_carbs_field', _carbs, '碳水化合物', 'g', _required),
            _field('custom_fat_field', _fat, '脂肪', 'g', _required),
            _field('custom_sugar_field', _sugar, '糖（可不填）', 'g', _optional),
            _field('custom_fiber_field', _fiber, '膳食纖維（可不填）', 'g', _optional),
            _field('custom_sodium_field', _sodium, '鈉（可不填）', 'mg', _optional),

            const SizedBox(height: 8),
            Text(
              '不知道的欄位請留空，不要填 0 —— 留空代表「沒有資料」，0 代表「確實是零」。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            FilledButton(
              key: const Key('custom_save_button'),
              onPressed: _saving ? null : _save,
              child: const Text('建立'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String key,
    TextEditingController c,
    String label,
    String suffix,
    String? Function(String?) validator,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: Key(key),
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: validator,
    ),
  );
}
