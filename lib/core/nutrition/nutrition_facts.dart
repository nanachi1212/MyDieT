/// Macro 佔熱量的百分比。
class MacroPercent {
  const MacroPercent({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double protein;
  final double carbs;
  final double fat;

  @override
  String toString() =>
      'MacroPercent(P: ${protein.toStringAsFixed(1)}%, '
      'C: ${carbs.toStringAsFixed(1)}%, F: ${fat.toStringAsFixed(1)}%)';
}

/// 營養素數值。單位固定：calories = kcal，protein/carbs/fat/sugar/fiber = g，
/// sodium = mg。
///
/// 可以表示「每 100g 的營養」，也可以表示「某一份實際餐點的營養」，
/// 由使用端決定語意。
///
/// sugar / fiber / sodium 是 nullable：**缺資料就是 null，不可以填 0**。
/// 0 代表「確實含量為零」，null 代表「不知道」，UI 必須分開呈現。
class NutritionFacts {
  const NutritionFacts({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sugar,
    this.fiber,
    this.sodium,
  });

  /// 全部為 0（不是「未知」）。日累計的起始值。
  static const zero = NutritionFacts(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    sugar: 0,
    fiber: 0,
    sodium: 0,
  );

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? sugar;
  final double? fiber;
  final double? sodium;

  /// 依比例縮放。[factor] 不可為負。
  NutritionFacts scale(double factor) {
    if (factor.isNaN || factor.isInfinite) {
      throw ArgumentError.value(factor, 'factor', '必須是有限數值');
    }
    if (factor < 0) {
      throw ArgumentError.value(factor, 'factor', '不可為負數');
    }
    return NutritionFacts(
      calories: calories * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      sugar: sugar == null ? null : sugar! * factor,
      fiber: fiber == null ? null : fiber! * factor,
      sodium: sodium == null ? null : sodium! * factor,
    );
  }

  /// 相加，用於當日累計。
  ///
  /// nullable 欄位規則：兩邊都是 null 才回 null，否則把已知的加總。
  /// 也就是「未知」不會把整天的已知數值洗掉，但總和會是低估值。
  NutritionFacts operator +(NutritionFacts other) => NutritionFacts(
    calories: calories + other.calories,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
    sugar: _addNullable(sugar, other.sugar),
    fiber: _addNullable(fiber, other.fiber),
    sodium: _addNullable(sodium, other.sodium),
  );

  static double? _addNullable(double? a, double? b) {
    if (a == null && b == null) return null;
    return (a ?? 0) + (b ?? 0);
  }

  /// 四捨五入。計算過程保留完整精度，只在寫入或顯示時呼叫這個。
  NutritionFacts rounded({int decimals = 1}) {
    if (decimals < 0) {
      throw ArgumentError.value(decimals, 'decimals', '不可為負數');
    }
    return NutritionFacts(
      calories: _round(calories, decimals),
      protein: _round(protein, decimals),
      carbs: _round(carbs, decimals),
      fat: _round(fat, decimals),
      sugar: sugar == null ? null : _round(sugar!, decimals),
      fiber: fiber == null ? null : _round(fiber!, decimals),
      sodium: sodium == null ? null : _round(sodium!, decimals),
    );
  }

  static double _round(double v, int decimals) {
    final f = _pow10(decimals);
    return (v * f).roundToDouble() / f;
  }

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// 三大 macro 各自的熱量佔比。
  ///
  /// 分母是「三者熱量總和」而不是 [calories]，避免酒精或資料誤差
  /// 造成三個百分比加起來不足 100%。三者皆為 0 時回傳 0/0/0。
  MacroPercent get macroPercent {
    final p = protein * 4;
    final c = carbs * 4;
    final f = fat * 9;
    final total = p + c + f;
    if (total <= 0) {
      return const MacroPercent(protein: 0, carbs: 0, fat: 0);
    }
    return MacroPercent(
      protein: p / total * 100,
      carbs: c / total * 100,
      fat: f / total * 100,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NutritionFacts &&
      other.calories == calories &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat &&
      other.sugar == sugar &&
      other.fiber == fiber &&
      other.sodium == sodium;

  @override
  int get hashCode =>
      Object.hash(calories, protein, carbs, fat, sugar, fiber, sodium);

  @override
  String toString() =>
      'NutritionFacts(${calories.toStringAsFixed(1)} kcal, '
      'P ${protein.toStringAsFixed(1)}g, C ${carbs.toStringAsFixed(1)}g, '
      'F ${fat.toStringAsFixed(1)}g)';
}
