import '../domain/profile_enums.dart';

/// Onboarding 與 Profile 編輯共用的顯示文字與驗證規則。
abstract final class ProfileForm {
  static String sexLabel(BiologicalSex s) => switch (s) {
    BiologicalSex.male => '男性',
    BiologicalSex.female => '女性',
  };

  static String activityLabel(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => '久坐',
    ActivityLevel.light => '輕度活動',
    ActivityLevel.moderate => '中度活動',
    ActivityLevel.active => '高度活動',
    ActivityLevel.veryActive => '非常活躍',
  };

  static String activityHint(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => '幾乎不運動，整天坐著',
    ActivityLevel.light => '每週運動 1–3 天',
    ActivityLevel.moderate => '每週運動 3–5 天',
    ActivityLevel.active => '每週運動 6–7 天',
    ActivityLevel.veryActive => '每天高強度運動或體力勞動',
  };

  static String goalLabel(GoalType g) => switch (g) {
    GoalType.lose => '減重',
    GoalType.maintain => '維持',
    GoalType.gain => '增重',
  };

  /// 年齡層，只用於顯示。實際熱量計算一律用真實年齡。
  static String ageGroupLabel(int age) {
    if (age < 30) return '青年';
    if (age < 45) return '成年';
    if (age < 65) return '中年';
    return '高齡';
  }

  /// BMI 的一般分類文字。這不是醫療診斷，只是常見的參考區間。
  static String bmiLabel(double bmi) {
    if (bmi < 18.5) return '過輕';
    if (bmi < 24) return '正常';
    if (bmi < 27) return '過重';
    return '肥胖';
  }

  static String? validateHeight(String? v) {
    final d = double.tryParse((v ?? '').trim());
    if (d == null) return '請輸入身高';
    if (d < 50 || d > 300) return '身高請輸入 50 到 300 公分之間';
    return null;
  }

  static String? validateWeight(String? v) {
    final d = double.tryParse((v ?? '').trim());
    if (d == null) return '請輸入體重';
    if (d < 10 || d > 500) return '體重請輸入 10 到 500 公斤之間';
    return null;
  }

  /// 目標體重可以留空。
  static String? validateTargetWeight(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null) return '請輸入數字';
    if (d < 10 || d > 500) return '目標體重請輸入 10 到 500 公斤之間';
    return null;
  }

  static String? validateCalorieTarget(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '請輸入每日熱量目標';
    final i = int.tryParse(t);
    if (i == null) return '請輸入整數';
    if (i < 500 || i > 10000) return '請輸入 500 到 10000 大卡之間';
    return null;
  }
}
