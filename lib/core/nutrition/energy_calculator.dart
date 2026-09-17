import '../../features/profile/domain/profile_enums.dart';

/// BMI / BMR / TDEE / 每日熱量目標。純 Dart，無狀態，不依賴 Flutter。
///
/// 這不是醫療工具。只提供一般營養學常用的估算公式，不做診斷、不給疾病建議。
abstract final class EnergyCalculator {
  // 合理輸入範圍。超出範圍視為輸入錯誤，而不是硬算出一個沒有意義的數字。
  static const _minHeightCm = 50.0;
  static const _maxHeightCm = 300.0;
  static const _minWeightKg = 10.0;
  static const _maxWeightKg = 500.0;
  static const _minAge = 0;
  static const _maxAge = 130;

  /// 減重時的每日熱量下限，低於此值不再往下扣。
  static const minCaloriesMale = 1500;
  static const minCaloriesFemale = 1200;

  static const _deficitForLose = 500;
  static const _surplusForGain = 300;

  /// 由出生日期算實際年齡（足歲）。
  static int ageFromBirthDate(DateTime birthDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    if (birthDate.isAfter(today)) {
      throw ArgumentError.value(birthDate, 'birthDate', '不可晚於今天');
    }
    var age = today.year - birthDate.year;
    final hadBirthday =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// BMI = 體重(kg) / 身高(m)²
  static double bmi({required double weightKg, required double heightCm}) {
    _validateWeight(weightKg);
    _validateHeight(heightCm);
    final m = heightCm / 100;
    return weightKg / (m * m);
  }

  /// BMR（基礎代謝率），Mifflin-St Jeor 公式。
  ///
  /// 男：10×kg + 6.25×cm − 5×age + 5
  /// 女：10×kg + 6.25×cm − 5×age − 161
  static double bmr({
    required BiologicalSex sex,
    required int ageYears,
    required double heightCm,
    required double weightKg,
  }) {
    _validateAge(ageYears);
    _validateHeight(heightCm);
    _validateWeight(weightKg);

    final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
    return switch (sex) {
      BiologicalSex.male => base + 5,
      BiologicalSex.female => base - 161,
    };
  }

  /// 活動係數。
  static double activityFactor(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
    ActivityLevel.veryActive => 1.9,
  };

  /// TDEE = BMR × 活動係數
  static double tdee({
    required BiologicalSex sex,
    required int ageYears,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
  }) {
    final b = bmr(
      sex: sex,
      ageYears: ageYears,
      heightCm: heightCm,
      weightKg: weightKg,
    );
    return b * activityFactor(activityLevel);
  }

  /// 每日建議攝取熱量（kcal，四捨五入到整數）。
  ///
  /// - 減重：TDEE − 500，但不低於性別下限
  /// - 維持：TDEE
  /// - 增重：TDEE + 300
  ///
  /// [manualOverride] 有值時直接採用，完全覆蓋計算結果 —— 使用者對自己的
  /// 目標有最終決定權。
  static int dailyCalorieTarget({
    required BiologicalSex sex,
    required int ageYears,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required GoalType goal,
    int? manualOverride,
  }) {
    if (manualOverride != null) {
      if (manualOverride <= 0) {
        throw ArgumentError.value(manualOverride, 'manualOverride', '必須大於 0');
      }
      return manualOverride;
    }

    final t = tdee(
      sex: sex,
      ageYears: ageYears,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: activityLevel,
    );

    final target = switch (goal) {
      GoalType.lose => t - _deficitForLose,
      GoalType.maintain => t,
      GoalType.gain => t + _surplusForGain,
    };

    final floor = switch (sex) {
      BiologicalSex.male => minCaloriesMale,
      BiologicalSex.female => minCaloriesFemale,
    };

    // 下限只在減重時保護。維持與增重本來就不會低於 TDEE。
    if (goal == GoalType.lose && target < floor) return floor;
    return target.round();
  }

  static void _validateHeight(double cm) {
    if (cm.isNaN || cm < _minHeightCm || cm > _maxHeightCm) {
      throw ArgumentError.value(
        cm,
        'heightCm',
        '身高必須介於 $_minHeightCm 至 $_maxHeightCm 公分',
      );
    }
  }

  static void _validateWeight(double kg) {
    if (kg.isNaN || kg < _minWeightKg || kg > _maxWeightKg) {
      throw ArgumentError.value(
        kg,
        'weightKg',
        '體重必須介於 $_minWeightKg 至 $_maxWeightKg 公斤',
      );
    }
  }

  static void _validateAge(int years) {
    if (years < _minAge || years > _maxAge) {
      throw ArgumentError.value(years, 'ageYears', '年齡必須介於 $_minAge 至 $_maxAge');
    }
  }
}
