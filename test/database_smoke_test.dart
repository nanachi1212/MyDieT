// drift 也匯出 isNull，與 flutter_test 的 matcher 撞名。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/nutrition/serving_unit.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';

/// schemaVersion 1（P0）時的 user_profiles DDL，用來驗證 v1 → v2 migration。
/// 這是當時 drift 實際產生的結構，不要隨新版 schema 一起改。
const _v1UserProfilesDdl = '''
CREATE TABLE user_profiles (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  biological_sex TEXT NOT NULL,
  birth_date INTEGER NOT NULL,
  height_cm REAL NOT NULL,
  activity_level TEXT NOT NULL,
  goal_type TEXT NOT NULL,
  target_weight_kg REAL NULL,
  manual_calorie_override INTEGER NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''';

void main() {
  late AppDatabase db;

  final now = DateTime(2026, 9, 17, 12);
  final birth = DateTime(1990, 5, 20);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> insertProfile() => db
      .into(db.userProfiles)
      .insert(
        UserProfilesCompanion.insert(
          biologicalSex: BiologicalSex.female,
          birthDate: birth,
          heightCm: 162.5,
          activityLevel: ActivityLevel.moderate,
          goalType: GoalType.lose,
          targetWeightKg: const Value(52.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

  Future<int> insertRice() => db
      .into(db.foodItems)
      .insert(
        FoodItemsCompanion.insert(
          name: '白飯',
          nameEn: const Value('steamed white rice'),
          category: FoodCategory.grains,
          calories: 130,
          protein: 2.7,
          carbs: 28,
          fat: 0.3,
          sugar: const Value(0.1),
          sodium: const Value(1),
          defaultServingGrams: const Value(200),
          defaultServingLabel: const Value('碗'),
          source: FoodSource.taiwanSeed,
          createdAt: now,
          updatedAt: now,
        ),
      );

  test('schemaVersion 為 2', () {
    expect(db.schemaVersion, 2);
  });

  group('UserProfiles', () {
    test('寫入後可以讀回相同資料', () async {
      final id = await insertProfile();
      final saved = await db.select(db.userProfiles).getSingle();

      expect(saved.id, id);
      expect(saved.biologicalSex, BiologicalSex.female);
      expect(saved.birthDate, birth);
      expect(saved.heightCm, 162.5);
      expect(saved.activityLevel, ActivityLevel.moderate);
      expect(saved.goalType, GoalType.lose);
      expect(saved.targetWeightKg, 52.0);
      // 未設定時必須是 null，不可以變成 0
      expect(saved.manualCalorieOverride, isNull);
    });
  });

  group('BodyMeasurements', () {
    test('同一天可以有多筆，體脂未填時為 null', () async {
      await db
          .into(db.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              measuredAt: DateTime(2026, 9, 17, 7),
              weightKg: 58.4,
              source: MeasurementSource.manual,
              createdAt: now,
            ),
          );
      await db
          .into(db.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              measuredAt: DateTime(2026, 9, 17, 22),
              weightKg: 59.1,
              bodyFatPercent: const Value(24.5),
              source: MeasurementSource.health,
              createdAt: now,
            ),
          );

      final rows = await db.select(db.bodyMeasurements).get();
      expect(rows, hasLength(2));
      expect(rows.first.bodyFatPercent, isNull);
      expect(rows.last.bodyFatPercent, 24.5);
      expect(rows.last.source, MeasurementSource.health);
    });
  });

  group('DailyNutritionTargets', () {
    test('生效日唯一，重複寫入同一天會失敗', () async {
      Future<void> insert(DateTime d, int kcal) => db
          .into(db.dailyNutritionTargets)
          .insert(
            DailyNutritionTargetsCompanion.insert(
              effectiveFrom: d,
              calorieTarget: kcal,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await insert(DateTime(2026, 9, 1), 1650);
      await expectLater(
        insert(DateTime(2026, 9, 1), 1700),
        throwsA(isA<SqliteException>()),
      );
    });

    test('取生效日在查詢日之前的最新一筆', () async {
      for (final e in [
        (DateTime(2026, 8, 1), 1800),
        (DateTime(2026, 9, 1), 1650),
        (DateTime(2026, 10, 1), 1500),
      ]) {
        await db
            .into(db.dailyNutritionTargets)
            .insert(
              DailyNutritionTargetsCompanion.insert(
                effectiveFrom: e.$1,
                calorieTarget: e.$2,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final q = db.select(db.dailyNutritionTargets)
        ..where((t) => t.effectiveFrom.isSmallerOrEqualValue(DateTime(2026, 9, 17)))
        ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
        ..limit(1);

      expect((await q.getSingle()).calorieTarget, 1650);
    });

    test('isManualOverride 預設為 false', () async {
      await db
          .into(db.dailyNutritionTargets)
          .insert(
            DailyNutritionTargetsCompanion.insert(
              effectiveFrom: DateTime(2026, 9, 1),
              calorieTarget: 1650,
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(
        (await db.select(db.dailyNutritionTargets).getSingle()).isManualOverride,
        isFalse,
      );
    });
  });

  group('FoodItems 與 FoodEntries', () {
    test('可以寫入食物並建立紀錄', () async {
      final foodId = await insertRice();
      await db
          .into(db.foodEntries)
          .insert(
            FoodEntriesCompanion.insert(
              date: DateTime(2026, 9, 17),
              mealType: MealType.lunch,
              foodItemId: Value(foodId),
              displayName: '白飯',
              quantity: 180,
              unit: ServingUnit.g,
              grams: 180,
              calories: 234,
              protein: 4.9,
              carbs: 50.4,
              fat: 0.5,
              sugar: const Value(0.2),
              sodium: const Value(1.8),
              nutritionSource: NutritionSource.database,
              createdAt: now,
            ),
          );

      final e = await db.select(db.foodEntries).getSingle();
      expect(e.displayName, '白飯');
      expect(e.mealType, MealType.lunch);
      expect(e.unit, ServingUnit.g);
      expect(e.grams, 180);
      expect(e.calories, 234);
      expect(e.nutritionSource, NutritionSource.database);
      // fiber 沒填 → null，不是 0
      expect(e.fiber, isNull);
    });

    test('食物字典更新後，既有紀錄的營養快照不變', () async {
      final foodId = await insertRice();
      await db
          .into(db.foodEntries)
          .insert(
            FoodEntriesCompanion.insert(
              date: DateTime(2026, 9, 17),
              mealType: MealType.lunch,
              foodItemId: Value(foodId),
              displayName: '白飯',
              quantity: 180,
              unit: ServingUnit.g,
              grams: 180,
              calories: 234,
              protein: 4.9,
              carbs: 50.4,
              fat: 0.5,
              nutritionSource: NutritionSource.database,
              createdAt: now,
            ),
          );

      // 之後修正食物字典的熱量
      await (db.update(db.foodItems)..where((t) => t.id.equals(foodId))).write(
        const FoodItemsCompanion(calories: Value(168)),
      );

      final e = await db.select(db.foodEntries).getSingle();
      expect(e.calories, 234, reason: '歷史紀錄不得隨字典更新而變動');
      expect((await db.select(db.foodItems).getSingle()).calories, 168);
    });

    test('刪除食物字典項目時，紀錄保留但 foodItemId 變 null', () async {
      final foodId = await insertRice();
      await db
          .into(db.foodEntries)
          .insert(
            FoodEntriesCompanion.insert(
              date: DateTime(2026, 9, 17),
              mealType: MealType.dinner,
              foodItemId: Value(foodId),
              displayName: '白飯',
              quantity: 1,
              unit: ServingUnit.serving,
              grams: 200,
              calories: 260,
              protein: 5.4,
              carbs: 56,
              fat: 0.6,
              nutritionSource: NutritionSource.database,
              createdAt: now,
            ),
          );

      await (db.delete(db.foodItems)..where((t) => t.id.equals(foodId))).go();

      final e = await db.select(db.foodEntries).getSingle();
      expect(e.foodItemId, isNull);
      expect(e.displayName, '白飯', reason: '名稱快照讓紀錄仍可讀');
      expect(e.calories, 260);
    });

    test('AI 一次性估算的紀錄可以沒有 foodItemId', () async {
      await db
          .into(db.foodEntries)
          .insert(
            FoodEntriesCompanion.insert(
              date: DateTime(2026, 9, 17),
              mealType: MealType.snack,
              displayName: '滷蛋',
              quantity: 1,
              unit: ServingUnit.serving,
              grams: 55,
              calories: 80,
              protein: 6.5,
              carbs: 1.2,
              fat: 5.5,
              nutritionSource: NutritionSource.aiEstimated,
              createdAt: now,
            ),
          );

      final e = await db.select(db.foodEntries).getSingle();
      expect(e.foodItemId, isNull);
      expect(e.nutritionSource, NutritionSource.aiEstimated);
    });
  });

  group('migration v1 → v2', () {
    test('升級後保留既有 UserProfile 資料，並建出新表', () async {
      final legacy = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(_v1UserProfilesDdl);
            raw.execute('PRAGMA user_version = 1');
            raw.execute(
              'INSERT INTO user_profiles '
              '(biological_sex, birth_date, height_cm, activity_level, '
              ' goal_type, target_weight_kg, created_at, updated_at) '
              "VALUES ('male', 642124800, 175.0, 'moderate', 'maintain', "
              ' 70.0, 1758000000, 1758000000)',
            );
          },
        ),
      );
      addTearDown(legacy.close);

      // 第一次查詢才會觸發 migration
      final profile = await legacy.select(legacy.userProfiles).getSingle();
      expect(profile.heightCm, 175.0);
      expect(profile.biologicalSex, BiologicalSex.male);
      expect(profile.goalType, GoalType.maintain);
      expect(profile.targetWeightKg, 70.0);

      // v2 新增的四張表都能用
      expect(await legacy.select(legacy.bodyMeasurements).get(), isEmpty);
      expect(await legacy.select(legacy.dailyNutritionTargets).get(), isEmpty);
      expect(await legacy.select(legacy.foodItems).get(), isEmpty);
      expect(await legacy.select(legacy.foodEntries).get(), isEmpty);

      final version = await legacy
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.first, 2);
    });
  });
}
