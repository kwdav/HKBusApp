# Firebase 設置頁面更新提示總結

**日期**: 2025-12-18
**版本**: v0.12.2
**狀態**: ✅ 完成並編譯成功

---

## 📋 用戶需求

**原始需求**：
> "no, dont do background download. If there is new version JSON, only show hints in the setting page (under the update button)"

**實現目標**：
1. ❌ 不自動下載
2. ✅ 只檢查版本
3. ✅ 在設置頁面顯示提示
4. ✅ 提示在「更新路線資料」按鈕下方

---

## 🎯 實現方案

### 用戶體驗流程

```
App 啟動
    ↓
檢查 Firebase 版本（24小時節流）
    ↓
有新版本？
    ↙ 是          ↘ 否
發送通知         不做任何事
    ↓
設置頁面收到通知
    ↓
顯示橙色提示行
「🆕 有新版本巴士數據可供更新」
    ↓
用戶打開設置頁面
    ↓
看到提示，決定是否更新
    ↓
手動點擊「更新路線資料」
    ↓
開始下載（顯示進度）
    ↓
安裝成功，隱藏提示
```

---

## 📱 設置頁面 UI

### 無更新時（2 行）

```
┌─────────────────────────────────────────┐
│ 數據管理                                 │
├─────────────────────────────────────────┤
│ 巴士數據           數據版本: 2025-10-30 12:40 │
├─────────────────────────────────────────┤
│ 更新路線資料                         >  │
└─────────────────────────────────────────┘
```

### 有更新時（3 行）

```
┌─────────────────────────────────────────┐
│ 數據管理                                 │
├─────────────────────────────────────────┤
│ 巴士數據           數據版本: 2025-10-30 12:40 │
├─────────────────────────────────────────┤
│ 更新路線資料                         >  │
├─────────────────────────────────────────┤
│ 🆕 有新版本巴士數據可供更新              │ ← 新增（橙色背景）
└─────────────────────────────────────────┘
```

---

## 🔧 技術實現

### 1. SceneDelegate.swift 修改

**刪除的代碼**：
```swift
// ❌ 已移除所有自動下載邏輯
private func startSilentDataUpdate() { ... }
```

**保留的代碼**：
```swift
func sceneDidBecomeActive(_ scene: UIScene) {
    // 只檢查版本，不自動下載
    FirebaseDataManager.shared.checkForUpdates { result in
        switch result {
        case .success(let hasUpdate):
            if hasUpdate {
                print("🆕 發現新版本（設置頁面將顯示提示）")
                // 發送通知給設置頁面
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewVersionAvailable"),
                    object: nil
                )
            }
        case .failure(let error):
            print("⚠️ 版本檢查失敗: \(error.localizedDescription)")
        }
    }
}
```

**關鍵變化**：
- ✅ 只檢查版本
- ✅ 發送通知 "NewVersionAvailable"
- ❌ 不下載數據

---

### 2. SettingsViewController.swift 修改

#### 新增屬性

```swift
private var hasNewVersionAvailable: Bool = false
```

#### NotificationCenter 監聽

```swift
private func setupNotifications() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleNewVersionAvailable),
        name: NSNotification.Name("NewVersionAvailable"),
        object: nil
    )
}

@objc private func handleNewVersionAvailable() {
    hasNewVersionAvailable = true
    tableView.reloadData()
}
```

#### 動態行數

```swift
func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch sectionType {
    case .dataManagement:
        return hasNewVersionAvailable ? 3 : 2  // 有更新時多 1 行
    ...
    }
}
```

#### 橙色提示 Cell

```swift
if indexPath.row == 2 {
    // 只在 hasNewVersionAvailable = true 時顯示
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.textLabel?.text = "🆕 有新版本巴士數據可供更新"
    cell.textLabel?.textColor = UIColor.systemOrange
    cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
    cell.textLabel?.numberOfLines = 0
    cell.accessoryType = .none
    cell.selectionStyle = .none
    cell.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
    return cell
}
```

#### 更新按鈕邏輯

```swift
@objc private func updateRouteData() {
    let loadingAlert = UIAlertController(title: "更新中", message: "正在下載最新巴士數據...", preferredStyle: .alert)
    present(loadingAlert, animated: true)

    FirebaseDataManager.shared.downloadBusData(
        progressHandler: { progress in
            DispatchQueue.main.async {
                loadingAlert.message = "下載進度: \(Int(progress * 100))%"
            }
        },
        completion: { [weak self] result in
            switch result {
            case .success(let tempURL):
                FirebaseDataManager.shared.installDownloadedData(from: tempURL) { installResult in
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            switch installResult {
                            case .success:
                                // 隱藏提示
                                self?.hasNewVersionAvailable = false
                                self?.checkDataVersion()
                                self?.tableView.reloadData()

                                let alert = UIAlertController(
                                    title: "更新成功",
                                    message: "巴士數據已更新至最新版本",
                                    preferredStyle: .alert
                                )
                                alert.addAction(UIAlertAction(title: "確定", style: .default))
                                self?.present(alert, animated: true)
                            ...
                            }
                        }
                    }
                }
            ...
            }
        }
    )
}
```

