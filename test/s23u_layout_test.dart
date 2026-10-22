import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/app.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/diary/presentation/add_food_page.dart';
import 'package:mydiet/features/diary/presentation/custom_food_page.dart';
import 'package:mydiet/features/profile/data/profile_repository.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';
import 'package:mydiet/features/profile/presentation/profile_page.dart';

import 'helpers/test_app.dart';

/// Galaxy S23 Ultra 預設 FHD+（1080x2316, dpr 2.8125）= 384x823 dp，
/// 字級調大到 1.3。任何 RenderFlex overflow 都會讓測試失敗。
void s23uTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 2.8125;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await body(tester);
    await disposeTree(tester);
  });
}

/// 輸入框內部也有 Scrollable，第一個才是頁面本身的 ListView。
Future<void> scrollTo(WidgetTester tester, Finder f) => tester
    .scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());

  Future<void> seedProfile() async {
    final repo = ProfileRepository(db);
    await repo.saveProfile(
      biologicalSex: BiologicalSex.female,
      birthDate: DateTime(1990, 5, 20),
      heightCm: 162,
      activityLevel: ActivityLevel.veryActive,
      goalType: GoalType.lose,
    );
    await repo.addMeasurement(weightKg: 58);
  }

  s23uTest('Onboarding 填完並顯示計算結果', (tester) async {
    await tester.pumpWidget(wrapForTest(const MyDietApp(), db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('height_field')), '162.5');
    await tester.enterText(find.byKey(const Key('weight_field')), '58.3');
    await tester.tap(find.text('出生日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    final calc = find.byKey(const Key('calculate_button'));
    await scrollTo(tester, calc);
    await tester.tap(calc);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('save_profile_button')));
    expect(find.textContaining('每日總消耗 TDEE'), findsOneWidget);
  });

  s23uTest('新增食物：搜尋結果與份量面板', (tester) async {
    await tester.pumpWidget(wrapForTest(const MyDietApp(), db));
    await tester.pumpAndSettle(); // 觸發種子資料匯入

    await tester.pumpWidget(
      wrapForTest(const AddFoodPage(initialMeal: MealType.snack), db),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food_search_field')), '便當');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm_entry_button')), findsOneWidget);
  });

  s23uTest('建立自訂食物', (tester) async {
    await tester.pumpWidget(wrapForTest(const CustomFoodPage(), db));
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('custom_save_button'));
    await scrollTo(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('必填'), findsWidgets);
  });

  s23uTest('我的', (tester) async {
    await seedProfile();
    await tester.pumpWidget(wrapForTest(const ProfilePage(), db));
    await tester.pumpAndSettle();
    expect(find.text('目前狀態'), findsOneWidget);
  });
}
