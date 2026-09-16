# PowerShell / Git 避坑指南

> 正本位置：`C:\Users\User\AI共同資料庫\guides\PowerShell-Git-避坑指南.md`
> （備份：`E:\OneDrive\AI共同資料庫`、`G:\我的雲端硬碟\AI共同資料庫`）。
> 修改請改正本，再執行 `backup.ps1` 同步。
>
> 本檔記錄本專案開發過程中實際踩過的坑。用 PowerShell 改檔案、或讓 AI（Claude / Codex）代產生指令前，先看這份。

---

## 1. Markdown 的 `\_` 不要帶進 PowerShell

聊天視窗或 Markdown 裡常把底線寫成跳脫字元 `\_`（避免變成斜體）。**複製到 PowerShell 時必須還原成 `_`。**

```powershell
# ❌ 錯：檔案其實叫 my_file.dart，這行會找不到檔案或建出怪檔名
Get-Content .\lib\my\_file.dart

# ✅ 對
Get-Content .\lib\my_file.dart
```

同理會被誤帶進 shell 的還有：`\*`、`` \` ``、`\[`、`\]`、`\$`。
**規則：貼進終端機前，先把所有 `\` + 標點的跳脫還原。**

---

## 2. `[System.IO.File]` 的相對路徑 ≠ `$PWD`

`[System.IO.File]::ReadAllText("x.md")` 用的是 **.NET 的 `CurrentDirectory`**，
而 PowerShell 的 `cd` 只改 `$PWD`，**不一定會同步 .NET CurrentDirectory**。

結果：明明 `Get-Content .\x.md` 讀得到，`ReadAllText("x.md")` 卻噴 `FileNotFoundException`，
或更糟——`WriteAllText("x.md", ...)` 把檔案寫到完全另一個目錄（通常是家目錄）。

```powershell
# ❌ 危險：相對路徑交給 .NET
[System.IO.File]::WriteAllText("docs\note.md", $content)

# ✅ 安全：先組成絕對路徑
$path = Join-Path $PWD 'docs\note.md'
[System.IO.File]::WriteAllText($path, $content)

# ✅ 檔案已存在時更保險（會正規化並驗證存在）
$path = (Resolve-Path '.\docs\note.md').Path
```

**規則：任何 `[System.IO.*]` 呼叫一律用 `Join-Path $PWD` / `Resolve-Path` / 絕對路徑，不用裸相對路徑。**

---

## 3. Windows PowerShell 5.1 的 `-Encoding utf8` 會寫 BOM

| 環境 | `Set-Content -Encoding utf8` 實際結果 |
|---|---|
| Windows PowerShell 5.1（`powershell.exe`） | **UTF-8 with BOM**（開頭多 `EF BB BF`） |
| PowerShell 7+（`pwsh.exe`） | UTF-8 no BOM |

BOM 會造成：Dart/YAML/JSON parse 失敗、shell script 第一行壞掉、`git diff` 顯示整檔改動。

需要 **UTF-8 無 BOM** 時：

```powershell
$path = Join-Path $PWD 'pubspec.yaml'
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
```

`[System.Text.UTF8Encoding]::new($false)` 的 `$false` 就是「不要 BOM」。

檢查目前檔案有沒有 BOM：

```powershell
Format-Hex -Path .\pubspec.yaml -Count 3
```
開頭是 `EF BB BF` 就是有 BOM。

用 `$PSVersionTable.PSVersion` 確認自己在 5.1 還是 7。

---

## 4. 動手前：先 `Test-Path`，必要時 `Resolve-Path`

```powershell
$rel = '.\lib\main.dart'
if (-not (Test-Path $rel)) { throw "找不到檔案：$rel" }
$path = (Resolve-Path $rel).Path
```

不驗證就寫，最常見的失敗是**靜默建出一個新檔案**（路徑打錯、大小寫錯、跳脫沒還原），
而你以為自己改到了原檔。

---

## 5. 改完後：用 git 驗收

```bash
git status
git diff --check
git diff
```

- `git diff --check`：檢查行尾空白、衝突標記等 whitespace error。
- `git diff`：**實際用眼睛看改了什麼**，不要跳過。
- 已 `git add` 過的內容，另外檢查暫存區：

```bash
git diff --cached --check
git diff --cached
```

---

## 6. 如果 diff 顯示「整個檔案都改了」→ 停下來，不要 commit

只改一行卻整檔變紅綠，幾乎一定是下列之一：

| 症狀 | 原因 |
|---|---|
| 第一行顯示為修改 | 加了 / 移除了 **BOM** |
| 每一行都顯示為修改 | **換行符**從 LF 變 CRLF（或反向） |
| 出現亂碼 | **編碼**從 UTF-8 變成 Big5 / UTF-16 |

處置：

```bash
git diff --stat          # 看改動規模是否合理
git checkout -- <file>   # 尚未 add 時還原（確認沒有其他想保留的改動再做）
```

還原後改用第 8 節的安全模板重寫。**不要因為「看起來好像只是格式」就 commit 下去。**

---

## 7. 分清楚 LF→CRLF warning 與真正的 whitespace error

**這是 warning，不是錯誤，可以忽略：**

```text
warning: LF will be replaced by CRLF in docs/foo.md.
The file will have its original line endings in your working directory.
```
只是 `core.autocrlf` 在做換行轉換，Git 存進 repo 的仍是 LF。

**這是真正要修的 error（`git diff --check` 報的）：**

```text
docs/foo.md:12: trailing whitespace.
docs/foo.md:30: new blank line at EOF.
lib/main.dart:8: leading whitespace.
```
這些是你這次改動引入的實體問題，修掉再 commit。

---

## 8. 安全模板：UTF-8 無 BOM 修改檔案並保留其他內容

```powershell
# --- 安全改檔模板 -------------------------------------------------
$ErrorActionPreference = 'Stop'

