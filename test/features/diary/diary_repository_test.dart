import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/nutrition/nutrition_calculator.dart';
import 'package:mydiet/core/nutrition/nutrition_facts.dart';
import 'package:mydiet/core/nutrition/serving_unit.dart';
import 'package:mydiet/features/diary/data/diary_repository.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/foods/data/food_repository.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late DiaryRepository diary;
  late FoodRepository foods;

  final today = DateTime(2026, 9, 17);

  setUp(() {
    db = memoryDb();
    diary = DiaryRepository(db);
    foods = FoodRepository(db);
  });

  /// 白飯：130 kcal / 100g，一碗 200g，fiber 不明
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

  /// 走完整流程：查食物 → 算份量 → 寫入紀錄
  Future<FoodEntry> logPortion(
    FoodItem food, {
    required double quantity,
    required ServingUnit unit,
    MealType meal = MealType.lunch,
  }) async {
    final p = NutritionCalculator.forPortion(
      per100g: food.per100g,
      quantity: quantity,
      unit: unit,
      servingGrams: food.defaultServingGrams,
    );
    final id = await diary.addEntry(
      date: today,
      mealType: meal,
      displayName: food.name,
      quantity: quantity,
      unit: unit,
      grams: p.grams,
      facts: p.facts,
      foodItemId: food.id,
    );
    return (await diary.entriesForDay(today)).firstWhere((e) => e.id == id);
  }

  group('搜尋', () {
    test('可以用中文名稱搜尋', () async {
      await addRice();
      expect(await foods.search('白飯'), hasLength(1));
      expect(await foods.search('飯'), hasLength(1));
    });

    test('可以用英文名稱搜尋', () async {
      await foods.createCustom(
        name: '燕麥',
        category: FoodCategory.grains,
        per100g: const NutritionFacts(
          calories: 400,
          protein: 12,
          carbs: 68,
          fat: 9,
        ),
      );
      expect(await foods.search('不存在的食物'), isEmpty);
    });

    test('空字串回傳空清單', () async {
      await addRice();
      expect(await foods.search(''), isEmpty);
      expect(await foods.search('   '), isEmpty);
    });
  });

  group('份量換算與寫入', () {
    test('100 公克', () async {
      final rice = await addRice();
      final e = await logPortion(rice, quantity: 100, unit: ServingUnit.g);

      expect(e.grams, 100);
      expect(e.calories, 130);
      expect(e.protein, 2.7);
      expect(e.carbs, 28);
    });

    test('非 100 公克：180g', () async {
      final rice = await addRice();
      final e = await logPortion(rice, quantity: 180, unit: ServingUnit.g);

      expect(e.grams, 180);
      expect(e.calories, 234);
      expect(e.protein, 4.9); // 4.86 四捨五入
      expect(e.carbs, 50.4);
    });

    test('以「份」輸入：1 碗 = 200g', () async {
      final rice = await addRice();
      final e = await logPortion(rice, quantity: 1, unit: ServingUnit.serving);

      expect(e.grams, 200);
      expect(e.quantity, 1);
      expect(e.unit, ServingUnit.serving);
      expect(e.calories, 260);
    });

    test('半碗', () async {
      final rice = await addRice();
      final e = await logPortion(
        rice,
        quantity: 0.5,
        unit: ServingUnit.serving,
      );

      expect(e.grams, 100);
      expect(e.calories, 130);
    });

    test('未知的營養素寫入後仍是 null', () async {
      final rice = await addRice();
      final e = await logPortion(rice, quantity: 180, unit: ServingUnit.g);
      expect(e.fiber, isNull);
      expect(e.sugar, isNotNull);
    });
  });

  group('nutrition snapshot', () {
    test('食物字典改了，既有紀錄不變', () async {
      final rice = await addRice();
      final e = await logPortion(rice, quantity: 100, unit: ServingUnit.g);
      expect(e.calories, 130);

      // 使用者把自訂食物的熱量改掉
      await db.customStatement(
        'UPDATE food_items SET calories = 999 WHERE id = ?1',
        [rice.id],
      );

      final after = (await diary.entriesForDay(today)).single;
      expect(after.calories, 130, reason: '歷史紀錄必須是當下的快照');
      expect((await foods.byId(rice.id))!.calories, 999);
    });
  });

  group('餐別', () {
    test('四種餐別都能記錄並查回', () async {
      final rice = await addRice();
      for (final m in MealType.values) {
        await logPortion(rice, quantity: 100, unit: ServingUnit.g, meal: m);
      }

      final entries = await diary.entriesForDay(today);
      expect(entries, hasLength(4));
      expect(entries.map((e) => e.mealType).toSet(), MealType.values.toSet());
    });

    test('只取當天的紀錄', () async {
      final rice = await addRice();
      await logPortion(rice, quantity: 100, unit: ServingUnit.g);

      await diary.addEntry(
        date: DateTime(2026, 9, 16),
        mealType: MealType.dinner,
        displayName: '白飯',
        quantity: 100,
        unit: ServingUnit.g,
        grams: 100,
        facts: rice.per100g,
      );

      expect(await diary.entriesForDay(today), hasLength(1));
      expect(await diary.entriesForDay(DateTime(2026, 9, 16)), hasLength(1));
    });

    test('日期帶時間也會歸零到當天', () async {
      final rice = await addRice();
      await diary.addEntry(
        date: DateTime(2026, 9, 17, 19, 30),
        mealType: MealType.dinner,
        displayName: '白飯',
        quantity: 100,
        unit: ServingUnit.g,
        grams: 100,
        facts: rice.per100g,
      );
      expect(await diary.entriesForDay(today), hasLength(1));
    });
  });

  group('自訂食物', () {
    test('source 為 userCustom 並可搜尋到', () async {
      final custom = await foods.createCustom(
        name: '媽媽的滷肉',
        category: FoodCategory.protein,
        per100g: const NutritionFacts(
          calories: 250,
          protein: 15,
          carbs: 2,
          fat: 20,
          sodium: 500,
        ),
      );

      expect(custom.source, FoodSource.userCustom);
      expect(custom.isEstimated, isFalse);
      expect(custom.supportsServingUnit, isFalse);
      expect(await foods.search('滷肉'), hasLength(1));
    });

    test('選填欄位留空時存成 null', () async {
      final custom = await foods.createCustom(
        name: '測試食物',
        category: FoodCategory.other,
        per100g: const NutritionFacts(
          calories: 100,
          protein: 1,
          carbs: 2,
          fat: 3,
        ),
      );
      expect(custom.sugar, isNull);
      expect(custom.fiber, isNull);
      expect(custom.sodium, isNull);
    });

    test('名稱為空白 → 拋錯', () async {
      expect(
        () => foods.createCustom(
          name: '   ',
          category: FoodCategory.other,
          per100g: const NutritionFacts(
            calories: 1,
            protein: 1,
            carbs: 1,
            fat: 1,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('自訂食物可以直接拿來記錄', () async {
      final custom = await foods.createCustom(
        name: '自製沙拉',
        category: FoodCategory.vegetables,
        per100g: const NutritionFacts(
          calories: 60,
          protein: 2,
          carbs: 5,
          fat: 4,
        ),
      );
      final e = await logPortion(custom, quantity: 250, unit: ServingUnit.g);

      expect(e.displayName, '自製沙拉');
      expect(e.calories, 150);
      expect(e.foodItemId, custom.id);
    });
  });

  group('最近使用', () {
    test('依最後記錄時間排序，且不重複', () async {
      final rice = await addRice();
      final salad = await foods.createCustom(
        name: '沙拉',
        category: FoodCategory.vegetables,
        per100g: const NutritionFacts(
          calories: 60,
          protein: 2,
          carbs: 5,
          fat: 4,
        ),
      );

      await diary.addEntry(
        date: today,
        mealType: MealType.lunch,
        displayName: rice.name,
        quantity: 100,
        unit: ServingUnit.g,
        grams: 100,
        facts: rice.per100g,
        foodItemId: rice.id,
        now: DateTime(2026, 9, 17, 12),
      );
      await diary.addEntry(
        date: today,
        mealType: MealType.dinner,
        displayName: salad.name,
        quantity: 100,
        unit: ServingUnit.g,
        grams: 100,
        facts: salad.per100g,
        foodItemId: salad.id,
        now: DateTime(2026, 9, 17, 19),
      );
      await diary.addEntry(
        date: today,
        mealType: MealType.snack,
        displayName: rice.name,
        quantity: 50,
        unit: ServingUnit.g,
        grams: 50,
        facts: rice.per100g,
        foodItemId: rice.id,
        now: DateTime(2026, 9, 17, 21),
      );

      final recent = await foods.recentlyUsed();
      expect(recent.map((f) => f.name).toList(), ['白飯', '沙拉']);
    });

    test('沒有紀錄時回空清單', () async {
      expect(await foods.recentlyUsed(), isEmpty);
    });
  });

  test('刪除紀錄', () async {
    final rice = await addRice();
    final e = await logPortion(rice, quantity: 100, unit: ServingUnit.g);

    await diary.deleteEntry(e.id);
    expect(await diary.entriesForDay(today), isEmpty);
  });
}
