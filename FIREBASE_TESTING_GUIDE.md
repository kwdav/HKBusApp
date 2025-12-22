# Firebase 下載驗證與安全檢查指南

**日期**: 2025-12-17
**版本**: v0.12.1
**狀態**: 準備測試

---

## 📋 快速檢查清單

### ✅ Step 1: Console 日誌驗證（5 分鐘）

**操作**:
1. 在 Xcode 中按 **Cmd+R** 運行 App
2. 打開 Console（**View → Debug Area → Activate Console**）
3. 搜尋以下日誌：

**預期日誌**:
```
✅ Firebase initialized
✅ LocalBusDataManager: Loaded bus data successfully
📊 Routes: 2090, Stops: 9223
📦 使用預置數據: Bundle/bus_data.json
⏰ 距離上次檢查不足24小時，跳過檢查
```

**檢查項目**:
- [ ] Firebase 初始化成功
- [ ] 數據載入成功
- [ ] 路線和站點數量正確
- [ ] 版本檢查運行（或跳過）

**截圖保存位置**: `測試報告/01_console_logs.png`

---

### ⚠️ Step 2: 強制下載測試（10 分鐘）

**目標**: 驗證完整的下載→驗證→安裝流程

#### 2.1 修改代碼

打開 `SceneDelegate.swift`，找到第 25 行：

**原代碼**:
```swift
FirebaseDataManager.shared.checkForUpdates { result in
```

**臨時改為**:
```swift
FirebaseDataManager.shared.checkForUpdates(forceCheck: true) { result in
```

#### 2.2 運行測試

1. 保存修改
2. 按 **Cmd+R** 重新運行 App
3. 應該立即彈出對話框：「發現新版本巴士數據」

#### 2.3 觀察下載過程

點擊「立即更新」，觀察：
- [ ] 顯示進度對話框「正在下載數據」
- [ ] 進度從 0% → 100%（約 5-10 秒）
- [ ] 顯示「更新成功」對話框

#### 2.4 驗證日誌

Console 應該顯示：
```
📡 遠程版本: 1733845440
📱 本地版本: 0
🆕 發現新版本！
[下載進度] 10%, 20%, ..., 100%
✅ 文件校驗通過 (MD5: ...)
✅ 數據安裝成功，版本: 1733845440
🔄 數據已重新載入
📦 使用已下載的數據: Documents/bus_data.json
```

#### 2.5 恢復代碼

測試完成後，**務必恢復原代碼**：
```swift
FirebaseDataManager.shared.checkForUpdates { result in
```

**檢查項目**:
- [ ] 更新提示彈出
- [ ] 下載進度正確顯示
- [ ] MD5 校驗通過
- [ ] 數據成功安裝
- [ ] 數據來源切換到 Documents

**截圖保存**:
- `測試報告/02_update_dialog.png`
- `測試報告/03_download_progress.png`
- `測試報告/04_success_message.png`
- `測試報告/05_console_download.png`

---

### 🔒 Step 3: Firebase Security Rules 檢查（5 分鐘）

#### 3.1 登入 Firebase Console

1. 打開瀏覽器
2. 前往 https://console.firebase.google.com
3. 選擇你的專案（hkbusapp-xxxxx）

#### 3.2 檢查 Storage Rules

1. 左側選單 → **Storage**
2. 頂部選擇 **Rules**
3. 確認規則如下：

