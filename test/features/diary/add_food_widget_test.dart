import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/nutrition/nutrition_facts.dart';
import 'package:mydiet/core/nutrition/serving_unit.dart';
import 'package:mydiet/features/diary/data/diary_repository.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/diary/presentation/add_food_page.dart';
import 'package:mydiet/features/foods/data/food_repository.dart';

import '../../helpers/test_app.dart';

/// 搜尋框裡也會有同樣的文字，所以固定用 ListTile 來定位食物項目。
Finder findFoodTile(String name) => find.widgetWithText(ListTile, name);

void main() {
  late AppDatabase db;
  late FoodRepository foods;
  late DiaryRepository diary;

  final today = DateTime(2026, 9, 17);

  setUp(() {
    db = memoryDb();
    foods = FoodRepository(db);
    diary = DiaryRepository(db);
  });

  Future<FoodItem> addRice() => foods.createCustom(
    name: '白飯',
    category: FoodCategory.grains,
    per100g: const NutritionFacts(
      calories: 130,
      protein: 2.7,
      carbs: 28,
      fat: 0.3,
      sugar: 0.1,
      sodium: 1,
    ),
    defaultServingGrams: 200,
    defaultServingLabel: '碗',
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    MealType meal = MealType.lunch,
  }) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapForTest(AddFoodPage(initialMeal: meal, date: today), db),
    );
    await tester.pumpAndSettle();
  }

  Future<void> searchFor(WidgetTester tester, String q) async {
    await tester.enterText(find.byKey(const Key('food_search_field')), q);
    await tester.pumpAndSettle();
  }

  testWidgets('四種餐別都能選', (tester) async {
    await pumpPage(tester);
    for (final label in ['早餐', '午餐', '晚餐', '點心']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('沒有紀錄時顯示空狀態', (tester) async {
    await pumpPage(tester);
    expect(find.text('還沒有記錄過任何食物，先搜尋看看'), findsOneWidget);
  });

  testWidgets('搜尋得到食物，搜尋不到顯示提示', (tester) async {
    await addRice();
    await pumpPage(tester);

    await searchFor(tester, '白飯');
    expect(findFoodTile('白飯'), findsOneWidget);
    expect(find.text('130 大卡 / 100 公克'), findsOneWidget);

    await searchFor(tester, '不存在的東西');
    expect(find.text('找不到符合的食物'), findsOneWidget);
  });

  testWidgets('預設以「份」輸入，顯示 1 碗的營養', (tester) async {
    await addRice();
    await pumpPage(tester);
    await searchFor(tester, '白飯');

    await tester.tap(findFoodTile('白飯'));
    await tester.pumpAndSettle();

    // 1 碗 = 200g = 260 kcal
    expect(find.byKey(const Key('preview_calories')), findsOneWidget);
    expect(find.text('260 大卡'), findsOneWidget);
    expect(find.text('共 200 公克'), findsOneWidget);
    expect(find.text('1 碗 = 200 公克'), findsOneWidget);
  });

  testWidgets('改份量即時重算', (tester) async {
    await addRice();
    await pumpPage(tester);
    await searchFor(tester, '白飯');
    await tester.tap(findFoodTile('白飯'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantity_field')), '0.5');
    await tester.pumpAndSettle();

    expect(find.text('130 大卡'), findsOneWidget);
    expect(find.text('共 100 公克'), findsOneWidget);
  });

  testWidgets('份量無效時擋下確認', (tester) async {
    await addRice();
    await pumpPage(tester);
    await searchFor(tester, '白飯');
    await tester.tap(findFoodTile('白飯'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantity_field')), '-5');
    await tester.pumpAndSettle();

    expect(find.text('請輸入 0 以上的數字'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('confirm_entry_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('確認後寫入 FoodEntry，含營養快照', (tester) async {
    await addRice();
    await pumpPage(tester, meal: MealType.dinner);
    await searchFor(tester, '白飯');
    await tester.tap(findFoodTile('白飯'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_entry_button')));
    await tester.pumpAndSettle();

    final entries = await diary.entriesForDay(today);
    expect(entries, hasLength(1));

    final e = entries.single;
    expect(e.displayName, '白飯');
    expect(e.mealType, MealType.dinner);
    expect(e.grams, 200);
    expect(e.calories, 260);
    expect(e.protein, 5.4);
    expect(e.carbs, 56);
    expect(e.nutritionSource, NutritionSource.database);
    // fiber 沒有資料 → null，不是 0
    expect(e.fiber, isNull);
  });

  testWidgets('以公克輸入 180g', (tester) async {
    await addRice();
    await pumpPage(tester);
    await searchFor(tester, '白飯');
    await tester.tap(findFoodTile('白飯'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('unit_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('公克').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quantity_field')), '180');
    await tester.pumpAndSettle();
    expect(find.text('234 大卡'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_entry_button')));
    await tester.pumpAndSettle();

    final e = (await diary.entriesForDay(today)).single;
    expect(e.grams, 180);
    expect(e.calories, 234);
  });

  testWidgets('沒有 default serving 的食物不顯示「份」選項', (tester) async {
    await foods.createCustom(
      name: '雞胸肉',
      category: FoodCategory.protein,
      per100g: const NutritionFacts(
        calories: 104,
        protein: 22.4,
        carbs: 0,
        fat: 1.2,
      ),
    );
    await pumpPage(tester);
    await searchFor(tester, '雞胸肉');
    await tester.tap(findFoodTile('雞胸肉'));
    await tester.pumpAndSettle();

    // 預設變成公克，100g
    expect(find.text('104 大卡'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unit_dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('份'), findsNothing);
  });

  testWidgets('估算的複合餐點會顯示提示', (tester) async {
    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            name: '牛肉麵',
            category: FoodCategory.other,
            calories: 75,
            protein: 5,
            carbs: 8.5,
            fat: 2.5,
            source: FoodSource.taiwanSeedEstimated,
            createdAt: today,
            updatedAt: today,
          ),
        );

    await pumpPage(tester);
    await searchFor(tester, '牛肉麵');
    expect(find.text('估算'), findsOneWidget);

    await tester.tap(findFoodTile('牛肉麵'));
    await tester.pumpAndSettle();
    expect(find.text('複合餐點，營養為估算值，實際依店家而異'), findsOneWidget);
  });

  testWidgets('建立自訂食物後可直接記錄', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('create_custom_food_button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('custom_name_field')), '媽媽的滷肉');
    await tester.enterText(
      find.byKey(const Key('custom_calories_field')),
      '250',
    );
    await tester.enterText(find.byKey(const Key('custom_protein_field')), '15');
    await tester.enterText(find.byKey(const Key('custom_carbs_field')), '2');
    await tester.enterText(find.byKey(const Key('custom_fat_field')), '20');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('custom_save_button')));
    await tester.pumpAndSettle();

    // 建立完直接進份量輸入
    expect(find.byKey(const Key('quantity_field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('quantity_field')), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_entry_button')));
    await tester.pumpAndSettle();

    final saved = await foods.search('滷肉');
    expect(saved, hasLength(1));
    expect(saved.single.source, FoodSource.userCustom);
    // 選填欄位留空 → null
    expect(saved.single.sugar, isNull);

    final e = (await diary.entriesForDay(today)).single;
    expect(e.displayName, '媽媽的滷肉');
    expect(e.calories, 250);
  });

  testWidgets('自訂食物必填欄位沒填 → 擋下來', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('create_custom_food_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('custom_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('請輸入食物名稱'), findsOneWidget);
    expect(find.text('必填'), findsWidgets);
    expect(await foods.search('a'), isEmpty);
  });

  testWidgets('記錄過的食物會出現在最近使用', (tester) async {
    final rice = await addRice();
    await diary.addEntry(
      date: today,
      mealType: MealType.lunch,
      displayName: rice.name,
      quantity: 100,
      unit: ServingUnit.g,
      grams: 100,
      facts: rice.per100g,
      foodItemId: rice.id,
    );

    await pumpPage(tester);
    expect(find.text('最近使用'), findsOneWidget);
    expect(findFoodTile('白飯'), findsOneWidget);
  });
}
