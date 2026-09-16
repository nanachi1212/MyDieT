import 'package:drift/drift.dart';

import '../../features/profile/domain/profile_enums.dart';

/// 使用者 Profile。單列表，id 固定為 1。
///
/// P0 只建這一張表。其餘 table（BodyMeasurements / FoodItems /
/// FoodEntries / AppSettings）屬於 P1，不提前建立。
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
