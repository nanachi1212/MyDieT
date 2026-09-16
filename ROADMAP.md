# MyDieT — ROADMAP

原則：**一次只做一個 Phase。** 每個 Phase 結束時 App 必須能在真機上跑。不要為了後面的 Phase 先蓋架構。

---

## P0 — 專案基礎

**Goal**：Android 與 iOS 都能 build 並跑起來，骨架就位，之後每個 Phase 只需要填內容。

**Tasks**
1. `flutter create --org com.mydiet --platforms=android,ios .`（專案名 `mydiet`）
2. 加入相依套件：`flutter_riverpod` `go_router` `drift` `drift_flutter` `sqlite3_flutter_libs` `flutter_secure_storage` `intl`；dev：`build_runner` `drift_dev` `flutter_lints` `test`
3. 建立 `ARCHITECTURE.md` 第 3 節的資料夾骨架（空目錄放 `.gitkeep`）
4. `app.dart`：MaterialApp.router + go_router，四個佔位路由：`/`（Dashboard）`/diary/add` `/profile` `/settings`
5. `main.dart`：`ProviderScope` 包住 App
6. `core/database/app_database.dart`：Drift DB，先只建 `UserProfiles` 一張表，跑通 codegen
7. `core/theme/app_theme.dart`：Material 3 light/dark，繁中字型 fallback
8. Android：`minSdk 26`、`compileSdk` 用最新、Kotlin/AGP 版本對齊
9. iOS：`platform :ios, '13.0'`、bundle id 設定
10. `.gitignore` 補上 `key.properties`、`*.jks`、`*.env`
11. `analysis_options.yaml`：開 `flutter_lints`，加 `prefer_const_constructors`
12. README：如何 build / run

**Deliverables**
`pubspec.yaml`、`lib/` 骨架、`app_database.dart` + 產生的 `.g.dart`、README

**Acceptance Criteria**
- `flutter analyze` 零 error
- `flutter build apk --debug` 成功
- `flutter build ios --simulator --no-codesign` 成功
- App 啟動顯示 Dashboard 佔位頁，底部導覽可切到另外三頁
- `flutter test` 通過（至少一個 smoke test）

**Dependencies**：無

**這個 Phase 不要做**
UI 美化、任何真實業務邏輯、AI、Health、CI/CD、多語系、狀態管理的複雜抽象、還沒用到的 table。

---

## P1 — 可用的 Calorie Tracker（沒有 AI 也完整）

**Goal**：P1 結束時，即使 AI 永遠不做，這個 App 也已經是一個能每天用的飲食記錄工具。

**Tasks**
1. Onboarding：性別、生日、身高、體重、活動程度、目標、目標體重
2. `energy_calculator`：BMI / BMR(Mifflin-St Jeor) / TDEE / 每日建議熱量 + 下限保護
3. 每日熱量目標可手動覆寫
4. Drift schema 完成：`BodyMeasurements` `FoodItems` `FoodEntries` `AppSettings`
5. `assets/data/taiwan_foods.csv` 種子資料（先 100 筆常見品項，之後補到 300–500），首次啟動匯入
6. 食物搜尋頁（`LIKE` 查詢 + 最近使用）
7. 份量輸入：公克 / 份數（`defaultServingGrams` 換算），即時顯示營養預覽
8. 自訂食物：使用者可新增自己的 per-100g 食物
9. Dashboard：目標／已攝取／剩餘、四個餐別區塊、七項營養素累計、Macro %
10. 日期切換（前一天／後一天／選日期）
11. 編輯與刪除既有紀錄
12. 體重紀錄與簡單趨勢圖（fl_chart）
13. 測試：`energy_calculator_test` `nutrition_calculator_test`

**Deliverables**
可安裝的 debug APK / iOS build，完整手動記錄流程

**Acceptance Criteria**
- 新使用者可在 2 分鐘內完成 onboarding 並看到自己的每日熱量目標
- 可記錄一整天四餐並看到正確累計（手算核對一份樣本）
- 殺掉 App 再開，資料還在
- 修改食物字典的營養值，**既有歷史紀錄數值不變**（快照驗證）
- sugar/fiber/sodium 缺資料時顯示「—」而不是 0
- `flutter test` 全綠

**Dependencies**：P0

**這個 Phase 不要做**
相機、AI、Health、Watch、匯出匯入、條碼、雲端、帳號、通知提醒。

---

## P2 — AI 辨識（Mode A / B / C）

**Goal**：拍照 → AI → Review → 入帳。且 AI 壞掉時 P1 的手動流程完全不受影響。

