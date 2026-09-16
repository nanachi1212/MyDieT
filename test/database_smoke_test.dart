// drift 也匯出 isNull，與 flutter_test 的 matcher 撞名。
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('寫入 UserProfile 後可以讀回相同資料', () async {
    final now = DateTime(2026, 9, 16, 12);
    final birth = DateTime(1990, 5, 20);

    final id = await db
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

  test('schemaVersion 為 1', () {
    expect(db.schemaVersion, 1);
  });
}
