# MyDieT — ARCHITECTURE

最後更新：2026-09-16 · Flutter 3.44.6 / Dart 3.12.2（本機已安裝版本）

---

## 1. 技術選型（選什麼 / 為什麼 / 代價）

| 項目 | 選擇 | 為什麼 | 代價 |
|---|---|---|---|
| 框架 | **Flutter 3.44+** | Android/iOS 一套程式碼，維護成本最低 | 平台特有功能需寫 plugin channel |
| 狀態管理 | **Riverpod 3.4** | 樣板比 bloc 少一半、compile-safe DI、AI agent 容易讀寫 | 團隊若熟 bloc 需要適應 |
| 本地 DB | **Drift 2.35（SQLite）** | 每日營養彙總本質是 SQL aggregate；migration 機制成熟；可直接下 SQL | 需要 build_runner codegen |
| 路由 | **go_router 18** | 官方維護、宣告式、deep link 現成 | 無 |
| Health | **health 13.3** | 一個 API 同時封裝 HealthKit 與 Health Connect | 平台權限設定仍要手動配置 |
| 安全儲存 | **flutter_secure_storage 11** | iOS Keychain / Android Keystore | 無 |
| 圖表 | **fl_chart 1.2** | 單純、夠用 | 無 |
| 相機/相簿 | **image_picker 1.2** | 不需要自訂相機 UI | 無 |
| HTTP | **dio** | AI provider 需要 timeout / 攔截器 | 無 |
| 後端 | **沒有** | MVP 不需要 | 之後要同步得補 |
| 帳號 | **沒有** | MVP 不需要 | 之後要多裝置得補 |

**不採用**：bloc（樣板多）、Isar（v3 維護狀況不穩）、Hive（沒有 SQL 彙總能力）、Firebase（等於引入後端）、Google Fit（已被 Health Connect 取代）。

---

## 2. 分層

```
presentation/   Widget、頁面、Riverpod provider
     ↓ 只依賴
domain/         entity、repository 介面、use case（純 Dart，零 Flutter import）
     ↑ 實作
data/           Drift DAO、AI provider 實作、Health 實作、營養資料 source
```

規則：
- `domain/` 不 import `package:flutter/*`，可單元測試，不需要模擬器
- `presentation/` 不直接碰 Drift table 或 HTTP
- 每個 feature 自成一個資料夾，跨 feature 共用的放 `core/`

---

## 3. 資料夾結構

```
lib/
  main.dart
  app.dart                       # MaterialApp + router + theme
  core/
    database/
      app_database.dart          # Drift DB + migration
      tables.dart                # table 定義
      daos/                      # food_dao.dart, entry_dao.dart, profile_dao.dart
    nutrition/
      nutrition_calculator.dart  # 份量 × per100g → 實際營養
      energy_calculator.dart     # BMI / BMR / TDEE / 每日目標
    secure/
      secure_store.dart          # API key 讀寫（唯一入口）
    utils/
      date_x.dart, json_x.dart
    theme/
      app_theme.dart
  features/
    profile/
      domain/       user_profile.dart, activity_level.dart, goal_type.dart
      data/         profile_repository.dart
      presentation/ profile_page.dart, onboarding_page.dart, profile_providers.dart
    diary/
      domain/       food_item.dart, food_entry.dart, meal_type.dart, nutrition_facts.dart
      data/         diary_repository.dart
      presentation/ dashboard_page.dart, meal_section.dart, add_food_page.dart,
                    food_search_page.dart, portion_editor.dart, diary_providers.dart
    foods/
      data/         nutrition_repository.dart, taiwan_seed_source.dart,
                    user_custom_source.dart
    ai/
      domain/       ai_provider.dart, ai_analysis_result.dart, analyzed_item.dart
      data/
        providers/  gemini_provider.dart, openai_provider.dart, claude_provider.dart
        prompt_builder.dart      # 產生標準 prompt（Mode A 與 B 共用）
        response_parser.dart     # 容錯 JSON parser（Mode A 與 B 共用）
      presentation/ capture_page.dart, manual_paste_page.dart,
                    review_page.dart, ai_settings_page.dart, ai_providers.dart
    health/
      data/         health_repository.dart
      presentation/ health_settings_page.dart
    settings/
      presentation/ settings_page.dart
assets/
  data/taiwan_foods.csv
test/
  core/nutrition/    energy_calculator_test.dart, nutrition_calculator_test.dart
  features/ai/       response_parser_test.dart
  fixtures/ai_responses/   真實 AI 回傳樣本（含壞格式）
```

