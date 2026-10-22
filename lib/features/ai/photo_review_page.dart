import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition/nutrition_facts.dart';
import '../../core/nutrition/serving_unit.dart';
import '../../core/providers.dart';
import '../diary/domain/diary_enums.dart';
import '../diary/presentation/add_food_page.dart';
import '../foods/data/food_repository.dart';
import 'food_recognizer.dart';

/// 拍照辨識的確認頁：AI 結果逐項列出，可改名、改份量、刪除，
/// **按下加入之前不寫入任何紀錄**。
///
/// 營養優先用本機資料庫（名稱完全相同才算），查不到才用 AI 的估算值，
/// 並標示「AI 估算」。
class PhotoReviewPage extends ConsumerStatefulWidget {
  const PhotoReviewPage({
    super.key,
    required this.image,
    required this.meal,
    required this.date,
  });

  final Uint8List image;
  final MealType meal;
  final DateTime date;

  @override
  ConsumerState<PhotoReviewPage> createState() => _PhotoReviewPageState();
}

class _Item {
  _Item({
    required String name,
    required double grams,
    required this.per100g,
    required this.foodItemId,
  }) : name = TextEditingController(text: name),
       grams = TextEditingController(text: '${grams.round()}');

  final TextEditingController name;
  final TextEditingController grams;
  final NutritionFacts per100g;

  /// null = 資料庫查不到，營養用 AI 估算值。
  final int? foodItemId;

  double? get gramsValue {
    final g = double.tryParse(grams.text.trim());
    return g == null || !g.isFinite || g <= 0 ? null : g;
  }

  void dispose() {
    name.dispose();
    grams.dispose();
  }
}

class _PhotoReviewPageState extends ConsumerState<PhotoReviewPage> {
  late MealType _meal = widget.meal;
  List<_Item>? _items;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  @override
  void dispose() {
    for (final i in _items ?? const <_Item>[]) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final config = await ref.read(aiConfigStoreProvider).load();
      if (config == null) {
        throw const AiException('還沒設定 AI 服務，請先到「設定」輸入 API key');
      }
      final foods = ref.read(foodRepositoryProvider);
      final found = await ref
          .read(foodRecognizerFactoryProvider)(config)
          .recognize(widget.image, knownNames: await foods.allNames());

      final items = <_Item>[];
      for (final f in found) {
        final db = await foods.byExactName(f.name);
        items.add(
          _Item(
            name: db?.name ?? f.name,
            grams: f.grams,
            per100g: db?.per100g ?? f.per100g,
            foodItemId: db?.id,
          ),
        );
      }
      if (mounted) setState(() => _items = items);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '辨識失敗，請再試一次或改用手動輸入');
    }
  }

  Future<void> _save() async {
    final items = _items!;
    final diary = ref.read(diaryRepositoryProvider);
    setState(() => _saving = true);
    try {
      // 全部成功或全部不寫，不會只記到一半
      await ref.read(appDatabaseProvider).transaction(() async {
        for (final i in items) {
          final g = i.gramsValue!;
          final name = i.name.text.trim();
          await diary.addEntry(
            date: widget.date,
            mealType: _meal,
            displayName: name.isEmpty ? '未命名食物' : name,
            quantity: g,
            unit: ServingUnit.g,
            grams: g,
            facts: i.per100g.scale(g / 100),
            foodItemId: i.foodItemId,
            nutritionSource: i.foodItemId == null
                ? NutritionSource.aiEstimated
                : NutritionSource.database,
          );
        }
      });
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _remove(_Item item) {
    setState(() => _items!.remove(item));
    item.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final valid =
        items != null &&
        items.isNotEmpty &&
        items.every((i) => i.gramsValue != null);

    return Scaffold(
      appBar: AppBar(title: const Text('確認辨識結果')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              widget.image,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            _ErrorView(
              message: _error!,
              onRetry: _analyze,
              onManual: () => Navigator.pop(context, false),
            )
          else if (items == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('AI 辨識中…'),
                ],
              ),
            )
          else ...[
            SegmentedButton<MealType>(
              segments: [
                for (final m in MealType.values)
                  ButtonSegment(value: m, label: Text(mealTypeLabel(m))),
              ],
              selected: {_meal},
              onSelectionChanged: (v) => setState(() => _meal = v.first),
            ),
            const SizedBox(height: 8),
            Text(
              items.isEmpty ? '沒有認出食物，可以重拍或改用手動輸入' : '份量是 AI 估計的，加入前可以修改',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final (index, item) in items.indexed)
              _ItemCard(
                key: ObjectKey(item),
                index: index,
                item: item,
                onChanged: () => setState(() {}),
                onRemove: () => _remove(item),
              ),
          ],
        ],
      ),
      bottomNavigationBar: items == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  key: const Key('photo_confirm_button'),
                  onPressed: valid && !_saving ? _save : null,
                  child: Text('加入 ${items.length} 項，共 ${_totalKcal(items)} 大卡'),
                ),
              ),
            ),
    );
  }

  static int _totalKcal(List<_Item> items) => items
      .fold(0.0, (a, i) => a + i.per100g.calories * (i.gramsValue ?? 0) / 100)
      .round();
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _Item item;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final g = item.gramsValue;
    final theme = Theme.of(context);
    final fromDb = item.foodItemId != null;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('photo_name_$index'),
                    controller: item.name,
                    decoration: const InputDecoration(
                      labelText: '名稱',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('photo_remove_$index'),
                  tooltip: '刪除這項',
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: Key('photo_grams_$index'),
                    controller: item.grams,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '份量',
                      suffixText: '公克',
                      isDense: true,
                      errorText: g == null ? '請輸入大於 0' : null,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        key: Key('photo_kcal_$index'),
                        g == null
                            ? '—'
                            : '${(item.per100g.calories * g / 100).round()} 大卡',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        fromDb ? '資料庫' : 'AI 估算',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fromDb
                              ? theme.colorScheme.primary
                              : theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onManual,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(key: const Key('photo_error'), message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        children: [
          OutlinedButton(onPressed: onRetry, child: const Text('再試一次')),
          FilledButton(onPressed: onManual, child: const Text('改用手動輸入')),
        ],
      ),
    ],
  );
}