# 1) 解析成絕對路徑，並確認檔案存在
$rel = '.\docs\PowerShell-Git-避坑指南.md'
if (-not (Test-Path -LiteralPath $rel)) { throw "檔案不存在：$rel" }
$path = (Resolve-Path -LiteralPath $rel).Path

# 2) 讀取整檔（明確指定 UTF-8，避免被系統 ANSI 猜錯）
$content = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))

# 3) 只做目標替換，其餘內容原樣保留
$old = 'version: 1.0.0'
$new = 'version: 1.1.0'
if ($content -notlike "*$old*") { throw "找不到要替換的內容：$old" }
$content = $content.Replace($old, $new)   # .Replace() 是字面字串，不會被當 regex

# 4) 寫回，UTF-8 無 BOM
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))

# 5) 驗收
git diff --check
git diff -- $path
# ------------------------------------------------------------------
```

要點：
- `-LiteralPath`：路徑含 `[` `]` 等字元時不會被當萬用字元。
- `.Replace()` 而非 `-replace`：後者是 regex，`.` `(` `$` 會有意外行為。
- 找不到目標就 `throw`：**寧可失敗，也不要寫出一個沒改到東西的檔案**。
- 新增檔案用 heredoc 風格的 here-string（`@'...'@`，結尾 `'@` 必須頂格）。

---

## 9. 給 AI / Codex 產生 PowerShell 指令的規則

要求 AI 產指令時，把這幾條貼給它（或讓它讀本檔）：

1. **不要把 Markdown 跳脫帶進 shell**：輸出的指令中不得出現 `\_`、`\*`、`` \` ``、`\[`；檔名一律寫原始字元。
2. **路徑一律絕對化**：`[System.IO.*]` 與任何跨 cmdlet 的路徑傳遞，先 `Join-Path $PWD` 或 `Resolve-Path`，禁止裸相對路徑。
3. **先驗證再動手**：寫入 / 替換前先 `Test-Path`，找不到目標字串就 `throw`，不得靜默建新檔。
4. **PowerShell 5.1 編碼**：需要 UTF-8 無 BOM 時，不得使用 `Set-Content -Encoding utf8`；改用
   `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))`。
5. **只改必要範圍**：不重寫整檔、不重排版、不批次格式化、不順手改換行符。
6. **附上驗收指令**：每段改檔指令後面要接 `git status` / `git diff --check` / `git diff`。
7. **整檔 diff 即停**：若 diff 顯示整檔改動，回報疑似 BOM / 換行 / 編碼問題並停止，不得 commit。
8. **不自行 commit / push**：除非使用者明確要求。

---

## 10. 不要用 `sed -i` / inline Python 改「含中文 + 反斜線」的檔案

**本指南寫作過程當場踩到的坑。** 在 Git Bash 用

```bash
sed -i 's|舊字串|新的 `C:\Users\User\AI共同資料庫`|' AGENTS.md
```

結果檔案被寫成亂碼（`C:SERSSERAI...`）：

1. `sed` 的替換字串裡 `\U`、`\L`、`\E` 是**大小寫轉換指令**，不是字面反斜線。
2. Git Bash 的 locale 不是 UTF-8 時，中文會被當單位元組處理，寫回就毀了編碼。

同樣地，`python - <<'PY'` 由 stdin 讀腳本時，Windows 會用系統 ANSI（cp950）解讀，
中文直接 `SyntaxError`。

**做法：**

- 改含中文的檔案：**整檔重寫**（`cat > file <<'EOF'`），不要就地替換。
- 一定要用 Python：把腳本**寫成檔案**再執行，並加 `PYTHONUTF8=1`，
  路徑與反斜線用 `chr(92)` 或 `\uXXXX` escape，不要靠終端機傳中文字面值。
- 改完立刻驗證編碼：

```bash
python -c "import io;io.open('AGENTS.md',encoding='utf-8').read();print('OK utf-8')"
```

失敗就是編碼壞了，**重寫，不要 commit**（見第 6 節）。

### 10.1 heredoc 的 `EOF` 一定要加單引號

```bash
cat > AGENTS.md <<'EOF'    # ✅ 引號 = 字面內容，不展開
cat > AGENTS.md <<EOF      # ❌ 反引號、$、\ 會被 shell 展開
```

沒加引號時，內容裡的 `` `git diff` ``、`$PWD`、`C:\Users` 會被當成命令替換、
變數與跳脫，輕則內容錯誤，重則 `bad substitution` 整個寫入失敗。

**規則：寫檔案內容一律 `<<'EOF'`；只有真的要插入變數才用不加引號的 `<<EOF`。**

---

## 11. Windows Packaged App / MSIX 檔案系統虛擬化

**這一節的代價最高：AI 代理會回報「全部 PASS」，而使用者端根本沒裝好。**

### 問題

Claude 桌面版、OpenAI Codex 桌面版等 AI 代理是以 Windows 打包應用程式（MSIX）形式執行。
它們的 shell 對使用者設定檔路徑的**寫入**會被 Windows 靜默重導到容器目錄：

```text
代理以為寫到：
C:\Users\<User>\AppData\Local\Android\Sdk

