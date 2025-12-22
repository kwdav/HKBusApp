# ✅ 正確的命令

## 問題
你在 `busApp` 目錄執行了 `pod install`，但 Podfile 在 `busApp/HKBusApp` 子目錄中。

---

## 解決方案

### 正確的命令順序

```bash
# 1. 進入正確的目錄（HKBusApp 子目錄）
cd "/Users/davidwong/Documents/App Development/busApp/HKBusApp"

# 2. 驗證 Podfile 存在
ls -la Podfile

# 3. 安裝 CocoaPods 依賴
pod install

# 4. 打開 Workspace（不是 xcodeproj）
open HKBusApp.xcworkspace
```

---

## 預期輸出

### pod install 成功時會顯示：

```
Analyzing dependencies
Downloading dependencies
Installing Firebase (10.x.x)
Installing FirebaseAuth (10.x.x)
Installing FirebaseCore (10.x.x)
Installing FirebaseStorage (10.x.x)
...
Generating Pods project
Integrating client project

[!] Please close any current Xcode sessions and use `HKBusApp.xcworkspace` for this project from now on.

Pod installation complete! There are X dependencies from the Podfile and X total pods installed.
```

### 會生成以下文件：
- `Pods/` 目錄
- `HKBusApp.xcworkspace` 文件
- `Podfile.lock` 文件

---

## 快速複製貼上版本

```bash
cd "/Users/davidwong/Documents/App Development/busApp/HKBusApp" && pod install
```

---

執行成功後，使用這個命令打開專案：

```bash
open "/Users/davidwong/Documents/App Development/busApp/HKBusApp/HKBusApp.xcworkspace"
```

⚠️ **重要**: 必須使用 `.xcworkspace`，不是 `.xcodeproj`！
