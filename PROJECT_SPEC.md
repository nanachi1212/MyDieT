# MyDieT — PROJECT_SPEC

Repo: https://github.com/nanachi1212/MyDieT
平台：Android + iOS（Flutter 單一程式碼）
最後更新：2026-09-16

---

## 1. 產品定位

一個每天用得下去的飲食記錄 App。只做三件事：

1. 讓使用者知道自己吃了什麼
2. 讓使用者掌握每天的熱量與營養成分
3. 幫助使用者減重 / 維持 / 增重

**不是**醫療 App、不是研究工具、不是健康聊天機器人。任何功能若不直接服務上面三點，不進 MVP。

---

## 2. 開源基底評估結論

| 專案 | License | 狀態 | 技術 | 結論 |
|---|---|---|---|---|
| [OpenNutriTracker](https://github.com/simonoppowa/OpenNutriTracker) | **GPL-3.0** | 活躍（2026-09-16 有 commit，2.5k★） | Flutter + bloc + get_it + hive_ce | **只作架構參考，不 fork、不複製程式碼** |
| [Fud AI](https://github.com/apoorvdarshan/fud-ai) | MIT | 活躍（415★） | **原生 Swift + Kotlin**，非 Flutter | 只作 AI provider / prompt 設計參考 |

### 決策：從新的 Flutter 專案開始，不 fork

**選什麼**：全新 Flutter 專案，重用的是 **pub.dev 套件**而不是別人的 App 程式碼。

**為什麼**：
- OpenNutriTracker 是 GPL-3.0。fork 或抄它的程式碼，我們整個 App 就必須以 GPL-3.0 釋出。而 GPL-3.0 與 Apple App Store 條款有已知的實務衝突（VLC 2011 年因此被下架），iOS 上架會是真實風險，不是理論問題。
- Fud AI 是 MIT，但它是原生 Swift/Kotlin 兩套程式碼，對 Flutter 專案沒有可直接重用的實作，且它的雙原生架構正好是我們要避免的維護成本。
- 我們要的功能（拍照、本地 DB、Health 同步、BYOK AI）在 Flutter 生態都是成熟套件，不需要靠 fork 取得。

**代價**：UI 與 food diary 要自己寫，大約比 fork 多 2–3 週。換來的是乾淨的 license、自己選的架構、AI agent 容易維護的程式碼。

**可以合法做的事**：閱讀 OpenNutriTracker 的架構與 UI 流程作為設計參考（看與學不受 GPL 限制，複製程式碼才受限）。

---

## 3. 核心使用流程

### 3.1 AI 記錄流程（P2）

```
拍照 / 從相簿選圖
  → App 產生標準 Prompt
  → AI 分析（Mode A 半手動 / Mode B 自動）
  → 解析成 AI 辨識結果
  → 【Review 畫面】使用者確認或修改
  → 選擇餐別（早/午/晚/點心）
  → 寫入紀錄
  → 更新當日累計
```

**硬性規則：AI 結果絕不直接寫入正式紀錄。** 一定要經過 Review 畫面。

Review 畫面可修改：
- 食物名稱（烤雞腿 → 炸雞腿，重新查營養）
- 份量（180g → 120g，即時重算）
- 刪除某一項
- 手動新增漏掉的項目
- 直接改營養數值（最後手段）

### 3.2 手動記錄流程（P1，不需要 AI）

```
選餐別 → 搜尋食物 → 輸入份量 → 預覽營養 → 儲存
```

沒有 AI、沒有訂閱、沒有 API Key，App 也必須完全可用。

---

## 4. 每日 Dashboard

**首頁必須顯示：**

- 今日熱量目標 / 已攝取 / 剩餘
- 四個餐別區塊（早餐、午餐、晚餐、點心）各自小計 + 品項
- 當日累計營養素：Calories、Protein、Carbohydrates、Fat、Sugar、Fiber、Sodium
- Macro 百分比：Protein % / Carbs % / Fat %（依熱量佔比計算）

**分類與營養素必須分開。** 「全穀雜糧」是食物分類，不是 macro nutrient。

食物分類（六大類，台灣衛福部口徑）：
`全穀雜糧` `豆魚蛋肉` `蔬菜` `水果` `乳品` `油脂與堅果`

---

## 5. Profile 與熱量計算

**輸入**：生理性別（男/女）、出生年月或年齡、身高、體重、活動程度、目標體重、目標（減重/維持/增重）

**計算**：

- BMI = 體重(kg) / 身高(m)²
- BMR = **Mifflin-St Jeor**
  - 男：`10×kg + 6.25×cm − 5×age + 5`
  - 女：`10×kg + 6.25×cm − 5×age − 161`
- TDEE = BMR × 活動係數（1.2 / 1.375 / 1.55 / 1.725 / 1.9）
- 每日建議熱量：
  - 減重：TDEE − 500（下限：男 1500、女 1200 kcal）
  - 維持：TDEE
  - 增重：TDEE + 300

**使用者可以直接覆寫最終每日熱量目標**，覆寫值優先。

年齡分群（青年／成年／中年／高齡）**只用於 UI 顯示**，計算一律用實際年齡。

不做醫療診斷、不給疾病建議。BMI 只顯示數值與一般區間文字。

---

## 6. AI 三種模式

### Mode A：使用者自己的 AI 訂閱（半手動）

給已經付 ChatGPT Plus / Claude Pro / Gemini Pro 的人，不用再付 API 費用。

```
拍照 → App 把照片存到暫存 + 產生標準 Prompt
→ 使用者用系統分享（Share Sheet）把「照片 + Prompt」送到 ChatGPT / Claude / Gemini App
→ AI 回答
→ 使用者複製回答
→ 回到 MyDieT 貼上（或 App 偵測剪貼簿內容自動提示）
→ 解析 → Review → 儲存
```

不假設能呼叫第三方 App 的私有 API。整條路徑都是使用者自己操作，合規。

### Mode B：自己的 API Key（全自動）

Provider abstraction，第一批：**Gemini / OpenAI / Anthropic Claude**。
架構要能輕鬆加入 OpenRouter、OpenAI-compatible endpoint、本機模型。

API Key 儲存規則（強制）：
- iOS：Keychain
- Android：Keystore-backed encrypted storage
- **禁止** hardcode、禁止 commit 進 git、禁止寫入一般 SharedPreferences、禁止上傳到我們自己的 server（我們沒有 server）

### Mode C：完全手動

搜尋食物、輸入份量、調整營養、加入餐點。AI 全部失效時 App 仍完整可用。

---

## 7. AI 回傳格式契約

App 產生的 Prompt 會要求 AI 回傳這個結構：

```json
{
  "schema": "mydiet.v1",
  "items": [
    {
      "name": "白飯",
      "name_en": "steamed white rice",
      "quantity": 180,
      "unit": "g",
      "confidence": 0.85,
      "food_category": "grains",
      "nutrition_per_100g": {
        "calories": 130, "protein": 2.7, "carbs": 28.0, "fat": 0.3,
        "sugar": 0.1, "fiber": 0.4, "sodium": 1
      }
    }
  ],
  "note": "便當，含滷汁"
}
```

**Parser 必須容忍**：
- ` ```json ` code fence 包裹
- 純 JSON
- JSON 前後有說明文字（抓第一個平衡的 `{...}`）
- 缺欄位（缺 `nutrition_per_100g` → 標記需查資料庫；缺 `sugar/fiber/sodium` → null，不是 0）
- `unit` 為 `g` / `ml` / `serving` / `piece` / `顆` / `碗`
- 中文或英文 key 混用（維護一份 alias map）
- 數字是字串（`"180"` → 180）

**絕不因為 JSON 不完美就整個失敗。** 至少要救出食物名稱與份量，其餘讓使用者在 Review 畫面補。解析完全失敗時，顯示原始文字 + 手動輸入入口。

---

## 8. AI 與營養資料的責任分離

```
AI            →  「照片裡可能是什麼食物 + 估計份量」
NutritionRepo →  「這個食物每 100g 的營養」
Calculator    →  「依份量算出實際要記錄的營養」
```

AI 不是營養資料的權威來源。

資料庫查不到該食物時，允許用 AI 提供的 `nutrition_per_100g` 作 fallback，但：
- 紀錄要標 `source = ai_estimated`
- UI 要明顯標示「估算值」
- 使用者可以把它存成自訂食物

---

## 9. 台灣食物

MVP 內建種子資料（約 300–500 筆常見台灣食物），涵蓋：

雞腿便當、排骨便當、滷肉飯、肉燥飯、雞肉飯、火雞肉飯、牛肉麵、鍋燒意麵、蛋餅、飯糰、水餃、鍋貼、小籠包、鹽酥雞、雞排、滷味、火鍋、豆漿、珍珠奶茶 …

資料來源：衛福部食藥署「食品營養成分資料庫」open data，加上常見外食品項的整理值。

`NutritionRepository` 設計成可插拔 source：
```
TaiwanSeedSource (MVP 內建)
UserCustomSource (使用者自訂，MVP)
OpenFoodFactsSource (P4，條碼)
USDASource (P4+，可選)
```

MVP **不**建立全球營養資料平台、不做後端同步的食物資料庫。

---

## 10. Health 整合（P3）

單一套件 `health`（同時封裝 HealthKit 與 Health Connect）。

**讀取**：身高、體重、體脂、Active Energy、步數、Workout
**寫入**：Dietary Energy、Protein、Carbs、Fat、Sugar、Water、Weight

Android 走 **Health Connect**，透過它與 Samsung Health / Google 生態交換資料。**不**做 Google Fit 舊架構。

權限規則：全部 opt-in、隨時可關、沒有權限 App 照常運作。

---

## 11. 資料與隱私

- **Local-first。MVP 沒有後端、沒有帳號、沒有雲端同步。**
- 所有飲食資料存在裝置本機 SQLite
- 照片存在 App 私有目錄，使用者可刪
- Mode B 的 API Key 只存在裝置 secure storage
- 唯一的對外連線：使用者自己設定的 AI provider（Mode B）
- 匯出／匯入 JSON（P4）取代雲端備份

---

## 12. MVP 範圍（P1 + P2）

**做**：Profile、BMI/BMR/TDEE、每日目標、四餐日記、手動食物輸入、搜尋、Dashboard、本地 DB、拍照、AI Mode A/B/C、Review 畫面。

**明確不做（第一版）**：
醫療診斷 · 疾病建議 · 長篇 AI 健康報告 · 論文式營養分析 · 社群 · 排行榜 · 教練平台 · 社交 feed · 後端 · 強制帳號 · 訂閱付費牆 · 食譜平台 · AI 聊天機器人 · 多語系（先繁中）· Watch 完整 App

AI 若給建議，只能一句話：「今天蛋白質還差約 25g。」

---

## 13. 成功標準

第一版可安裝在 Android 與 iPhone，使用者能連續一週每天記錄三餐，看到熱量與 macro，並知道自己離目標多遠。
