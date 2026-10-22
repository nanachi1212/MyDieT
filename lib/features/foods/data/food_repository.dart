import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/nutrition_facts.dart';
import '../../diary/domain/diary_enums.dart';

/// 食物字典的查詢與建立。
///
/// P1 只有本機 SQLite 一個來源（內建種子 + 使用者自訂都存在同一張表），
/// 因此不抽 NutritionSource 介面。等 P4 接上 Open Food Facts 再抽。
class FoodRepository {
  FoodRepository(this._db);

  final AppDatabase _db;

  /// 依名稱模糊搜尋。空字串回傳空清單（讓 UI 顯示「最近使用」）。
  Future<List<FoodItem>> search(String query, {int limit = 50}) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);

    final pattern = '%$q%';
    return (_db.select(_db.foodItems)
          ..where((t) => t.name.like(pattern) | t.nameEn.like(pattern))
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .get();
  }

  Future<FoodItem?> byId(int id) => (_db.select(
    _db.foodItems,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 最近使用過的食物，依最後一次記錄時間排序。
  Future<List<FoodItem>> recentlyUsed({int limit = 10}) async {
    final rows = await _db
        .customSelect(
          'SELECT food_item_id FROM food_entries '
          'WHERE food_item_id IS NOT NULL '
          'GROUP BY food_item_id '
          'ORDER BY MAX(created_at) DESC LIMIT ?1',
          variables: [Variable.withInt(limit)],
          readsFrom: {_db.foodEntries},
        )
        .get();

    final ids = rows.map((r) => r.read<int>('food_item_id')).toList();
    if (ids.isEmpty) return const [];

    final items = await (_db.select(
      _db.foodItems,
    )..where((t) => t.id.isIn(ids))).get();

    // 照 ids 的順序排回來
    final byIdMap = {for (final i in items) i.id: i};
    return [
      for (final id in ids)
        if (byIdMap[id] != null) byIdMap[id]!,
    ];
  }

  /// 建立使用者自訂食物，source 固定為 userCustom。
  Future<FoodItem> createCustom({
    required String name,
    required FoodCategory category,
    required NutritionFacts per100g,
    double? defaultServingGrams,
    String? defaultServingLabel,
    DateTime? now,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', '名稱不可為空');
    }
    final ts = now ?? DateTime.now();

    final id = await _db
        .into(_db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            name: trimmed,
            category: category,
            calories: per100g.calories,
            protein: per100g.protein,
            carbs: per100g.carbs,
            fat: per100g.fat,
            sugar: Value(per100g.sugar),
            fiber: Value(per100g.fiber),
            sodium: Value(per100g.sodium),
            defaultServingGrams: Value(defaultServingGrams),
            defaultServingLabel: Value(defaultServingLabel),
            source: FoodSource.userCustom,
            createdAt: ts,
            updatedAt: ts,
          ),
        );

    return (await byId(id))!;
  }
}

/// 把 FoodItem 的每 100g 欄位取成 NutritionFacts。
extension FoodItemNutrition on FoodItem {
  NutritionFacts get per100g => NutritionFacts(
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    sugar: sugar,
    fiber: fiber,
    sodium: sodium,
  );

  /// 複合餐點的營養只是估算值，UI 要標示出來。
  bool get isEstimated => source == FoodSource.taiwanSeedEstimated;

  bool get supportsServingUnit => defaultServingGrams != null;
}
