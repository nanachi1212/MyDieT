import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/profile/data/profile_repository.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  final birth = DateTime(1990, 5, 20);

  setUp(() {
    db = memoryDb();
    repo = ProfileRepository(db);
  });

  Future<void> saveDefault({
    BiologicalSex sex = BiologicalSex.female,
    GoalType goal = GoalType.lose,
    ActivityLevel activity = ActivityLevel.moderate,
    int? override,
  }) => repo.saveProfile(
    biologicalSex: sex,
    birthDate: birth,
    heightCm: 162.5,
    activityLevel: activity,
    goalType: goal,
    targetWeightKg: 52,
    manualCalorieOverride: override,
  );

  test('一開始沒有 Profile', () async {
    expect(await repo.getProfile(), isNull);
  });

  test('儲存後讀得回來', () async {
    await saveDefault();
    final p = await repo.getProfile();

    expect(p, isNotNull);
    expect(p!.id, ProfileRepository.profileId);
    expect(p.biologicalSex, BiologicalSex.female);
    expect(p.heightCm, 162.5);
    expect(p.goalType, GoalType.lose);
    expect(p.manualCalorieOverride, isNull);
  });

  test('重複儲存是覆蓋，不會變成兩筆', () async {
    await saveDefault();
    await saveDefault(sex: BiologicalSex.male, goal: GoalType.gain);

    final all = await db.select(db.userProfiles).get();
    expect(all, hasLength(1));
    expect(all.single.biologicalSex, BiologicalSex.male);
    expect(all.single.goalType, GoalType.gain);
  });

  test('覆蓋時保留原本的 createdAt', () async {
    final t1 = DateTime(2026, 1, 1);
    final t2 = DateTime(2026, 6, 1);

    await repo.saveProfile(
      biologicalSex: BiologicalSex.female,
      birthDate: birth,
      heightCm: 160,
      activityLevel: ActivityLevel.light,
      goalType: GoalType.maintain,
      now: t1,
    );
    await repo.saveProfile(
      biologicalSex: BiologicalSex.female,
      birthDate: birth,
      heightCm: 161,
      activityLevel: ActivityLevel.light,
      goalType: GoalType.maintain,
      now: t2,
    );

    final p = await repo.getProfile();
    expect(p!.createdAt, t1);
    expect(p.updatedAt, t2);
  });

  test('manualCalorieOverride 可以存與清除', () async {
    await saveDefault(override: 1450);
    expect((await repo.getProfile())!.manualCalorieOverride, 1450);

    await saveDefault();
    expect((await repo.getProfile())!.manualCalorieOverride, isNull);
  });

  group('體重紀錄', () {
    test('沒有紀錄時 latestMeasurement 回 null', () async {
      expect(await repo.latestMeasurement(), isNull);
    });

    test('取最新一筆', () async {
      await repo.addMeasurement(weightKg: 60, measuredAt: DateTime(2026, 9, 1));
      await repo.addMeasurement(
        weightKg: 58.5,
        measuredAt: DateTime(2026, 9, 15),
      );
      await repo.addMeasurement(
        weightKg: 59,
        measuredAt: DateTime(2026, 9, 10),
      );

      final latest = await repo.latestMeasurement();
      expect(latest!.weightKg, 58.5);
      expect(latest.source, MeasurementSource.manual);
    });

    test('體脂未填時是 null，不是 0', () async {
      await repo.addMeasurement(weightKg: 60);
      expect((await repo.latestMeasurement())!.bodyFatPercent, isNull);
    });
  });

  group('每日熱量目標', () {
    test('同一天重複設定是覆蓋', () async {
      final day = DateTime(2026, 9, 17);
      await repo.setDailyTarget(effectiveFrom: day, calorieTarget: 1650);
      await repo.setDailyTarget(
        effectiveFrom: day,
        calorieTarget: 1500,
        isManualOverride: true,
      );

      final all = await db.select(db.dailyNutritionTargets).get();
      expect(all, hasLength(1));
      expect(all.single.calorieTarget, 1500);
      expect(all.single.isManualOverride, isTrue);
    });

    test('時間帶進來會被歸零到當天', () async {
      await repo.setDailyTarget(
        effectiveFrom: DateTime(2026, 9, 17, 23, 45),
        calorieTarget: 1650,
      );
      expect(
        (await db.select(db.dailyNutritionTargets).getSingle()).effectiveFrom,
        DateTime(2026, 9, 17),
      );
    });

    test('targetFor 取生效日在該日之前的最新一筆', () async {
      await repo.setDailyTarget(
        effectiveFrom: DateTime(2026, 8, 1),
        calorieTarget: 1800,
      );
      await repo.setDailyTarget(
        effectiveFrom: DateTime(2026, 9, 1),
        calorieTarget: 1650,
      );
      await repo.setDailyTarget(
        effectiveFrom: DateTime(2026, 10, 1),
        calorieTarget: 1500,
      );

      expect(
        (await repo.targetFor(DateTime(2026, 9, 17)))!.calorieTarget,
        1650,
      );
      expect((await repo.targetFor(DateTime(2026, 8, 5)))!.calorieTarget, 1800);
      expect(
        (await repo.targetFor(DateTime(2026, 10, 9)))!.calorieTarget,
        1500,
      );
      // 早於所有生效日 → 沒有適用目標
      expect(await repo.targetFor(DateTime(2026, 7, 1)), isNull);
    });
  });

  group('computeSuggestedCalories', () {
    test('缺 Profile 或體重時回 null', () async {
      expect(await repo.computeSuggestedCalories(), isNull);

      await saveDefault();
      expect(await repo.computeSuggestedCalories(), isNull);
    });

    test('有資料時算得出建議熱量', () async {
      await saveDefault(goal: GoalType.maintain);
      await repo.addMeasurement(weightKg: 58);

      final kcal = await repo.computeSuggestedCalories(
        now: DateTime(2026, 9, 17),
      );
      expect(kcal, isNotNull);
      expect(kcal, greaterThan(1000));
      expect(kcal, lessThan(3000));
    });

    test('男女在相同條件下結果不同', () async {
      await saveDefault(sex: BiologicalSex.female, goal: GoalType.maintain);
      await repo.addMeasurement(weightKg: 58);
      final female = await repo.computeSuggestedCalories(
        now: DateTime(2026, 9, 17),
      );

      await saveDefault(sex: BiologicalSex.male, goal: GoalType.maintain);
      final male = await repo.computeSuggestedCalories(
        now: DateTime(2026, 9, 17),
      );

      expect(male, greaterThan(female!));
    });
  });
}
