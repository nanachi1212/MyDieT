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

  widgetTestWithTree('切換到前一天只看到那天的紀錄', (tester) async {
    final yesterday = today.subtract(const Duration(days: 1));
    await add(
      MealType.lunch,
      '今天的飯',
      const NutritionFacts(calories: 100, protein: 1, carbs: 1, fat: 1),
    );
    await diary.addEntry(
      date: yesterday,
      mealType: MealType.dinner,
      displayName: '昨天的麵',
      quantity: 100,
      unit: ServingUnit.g,
      grams: 100,
      facts: const NutritionFacts(calories: 400, protein: 1, carbs: 1, fat: 1),
    );

    await tester.pumpWidget(wrapForTest(const DashboardPage(), db));
    await tester.pumpAndSettle();
    expect(find.text('今日'), findsOneWidget);
    // 今天不能再往後
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);

    await tester.tap(find.byTooltip('前一天'));
    await tester.pumpAndSettle();
    expect(find.text('今日'), findsNothing);
    expect(find.text('昨天的麵'), findsOneWidget);
    expect(find.text('今天的飯'), findsNothing);

    await tester.tap(find.byTooltip('後一天'));
    await tester.pumpAndSettle();
    expect(find.text('今天的飯'), findsOneWidget);
  });

  widgetTestWithTree('點紀錄可以改份量', (tester) async {
    await add(
      MealType.lunch,
      '白飯',
      const NutritionFacts(calories: 260, protein: 5, carbs: 56, fat: 1),
    );
    await tester.pumpWidget(wrapForTest(const DashboardPage(), db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('白飯'));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget); // 帶入原本的份量
    await tester.enterText(find.byKey(const Key('quantity_field')), '50');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_entry_button')));
    await tester.pumpAndSettle();

    expect(find.text('130 大卡'), findsWidgets);
    final entry = (await diary.entriesForDay(today)).single;
    expect(entry.grams, 50);
    expect(entry.calories, 130);
  });

  widgetTestWithTree('刪除前會確認，確認後才刪', (tester) async {
    await add(
      MealType.snack,
      '餅乾',
      const NutritionFacts(calories: 200, protein: 2, carbs: 30, fat: 8),
    );
    await tester.pumpWidget(wrapForTest(const DashboardPage(), db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('餅乾'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_entry_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await diary.entriesForDay(today), hasLength(1));

    await tester.tap(find.byKey(const Key('delete_entry_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_button')));
    await tester.pumpAndSettle();
    expect(await diary.entriesForDay(today), isEmpty);
    expect(find.text('餅乾'), findsNothing);
  });
}
