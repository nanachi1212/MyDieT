# 第一批 GitHub Issues

Repo: https://github.com/nanachi1212/MyDieT

建議 labels：`P0` `P1` `P2` `P3` `P4` / `area:db` `area:ui` `area:ai` `area:health` `area:data` / `blocked`

---

## P0

### #1 `P0` Flutter 專案初始化與雙平台 build
建立 `flutter create --org com.mydiet --platforms=android,ios .`，設定 Android `minSdk 26`、iOS 13.0，加入 P0 相依套件，補 `.gitignore`（`key.properties` `*.jks` `*.env`）。
**DoD**：`flutter analyze` 零 error；`flutter build apk --debug` 與 `flutter build ios --simulator --no-codesign` 都成功。

### #2 `P0` `area:ui` App 骨架：Riverpod + go_router + 四個佔位頁
`ProviderScope` → `MaterialApp.router`，路由 `/` `/diary/add` `/profile` `/settings`，底部導覽可切換。Material 3 theme（light/dark）。
**DoD**：真機/模擬器啟動可在四頁間切換。 依賴 #1

### #3 `P0` `area:db` Drift 初始化與 `UserProfiles` 表
建立 `app_database.dart`，只建 `UserProfiles` 一張表，跑通 `build_runner` codegen，寫 migration strategy 骨架。
**DoD**：可寫入與讀回一筆 profile 的單元測試通過。 依賴 #1

### #4 `P0` 文件與 README
README 說明如何 build/run/test，連結三份規格文件。
**DoD**：新機器照 README 能跑起來。

---

## P1

### #5 `P1` `area:db` 完成 Drift schema
`BodyMeasurements` `FoodItems` `FoodEntries` `AppSettings` + DAO。`FoodEntries` 必須存營養快照欄位。
**DoD**：schema 測試 + migration 測試通過。 依賴 #3

### #6 `P1` `energy_calculator`：BMI / BMR / TDEE / 每日目標
Mifflin-St Jeor，活動係數，減重 −500 / 維持 / 增重 +300，男 1500、女 1200 kcal 下限保護。
**DoD**：`energy_calculator_test.dart` 涵蓋男女 × 五種活動等級 × 三種目標 + 下限案例。

### #7 `P1` `nutrition_calculator` 與 `NutritionFacts`
per-100g → 實際份量換算、加總、null 欄位不得變 0。
**DoD**：單元測試含 null 與加總案例。

### #8 `P1` `area:ui` Onboarding 與 Profile 頁
輸入性別/生日/身高/體重/活動/目標/目標體重，顯示 BMI 與每日熱量目標，允許手動覆寫。
**DoD**：新使用者 2 分鐘內完成並看到目標熱量。 依賴 #3 #6

### #9 `P1` `area:data` 台灣食物種子資料（首批 100 筆）
`assets/data/taiwan_foods.csv`（欄位：name, name_en, category, kcal, protein, carbs, fat, sugar, fiber, sodium, default_serving_g, default_serving_label, source），首次啟動匯入 SQLite。
**DoD**：啟動後可搜尋到「滷肉飯」「牛肉麵」「雞腿便當」。 依賴 #5

### #10 `P1` `area:ui` 食物搜尋 + 份量輸入 + 加入餐別
`LIKE` 搜尋、最近使用、公克/份數切換、即時營養預覽、選餐別寫入。
**DoD**：可完成一次完整手動記錄。 依賴 #5 #7 #9

### #11 `P1` `area:ui` Dashboard
目標／已攝取／剩餘、四餐區塊、七項營養素、Macro %、日期切換、編輯與刪除紀錄。
**DoD**：記錄一整天數字正確（手算核對）；殺 App 重開資料仍在。 依賴 #10

### #12 `P1` 自訂食物
使用者新增自己的 per-100g 食物，來源標 `user_custom`。
**DoD**：新增後可搜尋到並使用。 依賴 #9

### #13 `P1` 體重紀錄與趨勢圖
`BodyMeasurements` 寫入 + fl_chart 折線。
**DoD**：可記錄多筆體重並看到趨勢。 依賴 #5

---

## P2（等 P1 驗收完再開工）

### #14 `P2` `area:ai` `PromptBuilder`：標準 prompt 與 `mydiet.v1` schema
### #15 `P2` `area:ai` `ResponseParser`：六層容錯 + fixture 測試（**建議與 #14 一起做，是 AI 層的地基**）
### #16 `P2` `area:ui` 拍照／選圖頁，照片存 App 私有目錄
### #17 `P2` `area:ai` Mode A：分享到外部 AI App → 貼回解析
### #18 `P2` `area:ai` `AiProvider` 介面 + Gemini / OpenAI / Claude 實作
### #19 `P2` `SecureStore` + AI 設定頁（Keychain / Keystore、遮罩顯示、連線測試）
### #20 `P2` `area:ui` **Review / Confirm 畫面**（改名、改份量即時重算、刪除、新增、選餐別）
### #21 `P2` `NutritionRepository.resolveOrEstimate` + 「估算值」標示

