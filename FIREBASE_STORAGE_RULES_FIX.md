# Firebase Storage Rules 修復指南

**日期**: 2025-12-18
**問題**: User does not have permission to access Storage
**狀態**: 需要修改 Security Rules

---

## ✅ 好消息

Firebase 匿名登錄已成功！Authentication 設置正確。

---

## ❌ 目前問題

```
❌ Metadata 下載失敗: User does not have permission to access
   gs://hkbusapp-e34a7.firebasestorage.app/bus_data_metadata.json
```

**原因**: Firebase Storage Security Rules 阻擋了已認證用戶的讀取權限。

---

## 🔧 修復步驟

### Step 1: 登入 Firebase Console

1. 前往 https://console.firebase.google.com
2. 選擇專案：`hkbusapp-e34a7`

---

### Step 2: 進入 Storage Rules

1. 左側選單 → **Storage**
2. 頂部選擇 **Rules** 標籤

---

### Step 3: 檢查目前的 Rules

你可能會看到類似這樣的規則（太嚴格）：

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if false;  // 阻擋所有訪問
    }
  }
}
```

或者：

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid != null;  // 需要正式用戶
    }
  }
}
```

---

### Step 4: 替換為正確的 Rules

**刪除現有規則，替換為以下內容**：

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // 允許已認證的 iOS App 讀取巴士數據
    match /bus_data.json {
      allow read: if request.auth != null
                  && request.auth.token.firebase.sign_in_provider != null;
      allow write: if false;  // 只有 Admin SDK 可寫入
    }

    // 允許讀取元數據
    match /bus_data_metadata.json {
      allow read: if request.auth != null
                  && request.auth.token.firebase.sign_in_provider != null;
      allow write: if false;  // 只有 Admin SDK 可寫入
    }

    // 其他文件拒絕訪問
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

### Step 5: 發布 Rules

1. 點擊右上角的 **Publish** 按鈕
2. 確認發布
3. 等待幾秒鐘讓規則生效

---

### Step 6: 驗證檔案存在

在 Storage 中確認以下檔案已上傳：

1. 左側選單 → **Storage** → **Files** 標籤
2. 檢查是否存在：
   - [ ] `bus_data.json` (約 17-18 MB)
   - [ ] `bus_data_metadata.json` (約 2 KB)

**如果檔案不存在**，你需要先上傳（使用 `manual_upload_firebase.py`）。

---

## 🔍 Rules 解釋

### 為什麼這樣設置？

```javascript
allow read: if request.auth != null
            && request.auth.token.firebase.sign_in_provider != null;
```

**解釋**：
- `request.auth != null` → 用戶必須已認證（包括匿名用戶）
- `request.auth.token.firebase.sign_in_provider != null` → 確認是通過 Firebase SDK 認證（不是直接 URL）

### 安全性

- ✅ **允許**: 你的 iOS App 通過匿名認證下載
- ❌ **阻擋**: 瀏覽器直接訪問 URL
- ❌ **阻擋**: 未認證的請求
- ❌ **阻擋**: 所有寫入操作（只有 Python Admin SDK 可寫入）

---

## 📱 重新測試

完成 Rules 修改後：

### 方法 1: 在 Xcode 重新運行

```bash
open "/Users/davidwong/Documents/App Development/busApp/HKBusApp/HKBusApp.xcworkspace"
```

1. 點擊 ▶️ 運行
2. 查看 Console 日誌

---

### 方法 2: 強制檢查更新（測試用）

如果你想立即測試，可以臨時修改 `SceneDelegate.swift`：

**找到第 25 行**：
```swift
FirebaseDataManager.shared.checkForUpdates { result in
```

**臨時改為**（測試完記得改回來）：
```swift
FirebaseDataManager.shared.checkForUpdates(forceCheck: true) { result in
```

這樣每次啟動都會檢查更新。

---

## 預期結果

### 成功的日誌：

```
✅ Firebase initialized
✅ Firebase 匿名登錄成功
📋 正在下載 metadata...
✅ Metadata 下載成功
📡 遠程版本: 1733845440
📱 本地版本: 0
🆕 發現新版本！
[彈出對話框] "發現新版本巴士數據（約 18 MB）"
```

### 如果還是失敗：

檢查：
1. Rules 是否正確發布
2. `bus_data_metadata.json` 是否存在於 Storage 中
3. 檔案名稱是否完全正確（包括 `.json` 後綴）

---

## 🚨 常見錯誤

### 錯誤 1: 檔案不存在

```
❌ Metadata 下載失敗: Object 'bus_data_metadata.json' does not exist.
```

**解決**: 使用 `manual_upload_firebase.py` 上傳檔案。

### 錯誤 2: Rules 未生效

**解決**: 等待 30 秒後重試，或重新發布 Rules。

### 錯誤 3: 還是權限錯誤

**解決**: 檢查 Rules 語法是否正確，確認沒有多餘的逗號或括號。

---

## 📊 檢查清單

完成以下步驟：

- [ ] 登入 Firebase Console
- [ ] 進入 Storage → Rules
- [ ] 替換為正確的 Security Rules
- [ ] 點擊 Publish 發布
- [ ] 檢查 Files 標籤，確認檔案存在
- [ ] 在 Xcode 重新運行 App
- [ ] 查看 Console 日誌確認成功

---

**報告版本**: v1.0
**最後更新**: 2025-12-18
**狀態**: 等待 Storage Rules 修改
