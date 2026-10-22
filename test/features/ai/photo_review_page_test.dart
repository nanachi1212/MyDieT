import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/nutrition/nutrition_facts.dart';
import 'package:mydiet/core/providers.dart';
import 'package:mydiet/core/secure/ai_config_store.dart';
import 'package:mydiet/features/ai/food_recognizer.dart';
import 'package:mydiet/features/ai/photo_review_page.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/foods/data/food_repository.dart';

import '../../helpers/test_app.dart';

class FakeRecognizer implements FoodRecognizer {
  FakeRecognizer(this.result);

  final List<RecognizedFood> result;
  List<String>? knownNames;

  @override
  Future<List<RecognizedFood>> recognize(
    Uint8List image, {
    List<String> knownNames = const [],
  }) async {
    this.knownNames = knownNames;
    return result;
  }

  @override
  Future<void> ping() async {}
}

void main() {
  late AppDatabase db;
  late FakeRecognizer fake;
  final today = DateTime(2026, 10, 22);
  final image = Uint8List.fromList([0xFF, 0xD8, 0xFF]);

  setUp(() async {
    db = memoryDb();
    FlutterSecureStorage.setMockInitialValues({
      'ai_provider': 'claude',
      'ai_key_claude': 'sk-ant-test',
    });
    await FoodRepository(db).createCustom(
      name: '白飯',
      category: FoodCategory.grains,
      per100g: const NutritionFacts(
        calories: 130,
        protein: 2.7,
        carbs: 28,
        fat: 0.3,
      ),
    );
    fake = FakeRecognizer([
      // AI 自己估 200 kcal/100g，但資料庫有白飯 → 應該用資料庫的 130
      const RecognizedFood(
        name: '白飯',
        grams: 180,
        per100g: NutritionFacts(calories: 200, protein: 3, carbs: 40, fat: 1),
      ),
      const RecognizedFood(
        name: '神秘醬料',
        grams: 30,
        per100g: NutritionFacts(calories: 300, protein: 1, carbs: 10, fat: 28),
      ),
    ]);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapForTest(
        PhotoReviewPage(image: image, meal: MealType.lunch, date: today),
        db,
        overrides: [
          foodRecognizerFactoryProvider.overrideWithValue((_) => fake),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  widgetTestWithTree('資料庫有的用資料庫營養，沒有的標 AI 估算；確認前不寫入', (tester) async {
    await pumpPage(tester);

    expect(fake.knownNames, contains('白飯'));
    expect(textOf(tester, 'photo_kcal_0'), '234 大卡'); // 130 × 1.8
    expect(textOf(tester, 'photo_kcal_1'), '90 大卡'); // 300 × 0.3
    expect(find.text('資料庫'), findsOneWidget);
    expect(find.text('AI 估算'), findsOneWidget);
    expect(await db.select(db.foodEntries).get(), isEmpty);

    await tester.enterText(find.byKey(const Key('photo_grams_1')), '10');
    await tester.enterText(find.byKey(const Key('photo_name_1')), '沙茶醬');
    await tester.pumpAndSettle();
    expect(textOf(tester, 'photo_kcal_1'), '30 大卡');

    await tester.tap(find.byKey(const Key('photo_confirm_button')));
    await tester.pumpAndSettle();

    final saved = await db.select(db.foodEntries).get();
    expect(saved, hasLength(2));
    final rice = saved.firstWhere((e) => e.displayName == '白飯');
    expect(rice.calories, 234);
    expect(rice.nutritionSource, NutritionSource.database);
    expect(rice.foodItemId, isNotNull);
    expect(rice.mealType, MealType.lunch);
    expect(rice.date, today);
    final sauce = saved.firstWhere((e) => e.displayName == '沙茶醬');
    expect(sauce.grams, 10);
    // 改過名且資料庫查不到：營養沿用 AI 對原本食物的估算，標成使用者修改過
    expect(sauce.nutritionSource, NutritionSource.userEdited);
    expect(sauce.foodItemId, isNull);
  });

  widgetTestWithTree('刪掉一項後只加入剩下的', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('photo_remove_1')));
    await tester.pumpAndSettle();
    expect(find.text('加入 1 項，共 234 大卡'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo_confirm_button')));
    await tester.pumpAndSettle();
    expect(await db.select(db.foodEntries).get(), hasLength(1));
  });

  widgetTestWithTree('份量無效時不能加入', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('photo_grams_0')), '0');
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('photo_confirm_button')),
    );
    expect(button.onPressed, isNull);
  });

  widgetTestWithTree('還沒設定 API key → 顯示說明，可改用手動輸入', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await pumpPage(tester);

    expect(textOf(tester, 'photo_error'), contains('API key'));
    expect(find.text('改用手動輸入'), findsOneWidget);
    expect(fake.knownNames, isNull);
  });

  test('OpenAI 相容缺模型名稱時視為未設定', () async {
    FlutterSecureStorage.setMockInitialValues({
      'ai_provider': 'openAiCompatible',
      'ai_key_openAiCompatible': 'k',
      'ai_openai_base_url': 'https://example.com/v1',
    });
    expect(await AiConfigStore().load(), isNull);
  });

  widgetTestWithTree('改名後重新對照資料庫，不沿用舊食物的營養與連結', (tester) async {
    await pumpPage(tester);

    // AI 的「神秘醬料」改成資料庫有的「白飯」→ 改用白飯的營養（30g × 130）
    await tester.enterText(find.byKey(const Key('photo_name_1')), '白飯');
    await tester.pumpAndSettle();
    expect(textOf(tester, 'photo_kcal_1'), '39 大卡');

    // 資料庫的「白飯」改成查不到的名字 → 斷開資料庫連結、標示已改名
    await tester.enterText(find.byKey(const Key('photo_name_0')), '炸雞腿');
    await tester.pumpAndSettle();
    expect(find.text('已改名（AI 估算）'), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo_confirm_button')));
    await tester.pumpAndSettle();

    final saved = await db.select(db.foodEntries).get();
    final chicken = saved.firstWhere((e) => e.displayName == '炸雞腿');
    expect(chicken.foodItemId, isNull);
    expect(chicken.nutritionSource, NutritionSource.userEdited);
    final rice = saved.firstWhere((e) => e.displayName == '白飯');
    expect(rice.foodItemId, isNotNull);
    expect(rice.calories, closeTo(39, 1e-9));
  });
}
