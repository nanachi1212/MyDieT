import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/app.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/features/profile/data/profile_repository.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';

import 'helpers/test_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDb());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(wrapForTest(const MyDietApp(), db));
    await tester.pumpAndSettle();
  }

  widgetTestWithTree('全新安裝時進入 Onboarding', (tester) async {
    await pumpApp(tester);

    expect(find.text('建立你的資料'), findsOneWidget);
    // Onboarding 階段不該出現主畫面的導覽列
    expect(find.byType(NavigationBar), findsNothing);
  });

  widgetTestWithTree('已有 Profile 時直接進主畫面，且可切換分頁', (tester) async {
    await ProfileRepository(db).saveProfile(
      biologicalSex: BiologicalSex.female,
      birthDate: DateTime(1990, 5, 20),
      heightCm: 162,
      activityLevel: ActivityLevel.moderate,
      goalType: GoalType.maintain,
    );
    await ProfileRepository(db).addMeasurement(weightKg: 58);

    await pumpApp(tester);

    expect(find.text('Dashboard placeholder'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_save_button')), findsOneWidget);

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('Settings placeholder'), findsOneWidget);
  });

  widgetTestWithTree('啟動時會匯入台灣食物種子資料', (tester) async {
    await ProfileRepository(db).saveProfile(
      biologicalSex: BiologicalSex.male,
      birthDate: DateTime(1990, 5, 20),
      heightCm: 175,
      activityLevel: ActivityLevel.light,
      goalType: GoalType.maintain,
    );
    await ProfileRepository(db).addMeasurement(weightKg: 70);

    await pumpApp(tester);

    final foods = await db.select(db.foodItems).get();
    expect(foods.length, greaterThanOrEqualTo(30));
    expect(foods.any((f) => f.name == '白飯'), isTrue);
  });
}