---

## 🔍 Console 日誌

### 檢查到新版本

```
✅ Firebase initialized
✅ Firebase 匿名登錄成功
📋 正在下載 metadata...
✅ Metadata 下載成功
📡 遠程版本: 1765570893
📱 本地版本: 1761799243
🆕 發現新版本！
🆕 發現新版本（設置頁面將顯示提示）
```

### 用戶手動更新

```
[用戶點擊「更新路線資料」]
下載進度: 10%
下載進度: 20%
...
下載進度: 100%
✅ 文件校驗通過 (MD5: ...)
✅ 數據安裝成功，版本: 1765570893
🔄 數據已重新載入
```

---

## 📊 代碼統計

| 文件 | 新增 | 刪除 | 淨變化 |
|------|------|------|--------|
| SceneDelegate.swift | 13 | 30 | -17 |
| SettingsViewController.swift | 67 | 28 | +39 |
| **總計** | **80** | **58** | **+22** |

---

## ✅ 功能檢查清單

### 編譯測試
- [x] Xcode 編譯成功（BUILD SUCCEEDED）
- [x] 無編譯錯誤或警告

### 功能測試（待執行）
- [ ] App 啟動時不自動下載
- [ ] App 啟動時只檢查版本
- [ ] 有新版本時 Console 顯示提示
- [ ] 設置頁面顯示橙色提示行
- [ ] 提示在「更新路線資料」按鈕下方
- [ ] 手動點擊按鈕開始下載
- [ ] 下載進度正確顯示
- [ ] 更新成功後提示消失
- [ ] 數據版本正確更新

---

## 🎨 視覺設計

### 橙色提示行特點

- **顏色**: `UIColor.systemOrange`
- **背景**: `systemOrange.withAlphaComponent(0.1)` (10% 透明度)
- **字體**: 15pt, medium weight
- **圖標**: 🆕 emoji
- **行為**: 不可點擊（selectionStyle = .none）
- **佈局**: 多行文字支持（numberOfLines = 0）

---

## 🔄 狀態轉換

```
初始狀態: hasNewVersionAvailable = false
    ↓
收到 "NewVersionAvailable" 通知
    ↓
hasNewVersionAvailable = true
    ↓
tableView.reloadData() → 顯示橙色提示行
    ↓
用戶點擊「更新路線資料」
    ↓
下載並安裝成功
    ↓
hasNewVersionAvailable = false
    ↓
tableView.reloadData() → 隱藏橙色提示行
```

---

## 🎯 與用戶需求對比

| 需求 | 實現 | 狀態 |
|------|------|------|
| 不自動下載 | 移除所有背景下載邏輯 | ✅ |
| 只檢查版本 | 保留 checkForUpdates | ✅ |
| 設置頁面顯示提示 | 橙色提示行 | ✅ |
| 在更新按鈕下方 | row 2（按鈕是 row 1）| ✅ |
| 用戶手動更新 | 點擊按鈕觸發下載 | ✅ |

**結論**: 100% 符合用戶需求 ✅

---

## 🚀 用戶價值

### 之前的問題
1. ❌ 彈窗打斷用戶
2. ❌ 自動下載消耗流量
3. ❌ 用戶無控制權

### 現在的優勢
1. ✅ 無打擾體驗
2. ✅ 用戶完全控制何時更新
3. ✅ 清晰的視覺提示（橙色背景）
4. ✅ 只在需要時才下載
5. ✅ WiFi/流量自主選擇

---

## 📝 測試步驟

### 測試新版本提示

1. **模擬有新版本**：
   - 暫時修改 `FirebaseDataManager.swift`
   - 在 `checkForUpdates` 中強制返回 `hasUpdate = true`

2. **運行 App**：
   ```bash
   open HKBusApp.xcworkspace
   ```

3. **驗證提示顯示**：
   - 啟動 App
   - 進入設置頁面
   - 確認看到橙色提示行

4. **測試手動更新**：
   - 點擊「更新路線資料」
   - 確認顯示下載進度
   - 確認更新成功後提示消失

---

## 🎉 完成狀態

**v0.12.2 成功實現設置頁面更新提示**：
- ✅ 移除自動下載
- ✅ 只檢查版本
- ✅ 設置頁面顯示橙色提示
- ✅ 用戶手動控制更新
- ✅ 編譯成功（BUILD SUCCEEDED）
- ✅ 代碼簡潔清晰

**下一步**: 在 Xcode 運行測試，驗證提示顯示和手動更新流程。

---

**報告版本**: v1.0
**最後更新**: 2025-12-18
**狀態**: ✅ 完成開發，等待測試
