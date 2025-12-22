# 階段三安裝指南 - Firebase 依賴設置

**日期**: 2025-12-13
**狀態**: 需要手動操作

---

## ⚠️ 需要手動完成的步驟

由於 CocoaPods 安裝需要管理員權限，以下步驟需要你手動在 Terminal 中執行。

---

## 步驟 1: 安裝 CocoaPods

### 方法 A: 使用 Homebrew（推薦）

```bash
# 如果已安裝 Homebrew
brew install cocoapods
```

### 方法 B: 使用 RubyGems

```bash
# 需要輸入密碼
sudo gem install cocoapods
```

### 驗證安裝

```bash
pod --version
# 應該顯示版本號，例如: 1.12.1
```

---

## 步驟 2: 安裝 Firebase 依賴

```bash
# 進入 Xcode 專案目錄
cd "/Users/davidwong/Documents/App Development/busApp/HKBusApp"

# 安裝 Pods（首次運行約需 2-5 分鐘）
pod install
```

### 預期輸出

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
```

---

## 步驟 3: 添加 GoogleService-Info.plist 到 Xcode

### 檔案位置

```
/Users/davidwong/Documents/App Development/busApp/GoogleService-Info.plist
```

✅ 此檔案已存在

### 操作步驟

1. **打開 Xcode Workspace**（不是 .xcodeproj）

   ```bash
   open "/Users/davidwong/Documents/App Development/busApp/HKBusApp/HKBusApp.xcworkspace"
   ```

2. **拖動檔案到專案**
   - 在 Xcode 左側專案導航器中
   - 找到 `HKBusApp` 資料夾（與 `AppDelegate.swift` 同層）
   - 將 `GoogleService-Info.plist` 拖入

3. **確認設置**
   - ✅ 勾選 "Copy items if needed"
   - ✅ 勾選 "Add to targets: HKBusApp"
   - 點擊 "Finish"

4. **驗證**
   - 專案導航器應該顯示 `GoogleService-Info.plist`
   - 選中檔案，右側 Inspector 應顯示 Target Membership: HKBusApp ✓

---

## 步驟 4: 編譯並測試

### A. 編譯專案

```bash
# 使用 xcodebuild 編譯
xcodebuild -workspace HKBusApp.xcworkspace \
           -scheme HKBusApp \
           -configuration Debug \
           -sdk iphonesimulator \
           clean build
```

### B. 運行模擬器測試

**啟動模擬器**:
```bash
# 列出可用模擬器
xcrun simctl list devices available

# 啟動指定模擬器（例如 iPhone 15 Pro）
open -a Simulator --args -CurrentDeviceUDID <DEVICE_UDID>
```

**安裝並運行 App**:
```bash
# 編譯並運行
xcodebuild -workspace HKBusApp.xcworkspace \
           -scheme HKBusApp \
           -configuration Debug \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           clean build
```

---

## 步驟 5: 驗證 Firebase 初始化

### 預期日誌輸出

啟動 App 後，Xcode Console 應該顯示：

```
✅ Firebase initialized
⏰ 距離上次檢查不足24小時，跳過
# 或者
📡 遠程版本: 1733845440
📱 本地版本: 1733845440
✅ 已是最新版本
```

### 如果看到錯誤

**錯誤 1: "FirebaseApp.configure() must be called before using Firebase"**
- 檢查 `GoogleService-Info.plist` 是否正確添加到專案
- 確認檔案在 Bundle Resources 中

**錯誤 2: "No such module 'FirebaseCore'"**
- 確認已運行 `pod install`
- 確認使用 `.xcworkspace` 而非 `.xcodeproj`

**錯誤 3: 版本檢查失敗**
- 檢查網絡連接
- 檢查 Firebase Storage 中是否有 `bus_data_metadata.json`

---

## 步驟 6: 測試數據更新流程

### 場景 1: 強制觸發更新提示

**修改版本號**（臨時測試）:

在 `SceneDelegate.swift` 的 `sceneDidBecomeActive` 中：

```swift
// 臨時強制檢查
FirebaseDataManager.shared.checkForUpdates(forceCheck: true) { result in
    // ...
}
```

**預期行為**:
1. App 啟動後彈出「發現新版本巴士數據」對話框
2. 點擊「立即更新」
3. 顯示下載進度 0% → 100%
4. 顯示「更新成功」

### 場景 2: 驗證數據來源

**查看日誌**:

```
📦 使用已下載的數據: Documents/bus_data.json
# 或者
📦 使用預置數據: Bundle/bus_data.json
```

### 場景 3: 驗證 24 小時節流

**重複啟動 App**:
- 第一次啟動: 檢查版本
- 24 小時內再次啟動: 「⏰ 距離上次檢查不足24小時，跳過」

---

## 檔案清單

### 階段三新增/修改的檔案

| 檔案 | 狀態 | 位置 |
|-----|------|------|
| `FirebaseDataManager.swift` | ✅ 新增 | `HKBusApp/Services/` |
| `LocalBusDataManager.swift` | ✅ 修改 | `HKBusApp/Services/` |
| `SceneDelegate.swift` | ✅ 修改 | `HKBusApp/` |
| `AppDelegate.swift` | ✅ 修改 | `HKBusApp/` |
| `Podfile` | ✅ 新增 | `HKBusApp/` |
| `PHASE3_COMPLETION_SUMMARY.md` | ✅ 新增 | `busApp/` |
| `CHANGELOG.md` | ✅ 更新 | `busApp/` |

### 需要手動添加的檔案

| 檔案 | 狀態 | 操作 |
|-----|------|------|
| `GoogleService-Info.plist` | ✅ 存在 | 需拖入 Xcode |
| `Pods/` | ⏳ 待生成 | 運行 `pod install` |
| `HKBusApp.xcworkspace` | ⏳ 待生成 | 運行 `pod install` |

---

## 故障排查

### 問題 1: pod install 失敗

**錯誤**: "Unable to find a specification for Firebase/Core"

**解決方案**:
```bash
# 更新 CocoaPods repo
pod repo update
pod install
```

### 問題 2: Xcode 無法找到 Firebase 模組

**檢查清單**:
1. ✅ 使用 `.xcworkspace` 而非 `.xcodeproj`
2. ✅ Clean Build Folder (Cmd+Shift+K)
3. ✅ Derived Data 清除
4. ✅ 重新運行 `pod install`

### 問題 3: GoogleService-Info.plist 無法識別

**檢查清單**:
1. ✅ 檔案在專案導航器中可見
2. ✅ Target Membership 已勾選
3. ✅ Build Phases → Copy Bundle Resources 中有此檔案

---

## 成功標準

### ✅ 階段三安裝完成條件

- [ ] CocoaPods 已安裝並可運行 `pod --version`
- [ ] `pod install` 成功完成，生成 `Pods/` 目錄
- [ ] `HKBusApp.xcworkspace` 已生成
- [ ] `GoogleService-Info.plist` 已添加到 Xcode 專案
- [ ] Xcode 編譯成功（無 Firebase 相關錯誤）
- [ ] App 啟動時日誌顯示 "✅ Firebase initialized"
- [ ] 版本檢查日誌正常（顯示遠程/本地版本比對）

---

## 下一步：階段四

完成階段三測試後，將進入：

**階段四：Google Analytics 整合**
- 安裝 Firebase Analytics SDK (`pod 'Firebase/Analytics'`)
- 創建 `AnalyticsManager.swift`
- 在各頁面集成追蹤事件
- 實現隱私設置選項

---

**文檔版本**: v1.0
**最後更新**: 2025-12-13
**狀態**: 等待手動完成步驟 1-3