**Tasks**
1. `capture_page`：拍照或從相簿選，照片存 App 私有目錄
2. `PromptBuilder`：產生標準 prompt（含 `mydiet.v1` JSON schema 說明、要求繁中食物名）
3. `ResponseParser`：`ARCHITECTURE.md` 5.1 的六層容錯，配 fixture 測試
4. **Mode A**：分享照片＋prompt 到外部 AI App → 回到 App 貼上 → 解析。含「一鍵複製 Prompt」與剪貼簿偵測提示
5. **Mode B**：`AiProvider` 介面 + Gemini / OpenAI / Claude 三個實作
6. `SecureStore` + AI 設定頁：輸入、遮罩顯示、刪除 API key；連線測試按鈕
7. **Review 畫面**（本 Phase 最重要）：逐項顯示名稱／份量／營養／來源標籤；可改名、改份量（即時重算）、刪除、新增；選餐別；確認後才寫入
8. `NutritionRepository.resolveOrEstimate`：AI 品項先查資料庫，查不到才用 AI 估算值並標記「估算」
9. `AiAnalyses` 紀錄原始回應（除錯用，可在設定頁清除）
10. AI 全面失效的降級路徑：解析失敗 → 顯示原文 + 直接進手動輸入

**Deliverables**
三種模式可用的完整拍照記錄流程

**Acceptance Criteria**
- Mode A：用 ChatGPT / Claude / Gemini 各實測一張便當照，貼回都能解析出品項
- Mode B：三家 provider 各實測成功
- **AI 結果在使用者按下確認前，DB 內沒有任何 FoodEntry**
- 把「白飯 180g」改成 120g，營養即時按比例重算
- 餵 5 種壞格式回應（缺欄位／多餘文字／code fence／中文 key／純文字）都不 crash
- 清空 API key 後，Mode C 手動流程完全正常

**Dependencies**：P1

**這個 Phase 不要做**
AI 聊天、長篇健康報告、多張照片一次分析、AI 自動學習使用者習慣、串接第三方 App 私有 API、hosted AI（我們沒有後端）。

---

## P3 — Health 整合

**Goal**：體重與活動量進得來，飲食資料出得去，而且沒授權也不影響使用。

**Tasks**
1. `health` 套件整合 + iOS entitlement / Info.plist、Android Health Connect 宣告
2. 權限頁：逐項 opt-in，隨時可關
3. 讀取：身高、體重、體脂、Active Energy、步數、Workout
4. 寫入：Dietary Energy、Protein、Carbs、Fat、Sugar、Water、Weight
5. 體重雙向同步策略（以最新時間戳為準，標記 source）
6. 可選：把 Active Energy 計入當日可攝取熱量（預設關閉）
7. 全部呼叫 try/catch，失敗不中斷流程

**Deliverables**
Health 設定頁 + 雙向同步

**Acceptance Criteria**
- iPhone：記錄一餐後，Apple 健康 App 看得到 Dietary Energy 與三大營養素
- Android：Health Connect 看得到同樣資料
- 在 Apple 健康／Health Connect 改體重，App 下次開啟會更新
- **拒絕所有 Health 權限時，App 全功能正常，無錯誤彈窗**

**Dependencies**：P1（P2 非必要）

**這個 Phase 不要做**
Google Fit、Samsung Health SDK 直連（走 Health Connect 就好）、睡眠／心率／血糖等與飲食無關的資料。

---

## P4 — 台灣食物、Watch、上架準備

**Goal**：從「能用」變成「可以發佈」。

**Tasks**
1. 台灣食物資料補到 300–500 筆，含常見外食與手搖飲
2. 常見組合餐（雞腿便當＝白飯＋雞腿＋配菜）一鍵拆解記錄
3. 條碼掃描 + OpenFoodFacts（台灣包裝食品）
4. 資料匯出／匯入 JSON（取代雲端備份）
5. Apple Watch / Wear OS **簡化版**：今日 `980 / 1650 kcal` + P/C/F + 快速加水。不是完整 App
6. UI/UX polish：空狀態、載入、錯誤、無障礙字級
7. App 圖示、啟動畫面、商店截圖與說明
8. 隱私政策（重點：資料留在裝置、API key 不外傳、我們沒有 server）
9. Release 簽章設定（keystore 不進 git）
10. 真機測試：Android 與 iOS 各至少一台

**Deliverables**
Release build、商店素材、隱私政策

**Acceptance Criteria**
- 記錄「雞腿便當」可一步完成
- 匯出後重灌 App 再匯入，資料完整
- Watch 顯示今日熱量且與手機一致
- Release build 在真機安裝並連用七天無 crash

**Dependencies**：P1、P2、P3

**這個 Phase 不要做**
訂閱付費牆、帳號系統、社群、多語系、食譜平台、Watch 完整記錄功能。

---

## 全程紀律

- 不提前實作下一個 Phase 的架構
- 每個 Phase 的 Acceptance Criteria 全過才進下一個
- 遇到「未來可能需要」→ 寫進這份 ROADMAP，不寫進程式碼
- 任何新增相依套件前先問：標準庫或現有套件能不能做
