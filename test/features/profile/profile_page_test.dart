import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/features/profile/data/profile_repository.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';
import 'package:mydiet/features/profile/presentation/profile_page.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = memoryDb();
    repo = ProfileRepository(db);
  });

  Future<void> seedProfile({int? override}) async {
    await repo.saveProfile(
      biologicalSex: BiologicalSex.female,
      birthDate: DateTime(1990, 5, 20),
      heightCm: 162,
      activityLevel: ActivityLevel.moderate,
      goalType: GoalType.maintain,
      targetWeightKg: 55,
      manualCalorieOverride: override,
    );
    await repo.addMeasurement(weightKg: 58);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(wrapForTest(const ProfilePage(), db));
    await tester.pumpAndSettle();
  }

  widgetTestWithTree('顯示現有資料與 BMI', (tester) async {
    await seedProfile();
    await pumpPage(tester);

    expect(find.text('目前狀態'), findsOneWidget);
    // 58 / 1.62^2 = 22.1
    expect(find.textContaining('BMI 22.1'), findsOneWidget);
    expect(find.text('每日目標：依建議值自動計算'), findsOneWidget);
  });

  widgetTestWithTree('有手動目標時會標示出來', (tester) async {
    await seedProfile(override: 1400);
    await pumpPage(tester);

    expect(find.text('每日目標：1400 大卡（手動設定）'), findsOneWidget);
  });

  widgetTestWithTree('改體重會新增一筆體重紀錄並更新目標', (tester) async {
    await seedProfile();
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('profile_weight_field')), '56');
    await tester.tap(find.byKey(const Key('profile_save_button')));
    await tester.pumpAndSettle();

    expect((await repo.latestMeasurement())!.weightKg, 56);
    expect(await db.select(db.bodyMeasurements).get(), hasLength(2));

    final target = await repo.targetFor(DateTime.now());
    expect(target, isNotNull);
    expect(target!.isManualOverride, isFalse);
  });

  widgetTestWithTree('表單驗證擋下不合理的身高', (tester) async {
    await seedProfile();
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('profile_height_field')), '5');
    await tester.tap(find.byKey(const Key('profile_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('身高請輸入 50 到 300 公分之間'), findsOneWidget);
    // 沒有寫入新的體重紀錄
    expect(await db.select(db.bodyMeasurements).get(), hasLength(1));
  });

  group('手動目標保護', () {
    widgetTestWithTree('建議值改變時會詢問，不默默覆蓋', (tester) async {
      await seedProfile(override: 1400);
      await pumpPage(tester);

      // 改體重 → 建議值跟著變
      await tester.enterText(
        find.byKey(const Key('profile_weight_field')),
        '70',
      );
      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('要更新熱量目標嗎？'), findsOneWidget);
      expect(find.byKey(const Key('keep_override_button')), findsOneWidget);
      expect(find.byKey(const Key('use_suggested_button')), findsOneWidget);
    });

    widgetTestWithTree('選擇保留 → 手動目標不變', (tester) async {
      await seedProfile(override: 1400);
      await pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('profile_weight_field')),
        '70',
      );
      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('keep_override_button')));
      await tester.pumpAndSettle();

      expect((await repo.getProfile())!.manualCalorieOverride, 1400);
      final target = await repo.targetFor(DateTime.now());
      expect(target!.calorieTarget, 1400);
      expect(target.isManualOverride, isTrue);
    });

    widgetTestWithTree('選擇改用建議值 → 清掉手動目標', (tester) async {
      await seedProfile(override: 1400);
      await pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('profile_weight_field')),
        '70',
      );
      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('use_suggested_button')));
      await tester.pumpAndSettle();

      expect((await repo.getProfile())!.manualCalorieOverride, isNull);
      final target = await repo.targetFor(DateTime.now());
      expect(target!.isManualOverride, isFalse);
      expect(target.calorieTarget, isNot(1400));
    });

    widgetTestWithTree('取消 → 什麼都不改', (tester) async {
      await seedProfile(override: 1400);
      await pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('profile_weight_field')),
        '70',
      );
      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect((await repo.getProfile())!.manualCalorieOverride, 1400);
      expect((await repo.latestMeasurement())!.weightKg, 58);
      expect(await repo.targetFor(DateTime.now()), isNull);
    });

    widgetTestWithTree('沒有手動目標時直接儲存，不跳對話框', (tester) async {
      await seedProfile();
      await pumpPage(tester);

      await tester.enterText(
        find.byKey(const Key('profile_weight_field')),
        '70',
      );
      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('要更新熱量目標嗎？'), findsNothing);
      expect(await repo.targetFor(DateTime.now()), isNotNull);
    });
  });
}
