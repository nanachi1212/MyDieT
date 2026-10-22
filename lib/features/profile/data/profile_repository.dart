import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../diary/domain/diary_enums.dart';
import '../domain/profile_enums.dart';

/// Profile / 體重紀錄 / 每日熱量目標的讀寫。
///
/// UserProfiles 是單列表，固定使用 id = 1。
class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  static const profileId = 1;

  Future<UserProfile?> getProfile() => (_db.select(
    _db.userProfiles,
  )..where((t) => t.id.equals(profileId))).getSingleOrNull();

  Stream<UserProfile?> watchProfile() => (_db.select(
    _db.userProfiles,
  )..where((t) => t.id.equals(profileId))).watchSingleOrNull();

  /// 新增或覆寫 Profile。[now] 只給測試用。
  Future<void> saveProfile({
    required BiologicalSex biologicalSex,
    required DateTime birthDate,
    required double heightCm,
    required ActivityLevel activityLevel,
    required GoalType goalType,
    double? targetWeightKg,
    int? manualCalorieOverride,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final existing = await getProfile();

    await _db
        .into(_db.userProfiles)
        .insertOnConflictUpdate(
          UserProfilesCompanion(
            id: const Value(profileId),
            biologicalSex: Value(biologicalSex),
            birthDate: Value(birthDate),
            heightCm: Value(heightCm),
            activityLevel: Value(activityLevel),
            goalType: Value(goalType),
            targetWeightKg: Value(targetWeightKg),
            manualCalorieOverride: Value(manualCalorieOverride),
            createdAt: Value(existing?.createdAt ?? ts),
            updatedAt: Value(ts),
          ),
        );
  }

  Future<void> addMeasurement({
    required double weightKg,
    double? bodyFatPercent,
    MeasurementSource source = MeasurementSource.manual,
    DateTime? measuredAt,
  }) async {
    final ts = measuredAt ?? DateTime.now();
    await _db
        .into(_db.bodyMeasurements)
        .insert(
          BodyMeasurementsCompanion.insert(
            measuredAt: ts,
            weightKg: weightKg,
            bodyFatPercent: Value(bodyFatPercent),
            source: source,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// 最新一筆體重紀錄。沒有紀錄時回 null。
  Future<BodyMeasurement?> latestMeasurement() =>
      (_db.select(_db.bodyMeasurements)
            ..orderBy([(t) => OrderingTerm.desc(t.measuredAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<BodyMeasurement?> watchLatestMeasurement() =>
      (_db.select(_db.bodyMeasurements)
            ..orderBy([(t) => OrderingTerm.desc(t.measuredAt)])
            ..limit(1))
          .watchSingleOrNull();

  /// 設定某個生效日起的每日熱量目標。同一天重複設定會覆蓋。
  Future<void> setDailyTarget({
    required DateTime effectiveFrom,
    required int calorieTarget,
    bool isManualOverride = false,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    final day = DateTime(
      effectiveFrom.year,
      effectiveFrom.month,
      effectiveFrom.day,
    );

    await _db
        .into(_db.dailyNutritionTargets)
        .insert(
          DailyNutritionTargetsCompanion.insert(
            effectiveFrom: day,
            calorieTarget: calorieTarget,
            isManualOverride: Value(isManualOverride),
            createdAt: ts,
            updatedAt: ts,
          ),
          onConflict: DoUpdate(
            (_) => DailyNutritionTargetsCompanion(
              calorieTarget: Value(calorieTarget),
              isManualOverride: Value(isManualOverride),
              updatedAt: Value(ts),
            ),
            target: [_db.dailyNutritionTargets.effectiveFrom],
          ),
        );
  }

  /// 查某一天適用的目標：生效日在該日（含）之前的最新一筆。
  Future<DailyNutritionTarget?> targetFor(DateTime date) =>
      _target(date).getSingleOrNull();

  Stream<DailyNutritionTarget?> watchTargetFor(DateTime date) =>
      _target(date).watchSingleOrNull();

  SimpleSelectStatement<$DailyNutritionTargetsTable, DailyNutritionTarget>
  _target(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _db.select(_db.dailyNutritionTargets)
      ..where((t) => t.effectiveFrom.isSmallerOrEqualValue(day))
      ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
      ..limit(1);
  }
}
