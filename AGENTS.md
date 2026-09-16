# AGENTS.md — MyDieT 專案 AI 代理規則

適用於所有 AI 代理（Claude Code / Codex / Gemini / Antigravity / ChatGPT）。
跨專案共用規則正本在 `C:\Users\User\AI共同資料庫\`（見其 README.md）。

## 共同規則

Before making changes, read [docs/PowerShell-Git-避坑指南.md](docs/PowerShell-Git-避坑指南.md) and follow its Windows/PowerShell/Git safety rules.

重點：Markdown 跳脫不進 shell、`[System.IO.*]` 路徑一律絕對化、PowerShell 5.1 的 BOM 問題、
改檔後 `git diff --check` + `git diff`、整檔 diff 即停不 commit。

## 專案文件

- [PROJECT_SPEC.md](PROJECT_SPEC.md) — 需求規格
- [ARCHITECTURE.md](ARCHITECTURE.md) — 架構
- [ROADMAP.md](ROADMAP.md) — 開發路線

## 基本邊界

- 未經明確要求不 commit、不 push、不建 PR、不 deploy。
- 只改任務必要的檔案；不做無關重構與大規模格式化。
- 回報實際執行過的命令與輸出，不虛構驗證結果。
