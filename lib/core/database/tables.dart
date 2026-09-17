import 'package:drift/drift.dart';

import '../../features/diary/domain/diary_enums.dart';
import '../../features/profile/domain/profile_enums.dart';
import '../nutrition/serving_unit.dart';

/// 使用者 Profile。單列表，id 固定為 1。
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get biologicalSex => textEnum<BiologicalSex>()();
  DateTimeColumn get birthDate => dateTime()();
  RealColumn get heightCm => real()();
  TextColumn get activityLevel => textEnum<ActivityLevel>()();
  TextColumn get goalType => textEnum<GoalType>()();
  RealColumn get targetWeightKg => real().nullable()();

  /// 使用者手動覆寫的每日熱量目標。null = 用計算值。
  IntColumn get manualCalorieOverride => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// 體重與體脂紀錄。同一天可以有多筆（早晚各量一次）。
class BodyMeasurements extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 量測時間點。
  DateTimeColumn get measuredAt => dateTime()();
  RealColumn get weightKg => real()();
  RealColumn get bodyFatPercent => real().nullable()();
  TextColumn get source => textEnum<MeasurementSource>()();

  DateTimeColumn get createdAt => dateTime()();
}

/// 每日熱量／營養目標。
///
/// 稀疏儲存：只有「目標變更的那一天」才會有一筆。查某一天的目標時，取
/// `effectiveFrom <= 該日` 的最新一筆；查不到就用 EnergyCalculator 依
/// Profile 現算。
///
/// 需要獨立成表是因為目標會隨時間改變，而上個月的日記必須對照當時的目標，
/// 不能被今天改過的目標追溯覆蓋。理由與 BodyMeasurements 相同。
class DailyNutritionTargets extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 這筆目標的生效日（當天 00:00）。
  DateTimeColumn get effectiveFrom => dateTime().unique()();

  IntColumn get calorieTarget => integer()();
  RealColumn get proteinTargetG => real().nullable()();
  RealColumn get carbsTargetG => real().nullable()();
  RealColumn get fatTargetG => real().nullable()();

  /// true = 使用者手動指定，false = 由 TDEE 計算而來。
  BoolColumn get isManualOverride =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// 食物字典：每 100g 的營養資料。
///
/// 這張表就是 PROJECT_SPEC 裡講的 NutritionFacts 資料層 —— 營養數值以欄位
/// 內嵌，不另外開一張 NutritionFacts 表（見 FoodEntries 的說明）。
class FoodItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();
  TextColumn get nameEn => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get category => textEnum<FoodCategory>()();
  TextColumn get barcode => text().nullable()();

  // ---- 每 100g 營養 ----
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  RealColumn get sugar => real().nullable()();
  RealColumn get fiber => real().nullable()();
  RealColumn get sodium => real().nullable()();

  /// 一份等於幾公克，例如「1 碗 = 200g」。null = 不支援以「份」輸入。
  RealColumn get defaultServingGrams => real().nullable()();

  /// 份的顯示名稱，例如「碗」「顆」「片」。
  TextColumn get defaultServingLabel => text().nullable()();

  TextColumn get source => textEnum<FoodSource>()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// 實際的飲食紀錄。
///
/// **營養數值是快照，不是參照。** FoodItems 之後修正數值時，已經記下的
/// FoodEntry 必須維持當時的數字，否則上個月的日記會無聲地變動。
/// 這是全專案唯一一處刻意的資料重複。
class FoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 這筆吃的日期（當天 00:00，不含時間）。
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => textEnum<MealType>()();

  /// 對應的食物字典項目。食物被刪除時設為 null，紀錄本身仍保留。
  /// AI 一次性估算的品項本來就沒有對應項目，也是 null。
  IntColumn get foodItemId => integer().nullable().references(
    FoodItems,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 顯示用名稱快照。即使 foodItemId 為 null 也要看得出吃了什麼。
  TextColumn get displayName => text()();

  RealColumn get quantity => real()();
  TextColumn get unit => textEnum<ServingUnit>()();

  /// 正規化後的公克數，由 NutritionCalculator.toGrams 算出。
  RealColumn get grams => real()();

  // ---- 營養快照（這一份的實際數值，不是每 100g）----
  RealColumn get calories => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  RealColumn get sugar => real().nullable()();
  RealColumn get fiber => real().nullable()();
  RealColumn get sodium => real().nullable()();

  TextColumn get nutritionSource => textEnum<NutritionSource>()();

  DateTimeColumn get createdAt => dateTime()();
}
