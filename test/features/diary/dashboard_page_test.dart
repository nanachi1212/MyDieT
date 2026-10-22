import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/nutrition/nutrition_facts.dart';
import 'package:mydiet/core/nutrition/serving_unit.dart';
import 'package:mydiet/features/diary/data/diary_repository.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/diary/presentation/dashboard_page.dart';
import 'package:mydiet/features/profile/data/profile_repository.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late DiaryRepository diary;

  final today = DateTime.now();

  setUp(() {
    db = memoryDb();
    diary = DiaryRepository(db);
  });

  Future<void> add(MealType meal, String name, NutritionFacts facts) =>
      diary.addEntry(
        date: today,
        mealType: meal,
        displayName: name,
        quantity: 100,
        unit: ServingUnit.g,
        grams: 100,
        facts: facts,
      );

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  widgetTestWithTree('累計熱量、剩餘、各餐與營養素', (tester) async {
    await ProfileRepository(
      db,
    ).setDailyTarget(effectiveFrom: today, calorieTarget: 1800);
    await add(
      MealType.lunch,
      '白飯',
      const NutritionFacts(
        calories: 260,
        protein: 5.4,
        carbs: 56,
        fat: 0.6,
        sugar: 0.2,
      ),
    );
    await add(
      MealType.dinner,
      '雞腿',
      const NutritionFacts(calories: 300, protein: 25, carbs: 0, fat: 22),
    );

    await tester.pumpWidget(wrapForTest(const DashboardPage(), db));
    await tester.pumpAndSettle();

    // 1800 − (260 + 300) = 1240
    expect(textOf(tester, 'remaining_calories'), '1240');
    expect(textOf(tester, 'nutrient_蛋白質'), '30.4 g');
    expect(textOf(tester, 'nutrient_糖'), '0.2 g');
    // 兩筆都沒有鈉的資料 → 不知道，不是 0
    expect(textOf(tester, 'nutrient_鈉'), '—');

    final lunch = find.byKey(const Key('meal_lunch'));
    expect(find.descendant(of: lunch, matching: find.text('白飯')), findsOne);
    expect(
      find.descendant(of: lunch, matching: find.text('260 大卡')),
      findsWidgets,
    );
    final breakfast = find.byKey(const Key('meal_breakfast'));
    expect(
      find.descendant(of: breakfast, matching: find.text('0 大卡')),
      findsOne,
    );
  });

  widgetTestWithTree('超過目標時顯示超過的量', (tester) async {
    await ProfileRepository(
      db,
    ).setDailyTarget(effectiveFrom: today, calorieTarget: 500);
    await add(
      MealType.snack,
      '珍珠奶茶',
      const NutritionFacts(calories: 650, protein: 3, carbs: 110, fat: 20),
    );

    await tester.pumpWidget(wrapForTest(const DashboardPage(), db));
    await tester.pumpAndSettle();

    expect(find.text('超過'), findsOneWidget);
    expect(textOf(tester, 'remaining_calories'), '150');
  });
}
