import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/nutrition/nutrition_calculator.dart';
import 'package:mydiet/core/nutrition/nutrition_facts.dart';
import 'package:mydiet/core/nutrition/serving_unit.dart';

/// 白飯，每 100g（fiber 刻意留 null，用來驗證「未知 ≠ 0」）
const whiteRice = NutritionFacts(
  calories: 130,
  protein: 2.7,
  carbs: 28,
  fat: 0.3,
  sugar: 0.1,
  fiber: null,
  sodium: 1,
);

void main() {
  group('toGrams', () {
    test('g 直接對應', () {
      expect(
        NutritionCalculator.toGrams(quantity: 180, unit: ServingUnit.g),
        180,
      );
    });

    test('ml 以 1:1 近似', () {
      expect(
        NutritionCalculator.toGrams(quantity: 250, unit: ServingUnit.ml),
        250,
      );
    });

    test('serving 需乘上每份公克數', () {
      expect(
        NutritionCalculator.toGrams(
          quantity: 1.5,
          unit: ServingUnit.serving,
          servingGrams: 200,
        ),
        300,
      );
    });

    test('serving 缺 servingGrams → 拋錯', () {
      expect(
        () => NutritionCalculator.toGrams(
          quantity: 1,
          unit: ServingUnit.serving,
        ),
        throwsArgumentError,
      );
    });

    test('serving 的 servingGrams 非正數 → 拋錯', () {
      expect(
        () => NutritionCalculator.toGrams(
          quantity: 1,
          unit: ServingUnit.serving,
          servingGrams: 0,
        ),
        throwsArgumentError,
      );
    });

    test('份量 0 是合法的', () {
      expect(NutritionCalculator.toGrams(quantity: 0, unit: ServingUnit.g), 0);
    });

    test('負數份量 → 拋錯', () {
      expect(
        () => NutritionCalculator.toGrams(quantity: -1, unit: ServingUnit.g),
        throwsArgumentError,
      );
    });

    test('NaN / Infinity → 拋錯', () {
      expect(
        () => NutritionCalculator.toGrams(
          quantity: double.nan,
          unit: ServingUnit.g,
        ),
        throwsArgumentError,
      );
      expect(
        () => NutritionCalculator.toGrams(
          quantity: double.infinity,
          unit: ServingUnit.g,
        ),
        throwsArgumentError,
      );
    });
  });

  group('forGrams', () {
    test('100g 等於原本的每 100g 數值', () {
      final r = NutritionCalculator.forGrams(per100g: whiteRice, grams: 100);
      expect(r.calories, closeTo(130, 0.001));
      expect(r.protein, closeTo(2.7, 0.001));
      expect(r.carbs, closeTo(28, 0.001));
      expect(r.fat, closeTo(0.3, 0.001));
      expect(r.sodium, closeTo(1, 0.001));
    });

    test('50g 為一半', () {
      final r = NutritionCalculator.forGrams(per100g: whiteRice, grams: 50);
      expect(r.calories, closeTo(65, 0.001));
      expect(r.protein, closeTo(1.35, 0.001));
      expect(r.carbs, closeTo(14, 0.001));
    });

    test('180g', () {
      final r = NutritionCalculator.forGrams(per100g: whiteRice, grams: 180);
      expect(r.calories, closeTo(234, 0.001));
      expect(r.protein, closeTo(4.86, 0.001));
      expect(r.carbs, closeTo(50.4, 0.001));
      expect(r.fat, closeTo(0.54, 0.001));
      expect(r.sodium, closeTo(1.8, 0.001));
    });

    test('null 欄位縮放後仍是 null，不會變成 0', () {
      final r = NutritionCalculator.forGrams(per100g: whiteRice, grams: 180);
      expect(r.fiber, isNull);
    });

    test('0g 全部歸零，但 null 仍是 null', () {
      final r = NutritionCalculator.forGrams(per100g: whiteRice, grams: 0);
      expect(r.calories, 0);
      expect(r.protein, 0);
      expect(r.sodium, 0);
      expect(r.fiber, isNull);
    });

    test('負公克數 → 拋錯', () {
      expect(
        () => NutritionCalculator.forGrams(per100g: whiteRice, grams: -10),
        throwsArgumentError,
      );
    });
  });

  group('forPortion', () {
    test('一碗 200g 的白飯', () {
      final r = NutritionCalculator.forPortion(
        per100g: whiteRice,
        quantity: 1,
        unit: ServingUnit.serving,
        servingGrams: 200,
      );
      expect(r.grams, 200);
      expect(r.facts.calories, closeTo(260, 0.001));
      expect(r.facts.carbs, closeTo(56, 0.001));
    });

    test('直接輸入 180g', () {
      final r = NutritionCalculator.forPortion(
        per100g: whiteRice,
        quantity: 180,
        unit: ServingUnit.g,
      );
      expect(r.grams, 180);
      expect(r.facts.calories, closeTo(234, 0.001));
    });
  });

  group('rounding', () {
    test('預設一位小數', () {
      final r = NutritionCalculator.forGrams(
        per100g: whiteRice,
        grams: 180,
      ).rounded();
      expect(r.protein, 4.9); // 4.86 → 4.9
      expect(r.fat, 0.5); // 0.54 → 0.5
      expect(r.calories, 234.0);
    });

    test('可指定小數位數', () {
      final r = NutritionCalculator.forGrams(
        per100g: whiteRice,
        grams: 180,
      ).rounded(decimals: 0);
      expect(r.protein, 5.0);
      expect(r.fat, 1.0); // 0.54 → 1（四捨五入）
    });

    test('四捨五入不會把 null 變成 0', () {
      final r = NutritionCalculator.forGrams(
        per100g: whiteRice,
        grams: 180,
      ).rounded();
      expect(r.fiber, isNull);
    });

    test('負的小數位數 → 拋錯', () {
      expect(() => whiteRice.rounded(decimals: -1), throwsArgumentError);
    });
  });

  group('NutritionFacts 加總', () {
    test('兩筆相加', () {
      final a = NutritionCalculator.forGrams(per100g: whiteRice, grams: 100);
      final b = NutritionCalculator.forGrams(per100g: whiteRice, grams: 100);
      final sum = a + b;
      expect(sum.calories, closeTo(260, 0.001));
      expect(sum.carbs, closeTo(56, 0.001));
    });

    test('兩邊都 null 才是 null', () {
      const a = NutritionFacts(calories: 1, protein: 1, carbs: 1, fat: 1);
      const b = NutritionFacts(calories: 1, protein: 1, carbs: 1, fat: 1);
      expect((a + b).fiber, isNull);
    });

    test('一邊有值一邊 null → 取已知值', () {
      const a = NutritionFacts(
        calories: 1,
        protein: 1,
        carbs: 1,
        fat: 1,
        fiber: 3,
      );
      const b = NutritionFacts(calories: 1, protein: 1, carbs: 1, fat: 1);
      expect((a + b).fiber, 3);
    });

    test('從 zero 開始累加', () {
      final entries = [
        NutritionCalculator.forGrams(per100g: whiteRice, grams: 100),
        NutritionCalculator.forGrams(per100g: whiteRice, grams: 50),
      ];
      final total = entries.fold(NutritionFacts.zero, (a, b) => a + b);
      expect(total.calories, closeTo(195, 0.001));
    });
  });

  group('macroPercent', () {
    test('P/C/F 百分比加起來是 100', () {
      const f = NutritionFacts(
        calories: 500,
        protein: 25,
        carbs: 50,
        fat: 20,
      );
      final m = f.macroPercent;
      expect(m.protein + m.carbs + m.fat, closeTo(100, 0.001));
    });

    test('依熱量佔比而非重量', () {
      // P 25g=100kcal, C 50g=200kcal, F 20g=180kcal, 合計 480
      const f = NutritionFacts(
        calories: 500,
        protein: 25,
        carbs: 50,
        fat: 20,
      );
      final m = f.macroPercent;
      expect(m.protein, closeTo(100 / 480 * 100, 0.01));
      expect(m.carbs, closeTo(200 / 480 * 100, 0.01));
      expect(m.fat, closeTo(180 / 480 * 100, 0.01));
    });

    test('全部為 0 時回 0/0/0，不會除以零', () {
      final m = NutritionFacts.zero.macroPercent;
      expect(m.protein, 0);
      expect(m.carbs, 0);
      expect(m.fat, 0);
    });
  });
}
