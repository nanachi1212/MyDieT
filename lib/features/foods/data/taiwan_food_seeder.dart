import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/database/app_database.dart';
import '../../diary/domain/diary_enums.dart';

/// 把內建的台灣食物 CSV 匯入 FoodItems。
///
/// 可以重複執行：已經存在的種子食物會跳過，不會產生重複，
/// 也絕不碰使用者自訂（source = userCustom）的資料。
class TaiwanFoodSeeder {
  TaiwanFoodSeeder(this._db, {Future<String> Function()? loadCsv})
    : _loadCsv = loadCsv ?? _loadFromAsset;

  static const assetPath = 'assets/data/taiwan_foods.csv';

  final AppDatabase _db;
  final Future<String> Function() _loadCsv;

  static Future<String> _loadFromAsset() => rootBundle.loadString(assetPath);

  /// 種子來源的兩種 source，判斷「已存在」時只看這兩種。
  static const seedSources = [
    FoodSource.taiwanSeed,
    FoodSource.taiwanSeedEstimated,
  ];

  /// 回傳這次實際新增的筆數。
  Future<int> seed({DateTime? now}) async {
    final ts = now ?? DateTime.now();
    final rows = parseCsv(await _loadCsv());
    if (rows.isEmpty) return 0;

    final existing = await (_db.select(
      _db.foodItems,
    )..where((t) => t.source.isInValues(seedSources))).get();
    final existingNames = existing.map((e) => e.name).toSet();

    final toInsert = rows
        .where((r) => !existingNames.contains(r.name))
        .toList();
    if (toInsert.isEmpty) return 0;

    await _db.batch((b) {
      b.insertAll(_db.foodItems, [
        for (final r in toInsert)
          FoodItemsCompanion.insert(
            name: r.name,
            nameEn: Value(r.nameEn),
            category: r.category,
            calories: r.calories,
            protein: r.protein,
            carbs: r.carbs,
            fat: r.fat,
            sugar: Value(r.sugar),
            fiber: Value(r.fiber),
            sodium: Value(r.sodium),
            defaultServingGrams: Value(r.servingGrams),
            defaultServingLabel: Value(r.servingLabel),
            source: r.estimated
                ? FoodSource.taiwanSeedEstimated
                : FoodSource.taiwanSeed,
            createdAt: ts,
            updatedAt: ts,
          ),
      ]);
    });

    return toInsert.length;
  }

  /// 解析 CSV。忽略空行、`#` 開頭的註解行與表頭。
  ///
  /// 欄位不含逗號，所以用 split 就夠，不需要額外的 CSV 套件。
  static List<SeedFood> parseCsv(String csv) {
    final out = <SeedFood>[];

    for (final raw in csv.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('name,')) continue; // 表頭

      final c = line.split(',');
      if (c.length < 13) continue;

      out.add(
        SeedFood(
          name: c[0].trim(),
          nameEn: _text(c[1]),
          category: _category(c[2].trim()),
          calories: double.parse(c[3]),
          protein: double.parse(c[4]),
          carbs: double.parse(c[5]),
          fat: double.parse(c[6]),
          sugar: _number(c[7]),
          fiber: _number(c[8]),
          sodium: _number(c[9]),
          servingGrams: _number(c[10]),
          servingLabel: _text(c[11]),
          estimated: c[12].trim() == '1',
        ),
      );
    }

    return out;
  }

  /// 空欄位代表「不知道」，回 null，**不可以變成 0**。
  static double? _number(String s) {
    final t = s.trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  static String? _text(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static FoodCategory _category(String s) => FoodCategory.values.firstWhere(
    (c) => c.name == s,
    orElse: () => FoodCategory.other,
  );
}

/// CSV 的一列。
class SeedFood {
  const SeedFood({
    required this.name,
    required this.nameEn,
    required this.category,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    required this.fiber,
    required this.sodium,
    required this.servingGrams,
    required this.servingLabel,
    required this.estimated,
  });

  final String name;
  final String? nameEn;
  final FoodCategory category;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? sugar;
  final double? fiber;
  final double? sodium;
  final double? servingGrams;
  final String? servingLabel;
  final bool estimated;
}
