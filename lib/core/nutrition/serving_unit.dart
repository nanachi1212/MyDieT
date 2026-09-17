/// 使用者輸入份量時可以選的單位。
enum ServingUnit {
  /// 公克。
  g,

  /// 毫升。換算成公克時以 1 ml = 1 g 近似處理，見 NutritionCalculator。
  ml,

  /// 份（碗、顆、片…）。需要食物本身提供 defaultServingGrams 才能換算。
  serving,
}
