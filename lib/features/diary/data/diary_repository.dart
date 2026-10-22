import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/nutrition_facts.dart';
import '../../../core/nutrition/serving_unit.dart';
import '../domain/diary_enums.dart';

/// 飲食紀錄的讀寫。
class DiaryRepository {
  DiaryRepository(this._db);

  final AppDatabase _db;

  /// 新增一筆紀錄。
  ///
  /// [facts] 是「這一份的實際營養」，不是每 100g。寫進去之後就是快照，
  /// 之後 FoodItems 再怎麼修正都不會影響這一筆。
  Future<int> addEntry({
    required DateTime date,
    required MealType mealType,
    required String displayName,
    required double quantity,
    required ServingUnit unit,
    required double grams,
    required NutritionFacts facts,
    int? foodItemId,
    NutritionSource nutritionSource = NutritionSource.database,
    DateTime? now,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final snapshot = facts.rounded();

    return _db
        .into(_db.foodEntries)
        .insert(
          FoodEntriesCompanion.insert(
            date: day,
            mealType: mealType,
            foodItemId: Value(foodItemId),
            displayName: displayName,
            quantity: quantity,
            unit: unit,
            grams: grams,
            calories: snapshot.calories,
            protein: snapshot.protein,
            carbs: snapshot.carbs,
            fat: snapshot.fat,
            sugar: Value(snapshot.sugar),
            fiber: Value(snapshot.fiber),
            sodium: Value(snapshot.sodium),
            nutritionSource: nutritionSource,
            createdAt: now ?? DateTime.now(),
          ),
        );
  }

  Future<List<FoodEntry>> entriesForDay(DateTime date) => _day(date).get();

  Stream<List<FoodEntry>> watchDay(DateTime date) => _day(date).watch();

  SimpleSelectStatement<$FoodEntriesTable, FoodEntry> _day(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _db.select(_db.foodEntries)
      ..where((t) => t.date.equals(day))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
  }

  Future<void> deleteEntry(int id) =>
      (_db.delete(_db.foodEntries)..where((t) => t.id.equals(id))).go();
}

/// 把 FoodEntry 的營養快照欄位取成 NutritionFacts。
extension FoodEntryNutrition on FoodEntry {
  NutritionFacts get facts => NutritionFacts(
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    sugar: sugar,
    fiber: fiber,
    sodium: sodium,
  );
}
