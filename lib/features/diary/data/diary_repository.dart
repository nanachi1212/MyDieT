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
  ///
  /// 存完整精度、顯示時才四捨五入：改份量時要從快照反推每 100g，
  /// 先四捨五入的話 1 公克的紀錄會變成 0，再也還原不回來。
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
            calories: facts.calories,
            protein: facts.protein,
            carbs: facts.carbs,
            fat: facts.fat,
            sugar: Value(facts.sugar),
            fiber: Value(facts.fiber),
            sodium: Value(facts.sodium),
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

  /// 改份量。[facts] 是新份量的實際營養，同樣以快照寫入。
  Future<void> updatePortion(
    int id, {
    required double quantity,
    required ServingUnit unit,
    required double grams,
    required NutritionFacts facts,
  }) {
    return (_db.update(_db.foodEntries)..where((t) => t.id.equals(id))).write(
      FoodEntriesCompanion(
        quantity: Value(quantity),
        unit: Value(unit),
        grams: Value(grams),
        calories: Value(facts.calories),
        protein: Value(facts.protein),
        carbs: Value(facts.carbs),
        fat: Value(facts.fat),
        sugar: Value(facts.sugar),
        fiber: Value(facts.fiber),
        sodium: Value(facts.sodium),
      ),
    );
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