---

# 建議先執行的第一個 Issue

## → **#1 Flutter 專案初始化與雙平台 build**

理由：
- 現在 `E:\CodexProject\MyDieT` 是空的，沒有 Flutter 專案就沒有任何東西能跑
- 雙平台 build 是**最容易在最後才爆炸**的環節（Android SDK 版本、iOS pod、Kotlin/AGP 對齊）。第一天就把它踩通，之後每個 Phase 都是純加功能
- 它沒有任何前置依賴

實務上建議把 **#1 + #2 + #3 當成一個 P0 session 一起做完**（下面的 prompt 就是這樣設計的），因為三者合起來才是「App 能跑起來」這一件事。

---

# 交給 Claude Code 執行 P0 的 Prompt

直接複製下面整段：

---

你是 MyDieT 專案的 Flutter 工程師。工作目錄 `E:\CodexProject\MyDieT`，目前是空目錄（只有 `PROJECT_SPEC.md`、`ARCHITECTURE.md`、`ROADMAP.md`、`GITHUB_ISSUES.md`）。

先讀 `ARCHITECTURE.md` 第 1、2、3 節與 `ROADMAP.md` 的 P0 段落，然後**只執行 P0**。

本機環境：Windows 11、Flutter 3.44.6、Dart 3.12.2。iOS build 在 Windows 上無法驗證，這是預期的，不要嘗試繞過。

## 要做的事

1. `flutter create --org com.mydiet --project-name mydiet --platforms=android,ios .`
2. `pubspec.yaml` 加入：
   - dependencies：`flutter_riverpod` `go_router` `drift` `drift_flutter` `sqlite3_flutter_libs` `path_provider` `flutter_secure_storage` `intl`
   - dev_dependencies：`build_runner` `drift_dev` `flutter_lints`
   用 `flutter pub add` 取得目前最新穩定版，不要手寫版本號猜測。
3. 依 `ARCHITECTURE.md` 第 3 節建立 `lib/` 資料夾骨架，空目錄放 `.gitkeep`。**這個階段不要預先建立 P1/P2 才會用到的檔案內容**，只建目錄。
4. `lib/main.dart`：`ProviderScope` 包住 `MyDietApp`。
5. `lib/app.dart`：`MaterialApp.router` + go_router，四個路由 `/`（Dashboard）、`/diary/add`、`/profile`、`/settings`，用 `StatefulShellRoute` 或 `NavigationBar` 讓前三頁可切換（Settings 從 Dashboard AppBar 進入）。每頁先放簡單佔位內容 + 頁面標題。
6. `lib/core/theme/app_theme.dart`：Material 3，light 與 dark，seed color 自選一個食物感的綠色。
7. `lib/core/database/app_database.dart`：Drift database，**只**定義 `UserProfiles` 一張表（欄位見 `ARCHITECTURE.md` 4.1），`schemaVersion = 1`，用 `driftDatabase(name: 'mydiet')` 開檔，跑 `dart run build_runner build --delete-conflicting-outputs` 產生 `.g.dart`。
8. Android：`minSdk 26`；iOS：`platform :ios, '13.0'`。
9. `.gitignore` 補上 `key.properties`、`*.jks`、`*.keystore`、`*.env`。
10. `analysis_options.yaml`：`include: package:flutter_lints/flutter.yaml`，加 `prefer_const_constructors: true`。
11. `test/database_smoke_test.dart`：用記憶體 DB 寫入一筆 UserProfile 再讀回，驗證欄位正確。
12. `README.md`：專案一句話說明、環境需求、build/run/test 指令、三份文件連結。

## 驗收（全部要實際執行並貼出輸出）

- `flutter analyze` → 零 error
- `flutter test` → 全通過
- `flutter build apk --debug` → 成功
- iOS：只需確認 `ios/` 目錄與 Podfile 設定正確，並在報告中標記 `NOT_TESTED（Windows 無法 build iOS）`

## 限制

- 不要做 P1 之後的任何功能：不要 onboarding、不要食物搜尋、不要 AI、不要 Health、不要 CI/CD、不要多語系
- 不要建立只有一個實作的抽象介面
- 不要美化 UI，佔位頁越簡單越好
- 不要 `git init` / `git commit` / `git push`，除非我另外要求
- 完成後依全域規則格式回報：執行摘要、修改內容、驗證（PASS/FAIL/BLOCKED/NOT_TESTED）、注意事項、待授權動作

---
