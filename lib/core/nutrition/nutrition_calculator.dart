import 'nutrition_facts.dart';
import 'serving_unit.dart';

/// 份量 → 實際營養的換算。純 Dart，無狀態，不依賴 Flutter。
///
/// 責任分離（見 PROJECT_SPEC 第 7 節）：
///   AI          → 「這是什麼食物、大概幾公克」
///   食物資料庫   → 「這個食物每 100g 的營養」
///   本計算機     → 「依實際份量算出要記錄的營養」
///
/// AI 不參與這裡的任何計算。
abstract final class NutritionCalculator {
  /// 把使用者輸入的份量換算成公克。
  ///
  /// - [ServingUnit.g]：直接回傳
  /// - [ServingUnit.ml]：以 1 ml = 1 g 近似。多數飲品（水、茶、豆漿）誤差在
  ///   幾個百分比內；油脂類（約 0.92）與糖漿類會低估或高估。需要精確值時，
  ///   請在食物資料裡用 serving 定義實際公克數。
  /// - [ServingUnit.serving]：需要 [servingGrams]，缺少時拋出 [ArgumentError]
  static double toGrams({
    required double quantity,
    required ServingUnit unit,
    double? servingGrams,
  }) {
    if (quantity.isNaN || quantity.isInfinite) {
      throw ArgumentError.value(quantity, 'quantity', '必須是有限數值');
    }
    if (quantity < 0) {
      throw ArgumentError.value(quantity, 'quantity', '份量不可為負數');
    }

    switch (unit) {
      case ServingUnit.g:
      case ServingUnit.ml:
        return quantity;
      case ServingUnit.serving:
        if (servingGrams == null) {
          throw ArgumentError.notNull('servingGrams');
        }
        if (servingGrams <= 0) {
          throw ArgumentError.value(servingGrams, 'servingGrams', '必須大於 0');
        }
        return quantity * servingGrams;
    }
  }

  /// 由「每 100g 營養」與實際公克數，算出這一筆紀錄的營養快照。
  ///
  /// 回傳值保留完整精度；要寫入資料庫或顯示時再自行呼叫
  /// [NutritionFacts.rounded]。
  static NutritionFacts forGrams({
    required NutritionFacts per100g,
    required double grams,
  }) {
    if (grams.isNaN || grams.isInfinite) {
      throw ArgumentError.value(grams, 'grams', '必須是有限數值');
    }
    if (grams < 0) {
      throw ArgumentError.value(grams, 'grams', '不可為負數');
    }
    return per100g.scale(grams / 100);
  }

  /// [toGrams] 與 [forGrams] 的組合，一步從使用者輸入算到營養快照。
  static ({double grams, NutritionFacts facts}) forPortion({
    required NutritionFacts per100g,
    required double quantity,
    required ServingUnit unit,
    double? servingGrams,
  }) {
    final grams = toGrams(
      quantity: quantity,
      unit: unit,
      servingGrams: servingGrams,
    );
    return (grams: grams, facts: forGrams(per100g: per100g, grams: grams));
  }
}
