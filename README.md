# MyDieT

Android + iOS 跨平台飲食管理 App（Flutter）。

只做三件事：知道自己吃了什麼、掌握每天的熱量與營養、幫助減重 / 維持 / 增重。

目前進度：**P0 完成**（專案骨架）。功能開發從 P1 開始。

---

## 環境需求

- Flutter 3.44.6（stable）/ Dart 3.12.2 — 開發時使用的版本
- Android：Android SDK，`minSdk 26`（Health Connect 需求）
- iOS：Xcode + macOS，最低 iOS 13.0

## 常用指令

```bash
flutter pub get                       # 安裝相依套件
dart run build_runner build           # 產生 Drift 程式碼（改 table 後要跑）
flutter run                           # 在連接的裝置上執行
flutter analyze                       # 靜態檢查
flutter test                          # 單元與 widget 測試
flutter build apk --debug             # Android debug build
```

iOS build 需要 macOS 與 Xcode。**在 Windows 上無法驗證 iOS build**，這是環境限制，不是專案問題。

## 專案結構

`lib/core/` 跨 feature 共用（database、theme、之後的 nutrition / secure）。
`lib/features/<feature>/` 分 `domain` / `data` / `presentation` 三層，`domain` 不依賴 Flutter。

完整說明見 [ARCHITECTURE.md](ARCHITECTURE.md) 第 3 節。

## 文件

| 文件 | 內容 |
|---|---|
| [PROJECT_SPEC.md](PROJECT_SPEC.md) | 產品需求、核心流程、MVP 範圍、Non-goals |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 技術選型、分層、資料模型、AI 抽象、安全 |
| [ROADMAP.md](ROADMAP.md) | P0–P4 的目標、任務與驗收標準 |
| [GITHUB_ISSUES.md](GITHUB_ISSUES.md) | Issue 清單與執行順序 |

開發前請先讀 ROADMAP 對應的 Phase，**不要提前實作下一個 Phase 的內容**。

## 安全

API Key 一律走 `flutter_secure_storage`（iOS Keychain / Android Keystore），
禁止 hardcode、禁止進版控。`key.properties`、`*.jks`、`*.env` 已列入 `.gitignore`。

## AI 代理規則

所有 AI 代理（Claude / Codex / Gemini / Antigravity / ChatGPT）請先讀 [AGENTS.md](AGENTS.md)，
特別是 [docs/PowerShell-Git-避坑指南.md](docs/PowerShell-Git-避坑指南.md)。
