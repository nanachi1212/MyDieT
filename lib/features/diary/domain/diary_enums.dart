/// 餐別。FoodEntry 直接帶這個欄位，不另建 Meals 表 —— 一筆紀錄屬於哪一餐
/// 就是一個分類，額外開一張表只會多一次 join，不會多出任何資訊。
enum MealType { breakfast, lunch, dinner, snack }

/// 食物六大類（衛福部口徑）。
///
/// 注意：這是**食物分類**，不是 macro nutrient。營養素請看 NutritionFacts。
enum FoodCategory {
  /// 全穀雜糧
  grains,

  /// 豆魚蛋肉
  protein,

  /// 蔬菜
  vegetables,

  /// 水果
  fruits,

  /// 乳品
  dairy,

  /// 油脂與堅果
  fatsAndNuts,

  /// 無法歸類（複合餐點、加工食品）
  other,
}

/// 食物資料的來源。
enum FoodSource {
  /// App 內建的台灣食物種子資料
  taiwanSeed,

  /// 使用者自己建立
  userCustom,

  /// AI 估算，資料庫查不到時的 fallback（UI 必須標示為估算值）
  aiEstimated,

  /// Open Food Facts 條碼資料
  openFoodFacts,
}

/// 這筆 FoodEntry 的營養數值從哪來。
enum NutritionSource {
  /// 來自食物資料庫
  database,

  /// 來自 AI 估算
  aiEstimated,

  /// 使用者手動修改過
  userEdited,
}

/// 體重／體脂紀錄的來源。
enum MeasurementSource {
  /// 使用者手動輸入
  manual,

  /// 從 Apple Health / Health Connect 同步進來
  health,
}
