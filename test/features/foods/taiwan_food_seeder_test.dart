import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/database/app_database.dart';
import 'package:mydiet/core/nutrition/nutrition_facts.dart';
import 'package:mydiet/features/diary/domain/diary_enums.dart';
import 'package:mydiet/features/foods/data/food_repository.dart';
import 'package:mydiet/features/foods/data/taiwan_food_seeder.dart';

import '../../helpers/test_app.dart';

const _csv = '''
# 註解行會被忽略
name,name_en,category,calories,protein,carbs,fat,sugar,fiber,sodium,serving_g,serving_label,estimated
白飯,steamed white rice,grains,130,2.7,28.0,0.3,0.1,0.4,1,200,碗,0
高麗菜,cabbage,vegetables,23,1.3,4.8,0.1,2.9,1.1,17,,,0
冬粉,mung bean noodles,grains,351,0.1,86.6,0.1,,0.8,10,,,0
牛肉麵,beef noodle soup,other,75,5.0,8.5,2.5,0.8,0.6,450,700,碗,1
''';

void main() {
  late AppDatabase db;
  late TaiwanFoodSeeder seeder;

  setUp(() {
    db = memoryDb();
    seeder = TaiwanFoodSeeder(db, loadCsv: () async => _csv);
  });

  group('parseCsv', () {
    test('忽略註解與表頭，解析出四筆', () {
      expect(TaiwanFoodSeeder.parseCsv(_csv), hasLength(4));
    });

    test('空欄位解析成 null，不是 0', () {
      final rows = TaiwanFoodSeeder.parseCsv(_csv);
      final noodles = rows.firstWhere((r) => r.name == '冬粉');
      expect(noodles.sugar, isNull);
      expect(noodles.servingGrams, isNull);
      expect(noodles.servingLabel, isNull);
      // 有填 0.8 的 fiber 就要是 0.8
      expect(noodles.fiber, 0.8);
    });

    test('estimated 欄位正確對應', () {
      final rows = TaiwanFoodSeeder.parseCsv(_csv);
      expect(rows.firstWhere((r) => r.name == '白飯').estimated, isFalse);
      expect(rows.firstWhere((r) => r.name == '牛肉麵').estimated, isTrue);
    });

    test('分類字串對應到 FoodCategory', () {
      final rows = TaiwanFoodSeeder.parseCsv(_csv);
      expect(
        rows.firstWhere((r) => r.name == '白飯').category,
        FoodCategory.grains,
      );
      expect(
        rows.firstWhere((r) => r.name == '高麗菜').category,
        FoodCategory.vegetables,
      );
    });
  });

  group('seed', () {
    test('第一次執行會匯入全部資料', () async {
      expect(await seeder.seed(), 4);
      expect(await db.select(db.foodItems).get(), hasLength(4));
    });

    test('重複執行不會產生重複資料', () async {
      await seeder.seed();
      final second = await seeder.seed();
      final third = await seeder.seed();

      expect(second, 0);
      expect(third, 0);
      expect(await db.select(db.foodItems).get(), hasLength(4));
    });

    test('複合餐點標記為 taiwanSeedEstimated', () async {
      await seeder.seed();
      final beef = await (db.select(
        db.foodItems,
      )..where((t) => t.name.equals('牛肉麵'))).getSingle();
      final rice = await (db.select(
        db.foodItems,
      )..where((t) => t.name.equals('白飯'))).getSingle();

      expect(beef.source, FoodSource.taiwanSeedEstimated);
      expect(rice.source, FoodSource.taiwanSeed);
    });

    test('不覆蓋、不刪除使用者自訂食物', () async {
      final repo = FoodRepository(db);
      final custom = await repo.createCustom(
        name: '阿嬤的滷肉',
        category: FoodCategory.protein,
        per100g: const NutritionFacts(
          calories: 250,
          protein: 15,
          carbs: 2,
          fat: 20,
        ),
      );

      await seeder.seed();
      await seeder.seed();

      final saved = await repo.byId(custom.id);
      expect(saved, isNotNull);
      expect(saved!.name, '阿嬤的滷肉');
      expect(saved.calories, 250);
      expect(saved.source, FoodSource.userCustom);
    });

    test('同名的自訂食物不會擋掉種子資料', () async {
      await FoodRepository(db).createCustom(
        name: '白飯',
        category: FoodCategory.grains,
        per100g: const NutritionFacts(
          calories: 999,
          protein: 0,
          carbs: 0,
          fat: 0,
        ),
      );

      expect(await seeder.seed(), 4);

      final all = await (db.select(
        db.foodItems,
      )..where((t) => t.name.equals('白飯'))).get();
      expect(all, hasLength(2));
      expect(
        all.where((f) => f.source == FoodSource.userCustom).single.calories,
        999,
      );
      expect(
        all.where((f) => f.source == FoodSource.taiwanSeed).single.calories,
        130,
      );
    });

    test('serving 資訊有匯入', () async {
      await seeder.seed();
      final rice = await (db.select(
        db.foodItems,
      )..where((t) => t.name.equals('白飯'))).getSingle();

      expect(rice.defaultServingGrams, 200);
      expect(rice.defaultServingLabel, '碗');
      expect(rice.supportsServingUnit, isTrue);
    });
  });

  group('實際的 assets CSV', () {
    testWidgets('可以載入並匯入，且每一列都合法', (tester) async {
      final real = TaiwanFoodSeeder(db);
      final count = await real.seed();

      expect(count, greaterThanOrEqualTo(30));

      final items = await db.select(db.foodItems).get();
      for (final f in items) {
        expect(f.name.isNotEmpty, isTrue, reason: '名稱不可為空');
        expect(f.calories, greaterThanOrEqualTo(0));
        expect(f.protein, greaterThanOrEqualTo(0));
        expect(f.carbs, greaterThanOrEqualTo(0));
        expect(f.fat, greaterThanOrEqualTo(0));
      }

      // 重跑一次仍然不重複
      expect(await real.seed(), 0);
      expect(await db.select(db.foodItems).get(), hasLength(count));
    });
  });
}