---

## 4. 資料模型

### 4.1 Drift Tables

```dart
// 單列，id 固定 1
UserProfiles: id, biologicalSex, birthDate, heightCm, activityLevel,
              goalType, targetWeightKg, manualCalorieOverride?, createdAt, updatedAt

BodyMeasurements: id, date, weightKg, bodyFatPercent?, source(manual|health), createdAt

// 食物字典
FoodItems: id, name, nameEn?, brand?, category(六大類 enum), barcode?,
           per100g: calories, protein, carbs, fat, sugar?, fiber?, sodium?,
           defaultServingGrams?, defaultServingLabel?,   // 例：1 碗 = 200g
           source(taiwan_seed|user_custom|ai_estimated|openfoodfacts),
           isUserCreated, createdAt

// 實際紀錄
FoodEntries: id, date, mealType(breakfast|lunch|dinner|snack),
             foodItemId?,                 // 可為 null（一次性 AI 估算）
             displayName,                 // 顯示用快照
             quantity, unit,
             grams,                       // 正規化後的公克數
             // ↓ 營養快照，必存。FoodItems 之後更新不可以改動歷史紀錄
             calories, protein, carbs, fat, sugar?, fiber?, sodium?,
             nutritionSource(database|ai_estimated|user_edited),
             aiAnalysisId?, createdAt

AiAnalyses: id, createdAt, mode(manual_paste|api), providerId?,
            photoPath?, rawResponse, parseStatus(ok|partial|failed), itemCount

AppSettings: key, value                  // 非機敏設定；API key 一律走 SecureStore
```

**關鍵設計：`FoodEntries` 存營養快照。**
食物字典之後修正數值，不能讓上個月的日記跟著變。這是唯一一處刻意的資料重複。

### 4.2 Domain entity

```dart
class NutritionFacts {         // 不可變，單位固定 kcal / g / mg
  final double calories, protein, carbs, fat;
  final double? sugar, fiber, sodium;
  NutritionFacts scaleToGrams(double grams);   // per-100g → 實際
  NutritionFacts operator +(NutritionFacts o); // 日彙總用
}

class DailySummary {
  final DateTime date;
  final NutritionFacts total;
  final Map<MealType, NutritionFacts> byMeal;
  final int calorieTarget;
  int get remaining => calorieTarget - total.calories.round();
  MacroPercent get macroPercent;               // 依熱量佔比
}
```

Macro 百分比：`protein×4`、`carbs×4`、`fat×9`，各自除以三者熱量總和（不是除以總攝取熱量，避免誤差造成不足 100%）。

`sugar / fiber / sodium` 是 nullable。**缺資料就是 null，不可以填 0**；UI 顯示「—」。

---

## 5. AI Provider 抽象

```dart
abstract class AiProvider {
  String get id;                          // gemini | openai | claude
  String get displayName;
  bool get requiresApiKey;
  Future<AiAnalysisResult> analyzePhoto({
    required Uint8List image,
    required String prompt,
  });
}
```

實作：`GeminiProvider` / `OpenAiProvider` / `ClaudeProvider`。
之後加 OpenRouter 或 OpenAI-compatible endpoint，只要新增一個類別並註冊到 registry，其餘程式不動。

**Mode A（半手動）不是一個 AiProvider**，它是 UI 流程：

```
PromptBuilder.build()  →  Share Sheet（照片＋prompt）
                       →  使用者貼回  →  ResponseParser.parse()
```

