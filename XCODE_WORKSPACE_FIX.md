# ⚠️ 重要：必須使用 .xcworkspace 而非 .xcodeproj

## 問題

你剛才遇到的錯誤：
```
No such module 'FirebaseStorage'
No such module 'FirebaseAuth'
```

**原因**: 打開了 `HKBusApp.xcodeproj` 而不是 `HKBusApp.xcworkspace`

---

## ✅ 正確做法

### 使用 Workspace（包含 CocoaPods）

```bash
open "/Users/davidwong/Documents/App Development/busApp/HKBusApp/HKBusApp.xcworkspace"
```

**識別方法**：
- ✅ 文件圖標：白色文件夾圖標 + "xcworkspace"
- ✅ Xcode 左側：會顯示 "Pods" 專案
- ✅ Firebase 模組：可以正確找到

---

## ❌ 錯誤做法

### 不要使用 .xcodeproj（僅限主專案）

```bash
# ❌ 錯誤！
open "/Users/davidwong/Documents/App Development/busApp/HKBusApp/HKBusApp.xcodeproj"
```

**問題**：
- ❌ 找不到 CocoaPods 安裝的 Firebase SDK
- ❌ 編譯時會出現 "No such module" 錯誤
- ❌ 左側不會顯示 "Pods" 專案

---

## 🔍 如何判斷打開的是哪個？

### 在 Xcode 中檢查：

1. **查看左側導航器**：
   - ✅ 正確：顯示 "HKBusApp" 和 "Pods" 兩個專案
   - ❌ 錯誤：只顯示 "HKBusApp" 專案

2. **查看 Xcode 標題欄**：
   - ✅ 正確：顯示 "HKBusApp - xcworkspace"
   - ❌ 錯誤：顯示 "HKBusApp - xcodeproj"

3. **嘗試編譯**：
   - ✅ 正確：可以找到 Firebase 模組
   - ❌ 錯誤：出現 "No such module 'FirebaseStorage'" 錯誤

---

## 📚 背景知識

### 為什麼需要 .xcworkspace？

當你使用 CocoaPods 安裝依賴時：

1. `pod install` 會創建：
   - `Pods.xcodeproj`（包含所有依賴）
   - `HKBusApp.xcworkspace`（包含主專案 + Pods）
   - `Podfile.lock`（依賴版本鎖定）

2. `.xcworkspace` 將兩個專案合併：
   ```
   HKBusApp.xcworkspace/
   ├── HKBusApp.xcodeproj (主專案)
   └── Pods.xcodeproj     (Firebase SDK)
   ```

3. 只有 `.xcworkspace` 能同時訪問：
   - 你的主專案代碼
   - CocoaPods 安裝的第三方庫

---

## 🚀 快速修復步驟

### 如果你打開了錯誤的文件：

1. **關閉 Xcode**：
   ```bash
   # 快捷鍵: Cmd+Q
   # 或者命令行:
   osascript -e 'tell application "Xcode" to quit'
   ```

2. **打開正確的 Workspace**：
   ```bash
   open "/Users/davidwong/Documents/App Development/busApp/HKBusApp/HKBusApp.xcworkspace"
   ```

3. **驗證**：
   - 左側導航器應該顯示 "Pods" 專案
   - 編譯時不再出現 "No such module" 錯誤

---

## 📝 記憶技巧

### 規則：安裝 CocoaPods 後，永遠使用 .xcworkspace

```
✅ 有 CocoaPods → 使用 .xcworkspace
❌ 有 CocoaPods → 使用 .xcodeproj（錯誤！）
```

### CocoaPods 安裝後的提示：

```
[!] Please close any current Xcode sessions and use
    `HKBusApp.xcworkspace` for this project from now on.
```

**翻譯**：請關閉所有 Xcode，並從現在開始使用 `.xcworkspace`

---

## 🔧 Terminal 快捷命令

```bash
# 保存到你的 .zshrc 或 .bashrc
alias xcode-workspace='open *.xcworkspace'
alias xcode-clean='rm -rf ~/Library/Developer/Xcode/DerivedData/*'
```

使用方式：
```bash
cd "/Users/davidwong/Documents/App Development/busApp/HKBusApp"
xcode-workspace  # 自動打開 .xcworkspace
```

---

## ❓ 常見問題

### Q1: 我已經打開了 .xcodeproj，需要重新開始嗎？
**A**: 不需要！只需：
1. 關閉 Xcode（Cmd+Q）
2. 打開 `.xcworkspace`
3. 重新編譯

### Q2: 如果我不小心雙擊了 .xcodeproj 怎麼辦？
**A**: 立即關閉，打開 `.xcworkspace`

### Q3: 為什麼 Finder 中雙擊會打開錯誤的文件？
**A**: Finder 可能優先打開 `.xcodeproj`。建議：
- 使用命令行：`open HKBusApp.xcworkspace`
- 或者在 Finder 中右鍵 → "Open With" → Xcode

### Q4: 我刪除了 .xcworkspace，怎麼恢復？
**A**: 重新運行 `pod install`，會自動重新生成

---

## ✅ 驗證清單

在開始編譯前，確認：

- [ ] 已關閉所有 Xcode 視窗
- [ ] 使用命令 `open HKBusApp.xcworkspace` 打開
- [ ] Xcode 左側顯示 "Pods" 專案
- [ ] 標題欄顯示 "xcworkspace"
- [ ] 編譯時沒有 "No such module" 錯誤

---

**記住**：使用 CocoaPods = 必須使用 .xcworkspace！