**正確的規則**:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // 允許已認證的 iOS App 讀取巴士數據
    match /bus_data.json {
      allow read: if request.auth != null
                  && request.auth.token.firebase.sign_in_provider != null;
      allow write: if false;
    }

    // 允許讀取元數據
    match /bus_data_metadata.json {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // 其他文件拒絕訪問
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

#### 3.3 測試瀏覽器直接訪問

1. Storage → Files
2. 點擊 `bus_data.json`
3. 複製 **Access token** 下方的 URL
4. 在**無痕模式**瀏覽器中打開該 URL
5. **預期**: 應顯示 403 Forbidden 錯誤

**檢查項目**:
- [ ] Storage Rules 正確設置
- [ ] `allow write: if false` 確保只讀
- [ ] 瀏覽器直接訪問被拒絕

**截圖保存**:
- `測試報告/06_firebase_rules.png`
- `測試報告/07_browser_403.png`

---

### 🔐 Step 4: 敏感資料檢查（已完成 ✅）

**檢查結果**:
```
✅ .env - 在 .gitignore 中
✅ *service-account*.json - 在 .gitignore 中
✅ GoogleService-Info.plist - 在 .gitignore 中
✅ hkbusapp-service-account.json - 在 .gitignore 中
✅ Git 歷史中無敏感檔案
```

**結論**: 敏感資料保護正確 ✅

---

### 🌐 Step 5: 錯誤處理測試（10 分鐘）

#### 5.1 飛行模式測試

**步驟**:
1. Mac 開啟飛行模式（或關閉 WiFi）
2. 在 Xcode 中運行 App
3. 在 `SceneDelegate.swift` 中臨時啟用 `forceCheck: true`
4. 重新運行

**預期**:
- Console 顯示：`❌ Firebase 匿名登錄失敗: ...`
- App 不會崩潰
- 靜默失敗，不打擾用戶

#### 5.2 網絡中斷測試

**步驟**:
1. 啟動下載測試（Step 2）
2. 下載到 50% 時關閉 WiFi
3. 觀察行為

**預期**:
- 顯示錯誤訊息「更新失敗」
- Console 顯示錯誤日誌
- App 不會崩潰

**檢查項目**:
- [ ] 無網絡時不崩潰
- [ ] 下載中斷時顯示錯誤
- [ ] 錯誤訊息清晰

**截圖保存**:
- `測試報告/08_network_error.png`

---

### 📊 Step 6: 創建測試報告（5 分鐘）

使用以下模板記錄結果：

---

# Firebase 下載測試報告

**測試日期**: 2025-12-17
**測試人員**: David Wong
**App 版本**: v0.12.1
**測試環境**: Xcode Simulator (iPhone 15 Pro)

---

## 1. Firebase 初始化

**結果**: ✅ 成功 / ❌ 失敗

**日誌**:
```
[貼上 Console 截圖或文字]
```

---

## 2. 版本檢查

**結果**: ✅ 成功 / ❌ 失敗

**遠程版本**: 1733845440
**本地版本**: 0

**日誌**:
```
[貼上日誌]
```

---

## 3. 下載測試

**結果**: ✅ 成功 / ❌ 失敗

**下載時間**: X 秒
**文件大小**: 17.76 MB

**進度追蹤**: 0% → 10% → ... → 100%

**日誌**:
```
[貼上日誌]
```

---

## 4. MD5 校驗

**結果**: ✅ 通過 / ❌ 失敗

**MD5 Checksum**: [從日誌複製]

**日誌**:
```
✅ 文件校驗通過 (MD5: ...)
```

---

## 5. 安全檢查

- [x] Firebase Security Rules 正確設置
- [x] 敏感檔案未洩露
- [x] 瀏覽器直接訪問被拒絕
- [ ] 錯誤處理正常

---

## 6. 數據來源切換

**測試步驟**:
1. 首次運行：使用 Bundle 數據
2. 下載後：使用 Documents 數據
3. 刪除 Documents：降級回 Bundle

**結果**: ✅ 通過 / ❌ 失敗

---

## 發現的問題

1. [列出問題]
2. [列出問題]

---

## 建議

1. [列出建議]
2. [列出建議]

---

## 總結

**整體評分**: ⭐⭐⭐⭐⭐ (5/5)

**是否可以發布**: ✅ 是 / ❌ 否

**備註**: [其他說明]

---

## 附件

- `01_console_logs.png` - Console 日誌截圖
- `02_update_dialog.png` - 更新對話框
- `03_download_progress.png` - 下載進度
- `04_success_message.png` - 成功訊息
- `05_console_download.png` - 下載日誌
- `06_firebase_rules.png` - Firebase Rules
- `07_browser_403.png` - 瀏覽器 403 錯誤
- `08_network_error.png` - 網絡錯誤處理

---

**測試完成日期**: 2025-12-17
**簽名**: David Wong

---

## 快速命令參考

### 查看 Documents 目錄中的數據
```bash
ls -lh ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/bus_data.json
```

### 刪除下載的數據（測試降級）
```bash
rm -f ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents/bus_data.json
```

### 查看 UserDefaults 中的版本
```bash
defaults read com.hkbusapp.HKBusApp com.hkbusapp.localBusDataVersion 2>/dev/null || echo "未設置"
```

### 查看上次檢查時間
```bash
defaults read com.hkbusapp.HKBusApp com.hkbusapp.lastVersionCheckTime 2>/dev/null || echo "未設置"
```

---

## 注意事項

1. **Step 2 測試後務必恢復代碼**（移除 `forceCheck: true`）
2. **截圖要清晰**，確保日誌可讀
3. **測試時關閉其他 App** 避免干擾
4. **測試完成後重啟 Xcode** 確保乾淨環境

---

**祝測試順利！** 🎉