實際落在：
C:\Users\<User>\AppData\Local\Packages\<PackageFamilyName>\LocalCache\Local\Android\Sdk
```

在代理的 shell 裡，讀取、執行、驗證**全部都會成功**，因為容器內看得到自己寫的東西。
使用者在真實 PowerShell 打開同一個路徑，卻是空的，或根本不存在。

沒有錯誤訊息，沒有警告。這是最危險的地方。

### 受影響 / 不受影響

| 路徑 | 是否被重導 |
|---|---|
| `%LOCALAPPDATA%`（`C:\Users\<User>\AppData\Local\...`） | ✅ 會 |
| `%APPDATA%`、`%USERPROFILE%` 下部分子路徑 | ✅ 會 |
| Dart / Flutter 的 pub cache（`AppData\Local\Pub\Cache`） | ✅ 會 |
| 登錄檔寫入（環境變數） | ⚠️ 視情況，實測會寫進真實 User 層級 |
| 非系統磁碟，如 `E:\`、`D:\` | ❌ 不會 |
| `C:\Program Files\`（安裝程式提權執行時） | ❌ 不會 |

環境變數寫進真實登錄檔、檔案卻留在容器裡，是最惡劣的組合 ——
使用者看得到 `ANDROID_HOME`，但它指向一個不存在的資料夾。

### 規則

1. **開發工具鏈（SDK、runtime、toolchain）一律不裝在 `%LOCALAPPDATA%` 或使用者設定檔底下。**
   固定使用非系統磁碟的明確路徑，例如 `E:\Android\Sdk`。
2. **AI 代理不得自行安裝需要全域環境變數的開發工具。**
   代理負責產生指令，由使用者在真實 PowerShell 執行。
3. **代理 shell 內的 `flutter doctor`、`where.exe`、`Test-Path`、`adb --version` 結果，
   不得作為環境設定的驗收依據。** 環境類驗收一律由使用者在自己的終端機執行並回貼。
4. **設定與驗證必須在同一個環境完成。** 在 A 環境設定、在 B 環境驗證，等於沒驗證。
5. **搬移 / 複製 SDK 也不可由代理執行**，同樣會被重導。產生 Robocopy 指令交給使用者。

### 懷疑被重導時的交叉驗證

```powershell
# 用你以為的路徑，去 Packages 底下反查
Get-ChildItem 'C:\Users\User\AppData\Local\Packages' -Directory |
  ForEach-Object { Join-Path $_.FullName 'LocalCache\Local\Android\Sdk' } |
  Where-Object { Test-Path $_ }
```

找得到東西，就代表被重導了。

### 本專案實際案例（2026-09-16）

Android SDK 被裝進 `Claude_pzs8sxrjxfjjc\LocalCache\Local\Android\Sdk`（2.8 GB）。
代理端 `flutter doctor` 全綠、`adb` 正常、`flutter build apk --debug` 成功產出 APK，
但使用者端 `flutter doctor` 顯示 `Android SDK not found at this location`。

同一台機器另有 `OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Android\Sdk`（0.55 GB），成因相同。

修正方式：用 Robocopy 把容器內的 SDK 複製到 `E:\Android\Sdk`（由使用者執行），
再更新 `ANDROID_HOME`、User PATH 與 `flutter config --android-sdk`。

**本專案的正式 Android SDK 路徑固定為 `E:\Android\Sdk`，不得再使用 `%LOCALAPPDATA%` 或任何容器內路徑。**
