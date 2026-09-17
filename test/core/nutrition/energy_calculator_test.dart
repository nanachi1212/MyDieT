import 'package:flutter_test/flutter_test.dart';
import 'package:mydiet/core/nutrition/energy_calculator.dart';
import 'package:mydiet/features/profile/domain/profile_enums.dart';

void main() {
  group('ageFromBirthDate', () {
    test('生日已過', () {
      expect(
        EnergyCalculator.ageFromBirthDate(
          DateTime(1990, 3, 10),
          now: DateTime(2026, 9, 16),
        ),
        36,
      );
    });

    test('生日還沒到', () {
      expect(
        EnergyCalculator.ageFromBirthDate(
          DateTime(1990, 12, 25),
          now: DateTime(2026, 9, 16),
        ),
        35,
      );
    });

    test('今天剛好生日', () {
      expect(
        EnergyCalculator.ageFromBirthDate(
          DateTime(1990, 9, 16),
          now: DateTime(2026, 9, 16),
        ),
        36,
      );
    });

    test('出生日期在未來 → 拋錯', () {
      expect(
        () => EnergyCalculator.ageFromBirthDate(
          DateTime(2027, 1, 1),
          now: DateTime(2026, 9, 16),
        ),
        throwsArgumentError,
      );
    });
  });

  group('BMI', () {
    test('170cm / 65kg', () {
      expect(
        EnergyCalculator.bmi(weightKg: 65, heightCm: 170),
        closeTo(22.49, 0.01),
      );
    });

    test('160cm / 50kg', () {
      expect(
        EnergyCalculator.bmi(weightKg: 50, heightCm: 160),
        closeTo(19.53, 0.01),
      );
    });

    test('身高超出範圍 → 拋錯', () {
      expect(
        () => EnergyCalculator.bmi(weightKg: 65, heightCm: 0),
        throwsArgumentError,
      );
      expect(
        () => EnergyCalculator.bmi(weightKg: 65, heightCm: 400),
        throwsArgumentError,
      );
    });

    test('體重超出範圍 → 拋錯', () {
      expect(
        () => EnergyCalculator.bmi(weightKg: 0, heightCm: 170),
        throwsArgumentError,
      );
      expect(
        () => EnergyCalculator.bmi(weightKg: 600, heightCm: 170),
        throwsArgumentError,
      );
    });
  });

  group('BMR — Mifflin-St Jeor', () {
    // 男 30 歲 175cm 70kg: 10*70 + 6.25*175 - 5*30 + 5 = 700 + 1093.75 - 150 + 5
    test('男性 30 歲', () {
      expect(
        EnergyCalculator.bmr(
          sex: BiologicalSex.male,
          ageYears: 30,
          heightCm: 175,
          weightKg: 70,
        ),
        closeTo(1648.75, 0.01),
      );
    });

    // 女 30 歲 160cm 55kg: 550 + 1000 - 150 - 161
    test('女性 30 歲', () {
      expect(
        EnergyCalculator.bmr(
          sex: BiologicalSex.female,
          ageYears: 30,
          heightCm: 160,
          weightKg: 55,
        ),
        closeTo(1239.0, 0.01),
      );
    });

    test('同條件下男性 BMR 比女性高 166', () {
      const args = (age: 40, h: 168.0, w: 62.0);
      final male = EnergyCalculator.bmr(
        sex: BiologicalSex.male,
        ageYears: args.age,
        heightCm: args.h,
        weightKg: args.w,
      );
      final female = EnergyCalculator.bmr(
        sex: BiologicalSex.female,
        ageYears: args.age,
        heightCm: args.h,
        weightKg: args.w,
      );
      expect(male - female, closeTo(166, 0.001));
    });

    test('年齡越大 BMR 越低', () {
      double at(int age) => EnergyCalculator.bmr(
        sex: BiologicalSex.male,
        ageYears: age,
        heightCm: 175,
        weightKg: 70,
      );
      expect(at(20), greaterThan(at(40)));
      expect(at(40), greaterThan(at(65)));
      // 每多 5 歲少 25 kcal
      expect(at(20) - at(25), closeTo(25, 0.001));
    });

    test('年齡超出範圍 → 拋錯', () {
      expect(
        () => EnergyCalculator.bmr(
          sex: BiologicalSex.male,
          ageYears: -1,
          heightCm: 175,
          weightKg: 70,
        ),
        throwsArgumentError,
      );
      expect(
        () => EnergyCalculator.bmr(
          sex: BiologicalSex.male,
          ageYears: 200,
          heightCm: 175,
          weightKg: 70,
        ),
        throwsArgumentError,
      );
    });
  });

  group('活動係數與 TDEE', () {
    test('五個等級的係數', () {
      expect(EnergyCalculator.activityFactor(ActivityLevel.sedentary), 1.2);
      expect(EnergyCalculator.activityFactor(ActivityLevel.light), 1.375);
      expect(EnergyCalculator.activityFactor(ActivityLevel.moderate), 1.55);
      expect(EnergyCalculator.activityFactor(ActivityLevel.active), 1.725);
      expect(EnergyCalculator.activityFactor(ActivityLevel.veryActive), 1.9);
    });

    test('活動程度越高 TDEE 越高', () {
      double at(ActivityLevel l) => EnergyCalculator.tdee(
        sex: BiologicalSex.male,
        ageYears: 30,
        heightCm: 175,
        weightKg: 70,
        activityLevel: l,
      );
      expect(at(ActivityLevel.sedentary), lessThan(at(ActivityLevel.light)));
      expect(at(ActivityLevel.light), lessThan(at(ActivityLevel.moderate)));
      expect(at(ActivityLevel.moderate), lessThan(at(ActivityLevel.active)));
      expect(at(ActivityLevel.active), lessThan(at(ActivityLevel.veryActive)));
    });

    test('TDEE = BMR × 係數', () {
      final bmr = EnergyCalculator.bmr(
        sex: BiologicalSex.male,
        ageYears: 30,
        heightCm: 175,
        weightKg: 70,
      );
      expect(
        EnergyCalculator.tdee(
          sex: BiologicalSex.male,
          ageYears: 30,
          heightCm: 175,
          weightKg: 70,
          activityLevel: ActivityLevel.moderate,
        ),
        closeTo(bmr * 1.55, 0.01),
      );
    });
  });

  group('每日熱量目標', () {
    int target({
      BiologicalSex sex = BiologicalSex.male,
      int age = 30,
      double h = 175,
      double w = 70,
      ActivityLevel level = ActivityLevel.moderate,
      required GoalType goal,
      int? override,
    }) => EnergyCalculator.dailyCalorieTarget(
      sex: sex,
      ageYears: age,
      heightCm: h,
      weightKg: w,
      activityLevel: level,
      goal: goal,
      manualOverride: override,
    );

    test('維持 = TDEE', () {
      final tdee = EnergyCalculator.tdee(
        sex: BiologicalSex.male,
        ageYears: 30,
        heightCm: 175,
        weightKg: 70,
        activityLevel: ActivityLevel.moderate,
      );
      expect(target(goal: GoalType.maintain), tdee.round());
    });

    test('減重 = 維持 − 500', () {
      expect(
        target(goal: GoalType.maintain) - target(goal: GoalType.lose),
        500,
      );
    });

    test('增重 = 維持 + 300', () {
      expect(
        target(goal: GoalType.gain) - target(goal: GoalType.maintain),
        300,
      );
    });

    test('男性減重不低於 1500', () {
      // 久坐、高齡、嬌小體型 → TDEE 很低，扣 500 後會低於下限
      final t = target(
        sex: BiologicalSex.male,
        age: 80,
        h: 155,
        w: 45,
        level: ActivityLevel.sedentary,
        goal: GoalType.lose,
      );
      expect(t, EnergyCalculator.minCaloriesMale);
    });

    test('女性減重不低於 1200', () {
      final t = target(
        sex: BiologicalSex.female,
        age: 80,
        h: 145,
        w: 40,
        level: ActivityLevel.sedentary,
        goal: GoalType.lose,
      );
      expect(t, EnergyCalculator.minCaloriesFemale);
    });

    test('下限只在減重時套用，維持不會被抬高', () {
      final maintain = target(
        sex: BiologicalSex.female,
        age: 80,
        h: 145,
        w: 40,
        level: ActivityLevel.sedentary,
        goal: GoalType.maintain,
      );
      expect(maintain, lessThan(EnergyCalculator.minCaloriesFemale));
    });

    test('女性三種目標都算得出來', () {
      for (final g in GoalType.values) {
        expect(target(sex: BiologicalSex.female, goal: g), greaterThan(0));
      }
    });

    test('manualOverride 完全覆蓋計算結果', () {
      expect(target(goal: GoalType.lose, override: 1800), 1800);
      expect(target(goal: GoalType.maintain, override: 1800), 1800);
      // 低於下限也照用 —— 使用者對自己的目標有最終決定權
      expect(target(goal: GoalType.lose, override: 900), 900);
    });

    test('manualOverride 非正數 → 拋錯', () {
      expect(
        () => target(goal: GoalType.lose, override: 0),
        throwsArgumentError,
      );
      expect(
        () => target(goal: GoalType.lose, override: -100),
        throwsArgumentError,
      );
    });

    test('無效身高體重 → 拋錯', () {
      expect(() => target(goal: GoalType.lose, h: 10), throwsArgumentError);
      expect(() => target(goal: GoalType.lose, w: 1), throwsArgumentError);
    });
  });
}
