import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/providers.dart';
import 'package:mydiet/features/profile/data/profile_repository.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';
import 'package:mydiet/features/profile/presentation/onboarding_page.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());

  /// 填完 Onboarding 表單（不含按下計算）
  Future<void> fillForm(
    WidgetTester tester, {
    required String sex,
    String height = '170',
    String weight = '70',
  }) async {
    await tester.tap(find.text(sex));
    await tester.pumpAndSettle();

    // 出生日期：用日期選擇器選當前預設值（約 30 歲）
    await tester.tap(find.text('出生日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('height_field')), height);
    await tester.enterText(find.byKey(const Key('weight_field')), weight);
    await tester.pumpAndSettle();
  }

  Future<void> pumpOnboarding(WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const OnboardingPage(), db));
    await tester.pumpAndSettle();
  }

  testWidgets('沒選出生日期就按計算 → 顯示提示，不顯示結果', (tester) async {
    await pumpOnboarding(tester);

    await tester.enterText(find.byKey(const Key('height_field')), '170');
    await tester.enterText(find.byKey(const Key('weight_field')), '70');
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pump();

    expect(find.text('請選擇出生日期'), findsOneWidget);
    expect(find.text('計算結果'), findsNothing);
  });

  testWidgets('身高體重不合理 → 顯示錯誤訊息', (tester) async {
    await pumpOnboarding(tester);
    await fillForm(tester, sex: '女性', height: '10', weight: '5');

    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();

    expect(find.text('身高請輸入 50 到 300 公分之間'), findsOneWidget);
    expect(find.text('體重請輸入 10 到 500 公斤之間'), findsOneWidget);
    expect(find.text('計算結果'), findsNothing);
  });

  testWidgets('男性：顯示 BMI / BMR / TDEE 與建議熱量', (tester) async {
    await pumpOnboarding(tester);
    await fillForm(tester, sex: '男性', height: '175', weight: '70');

    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();

    expect(find.text('計算結果'), findsOneWidget);
    expect(find.text('BMI'), findsOneWidget);
    expect(find.text('基礎代謝率 BMR'), findsOneWidget);
    expect(find.text('每日總消耗 TDEE'), findsOneWidget);
    expect(find.text('建議每日攝取'), findsOneWidget);
    expect(find.byKey(const Key('final_target_text')), findsOneWidget);
  });

  testWidgets('女性：同樣能算出結果，且與男性不同', (tester) async {
    await pumpOnboarding(tester);
    await fillForm(tester, sex: '女性', height: '175', weight: '70');
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();

    final femaleText = tester
        .widget<Text>(find.byKey(const Key('final_target_text')))
        .data!;

    await tester.tap(find.text('男性'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();

    final maleText = tester
        .widget<Text>(find.byKey(const Key('final_target_text')))
        .data!;

    expect(maleText, isNot(femaleText));
  });

  testWidgets('儲存後寫入 Profile、體重與每日目標', (tester) async {
    await pumpOnboarding(tester);
    await fillForm(tester, sex: '女性', height: '162', weight: '58');
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pumpAndSettle();

    final repo = ProfileRepository(db);
    final profile = await repo.getProfile();
    expect(profile, isNotNull);
    expect(profile!.biologicalSex, BiologicalSex.female);
    expect(profile.heightCm, 162);
    // 沒有調整目標 → 不算 override
    expect(profile.manualCalorieOverride, isNull);

    expect((await repo.latestMeasurement())!.weightKg, 58);

    final target = await repo.targetFor(DateTime.now());
    expect(target, isNotNull);
    expect(target!.isManualOverride, isFalse);
    expect(target.calorieTarget, greaterThan(0));
  });

  testWidgets('自行調整目標 → 存成 manualCalorieOverride', (tester) async {
    await pumpOnboarding(tester);
    await fillForm(tester, sex: '女性', height: '162', weight: '58');
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit_target_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_input')), '1400');
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.text('目前設定的目標：1400 大卡'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pumpAndSettle();

    final repo = ProfileRepository(db);
    expect((await repo.getProfile())!.manualCalorieOverride, 1400);

    final target = await repo.targetFor(DateTime.now());
    expect(target!.calorieTarget, 1400);
    expect(target.isManualOverride, isTrue);
  });

  testWidgets('自訂目標輸入不合理 → 擋下來', (tester) async {
    await pumpOnboarding(tester);
    await fillForm(tester, sex: '女性', height: '162', weight: '58');
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit_target_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target_input')), '50');
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.text('請輸入 500 到 10000 大卡之間'), findsOneWidget);
  });

  testWidgets('完成後 onboardingState 變成 true（下次不會再跑 Onboarding）', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const OnboardingPage(), db));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingPage)),
    );
    expect(container.read(onboardingStateProvider).value, isNull);

    await fillForm(tester, sex: '女性', height: '162', weight: '58');
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pumpAndSettle();

    expect(container.read(onboardingStateProvider).value, isTrue);

    // 重新啟動流程時，因為已經有 Profile，會判定為不需要 Onboarding
    final fresh = testContainer(db);
    await fresh.read(appStartupProvider.future);
    expect(fresh.read(onboardingStateProvider).value, isTrue);
  });

  testWidgets('全新安裝時 appStartup 判定需要 Onboarding', (tester) async {
    // 一定要先 pumpWidget：appStartup 會透過 rootBundle 讀取種子 CSV，
    // 在還沒建立 widget tree 的 container 上讀會一直等不到結果。
    await tester.pumpWidget(wrapForTest(const SizedBox.shrink(), db));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SizedBox)),
    );

    await container.read(appStartupProvider.future);
    expect(container.read(onboardingStateProvider).value, isFalse);
  });

  testWidgets('舊資料只有 Profile：帶入原本資料，只補體重，不會被預設值蓋掉', (tester) async {
    final repo = ProfileRepository(db);
    await repo.saveProfile(
      biologicalSex: BiologicalSex.male,
      birthDate: DateTime(1985, 3, 1),
      heightCm: 175.5,
      activityLevel: ActivityLevel.active,
      goalType: GoalType.gain,
      targetWeightKg: 72,
      manualCalorieOverride: 2600,
    );

    await pumpOnboarding(tester);
    expect(find.textContaining('已帶入你之前的資料'), findsOneWidget);
    expect(find.text('175.5'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('weight_field')), '68');
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle();
    expect(find.text('目前設定的目標：2600 大卡'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save_profile_button')));
    await tester.pumpAndSettle();

    final p = (await repo.getProfile())!;
    expect(p.biologicalSex, BiologicalSex.male);
    expect(p.birthDate, DateTime(1985, 3, 1));
    expect(p.heightCm, 175.5);
    expect(p.activityLevel, ActivityLevel.active);
    expect(p.goalType, GoalType.gain);
    expect(p.targetWeightKg, 72);
    expect(p.manualCalorieOverride, 2600);
    expect((await repo.latestMeasurement())!.weightKg, 68);
    final target = (await repo.targetFor(DateTime.now()))!;
    expect(target.calorieTarget, 2600);
    expect(target.isManualOverride, isTrue);
  });
}