`PromptBuilder` 與 `ResponseParser` 是 Mode A 與 Mode B **共用**的，只有取得回應的方式不同。這是整個 AI 層唯一需要的抽象。

### 5.1 容錯 parser 策略（依序嘗試）

1. 整段就是 JSON → 直接 parse
2. 抓 markdown code fence 內的內容
3. 掃描第一個「括號平衡」的 `{...}` 區塊
4. 逐欄位正規化：key alias map、字串轉數字、單位轉小寫
5. 缺 `nutrition_per_100g` → 標記該項需查 NutritionRepository
6. 全失敗 → `parseStatus = failed`，把原始文字顯示在 Review 頁，提供手動輸入入口

`test/fixtures/ai_responses/` 放真實壞格式樣本，每遇到一種新壞格式就加一個 fixture。

---

## 6. Nutrition Repository

```dart
abstract class NutritionSource {
  String get id;
  Future<List<FoodItem>> search(String query, {int limit});
  Future<FoodItem?> getByBarcode(String barcode);   // 不支援回 null
}

class NutritionRepository {
  // 依序查詢，先命中先回；結果標示來源
  final List<NutritionSource> sources;  // [UserCustom, TaiwanSeed, (P4) OpenFoodFacts]
  Future<List<FoodItem>> search(String q);
  Future<FoodItem> resolveOrEstimate(AnalyzedItem aiItem); // 查不到 → 用 AI 估算值並標記
}
```

台灣種子資料以 CSV 放 `assets/`，首次啟動匯入 SQLite。搜尋 MVP 用 `LIKE`（幾百筆足夠），資料量長大再換 FTS5。

---

## 7. Health 整合

```dart
class HealthRepository {
  Future<bool> requestPermissions(Set<HealthPermission> perms); // opt-in
  Future<double?> latestWeight();
  Future<int?> activeEnergyToday();
  Future<void> writeMeal(FoodEntry entry);   // Dietary Energy + macros
  Future<void> writeWeight(double kg);
}
```

- 全部呼叫包在 try/catch，失敗只記 log，**不中斷使用者流程**
- 權限未授予時回 null / no-op，UI 顯示「未連接」
- iOS：`Info.plist` 的 `NSHealthShareUsageDescription`、`NSHealthUpdateUsageDescription` + HealthKit entitlement
- Android：Health Connect 權限宣告，`minSdk 26`

---

## 8. 安全

| 項目 | 做法 |
|---|---|
| API Key | `flutter_secure_storage`（iOS Keychain / Android Keystore）。唯一入口 `SecureStore`，禁止其他地方直接讀寫 |
| Key 顯示 | UI 只顯示遮罩 `sk-••••abcd`，不提供「顯示完整 key」 |
| Log | 禁止把 key、完整 AI request body 寫進 log |
| Git | `.gitignore` 排除 `*.env`、`*.jks`、`key.properties`、`**/GoogleService-Info.plist` |
| 照片 | App 私有目錄，不寫入相簿，不上傳（Mode B 僅送往使用者自選的 provider） |
| 網路 | 只連使用者設定的 AI endpoint。無分析、無追蹤、無自家 server |

---

## 9. 測試策略

跟修改風險相稱，不追求覆蓋率數字。

**必測**：
- `energy_calculator`：BMR / TDEE / 目標熱量（男女、各活動等級、下限保護）
- `nutrition_calculator`：份量換算、加總、null 欄位不得變成 0
- `response_parser`：每個 fixture 至少一個 case，含完全壞掉的輸入
- Drift migration：schema 升版

**不測**：UI 像素、第三方套件本身、HTTP 200。

---

## 10. 刻意不做的（YAGNI）

- 後端 / 帳號 / 雲端同步 → 有真實需求再說
- 只有一個實作的 repository 不抽介面（`NutritionSource` 例外，它一開始就有多個實作）
- 多語系 i18n 框架 → 先寫死繁中，要出海再導入
- 自訂相機 UI → `image_picker` 夠用
- 獨立 DI 容器 → Riverpod 本身就是 DI
- 離線佇列 / 重試框架 → 本地優先，沒有要同步什麼
