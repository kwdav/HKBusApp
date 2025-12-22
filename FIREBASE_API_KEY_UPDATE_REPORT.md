# Firebase API Key 更新報告

**日期**: 2025-12-22
**狀態**: ✅ 成功更新

---

## 安全事件摘要

### 原始問題
- Firebase `GoogleService-Info.plist` 檔案被推送到公開 GitHub 倉庫
- 曝光的 API Key: `AIzaSyD7ADhEeEay70U3x7M7vvD9qa90jDRViFg`
- 發現時間: 2025-12-22 11:49 (Google Cloud 自動警報)

### 已完成的修復行動

#### 1. Git 清理（12:20 完成）
- ✅ 從 Git 追蹤中移除 `GoogleService-Info.plist`
- ✅ 使用 `git filter-branch` 從所有歷史記錄中永久刪除
- ✅ 強制推送到 GitHub（commit: 78cb036）
- ✅ 清理 Git 備份引用和垃圾回收

#### 2. API Key 更新（17:04 完成）
- ✅ 從 Firebase Console 下載新的 `GoogleService-Info.plist`
- ✅ 成功替換到專案目錄
- ✅ 舊 API Key: `AIzaSyD7ADhEeEay70U3x7M7vvD9qa90jDRViFg` ❌
- ✅ 新 API Key: `AIzaSyADM3Yd7elaYRRRoKReKLNMZPt3zYG52TA` ✅
- ✅ 檔案更新時間: 2025-12-22 17:04:45

#### 3. 保護機制強化
- ✅ `.gitignore` 已更新為 `GoogleService-Info.plist*`（包含備份檔案）
- ✅ 備份檔案已創建: `GoogleService-Info.plist.backup-20251222`
- ✅ 驗證檔案未被 Git 追蹤

---

## 驗證結果

### Git 狀態檢查
```bash
$ git ls-files | grep GoogleService-Info.plist
(無輸出 - 正確！檔案未被追蹤)

$ git status --porcelain | grep GoogleService
(無輸出 - 正確！所有 GoogleService-Info.plist 檔案被 .gitignore 排除)
```

### API Key 確認
```bash
$ grep -A 1 "API_KEY" HKBusApp/HKBusApp/GoogleService-Info.plist
<key>API_KEY</key>
<string>AIzaSyADM3Yd7elaYRRRoKReKLNMZPt3zYG52TA</string>
✅ 新的 API Key 已生效
```

### Bundle ID 確認
```bash
$ grep -A 1 "BUNDLE_ID" HKBusApp/HKBusApp/GoogleService-Info.plist
<key>BUNDLE_ID</key>
<string>com.answertick.HKBusApp</string>
✅ Bundle ID 正確
```

### 檔案時間戳記
```bash
$ stat GoogleService-Info.plist
2025-12-22 17:04:45
✅ 今天剛剛更新
```

---

## 🔴 重要：仍需完成的步驟

### 1. 設定 API Key 限制（高優先級）
**時間需求**: 10 分鐘

即使 GitHub 上的 key 已移除，舊的 API key 仍然有效。必須在 Google Cloud Console 設定限制防止濫用。

#### 操作步驟：
1. 開啟 https://console.cloud.google.com/
2. 選擇專案：**HKBusApp** (id: hkbusapp-e34a7)
3. 導航到 "APIs & Services" → "Credentials"
4. 找到舊的 iOS API Key (`AIzaSyD7ADhEeEay70U3x7M7vvD9qa90jDRViFg`)
5. **禁用或刪除舊的 API key**
6. 找到新的 iOS API Key (`AIzaSyADM3Yd7elaYRRRoKReKLNMZPt3zYG52TA`)
7. 編輯新 key 並設定：

**Application restrictions**:
- 選擇 "iOS apps"
- 添加 Bundle ID: `com.answertick.HKBusApp`

**API restrictions**:
- 選擇 "Restrict key"
- 只啟用必要服務：
  - ✅ Cloud Storage for Firebase API
  - ✅ Firebase Installations API
  - ✅ (如果使用 Analytics) Firebase Analytics API

### 2. 設定監控（建議）
**時間需求**: 15 分鐘

#### 帳單警報
1. Google Cloud Console → Billing → Budgets & alerts
2. 設定警報：
   - $5 (50% 預算)
   - $10 (100% 預算)
   - $20 (警告閾值)

#### API 使用監控
1. "APIs & Services" → "Dashboard"
2. 每天檢查異常流量（持續 2-4 週）
3. 注意：
   - 未知 IP 地址的請求
   - 不尋常的地理位置
   - 高請求量

### 3. 啟用 Firebase App Check（可選但強烈推薦）
**時間需求**: 30 分鐘

Firebase App Check 防止未授權的客戶端存取你的 Firebase 服務。

#### 設定步驟：
1. Firebase Console → Build → App Check
2. 點擊 "Get started"
3. iOS 選擇：App Attest 或 DeviceCheck
4. 為以下服務啟用 App Check：
   - Cloud Storage
   - (如使用) Realtime Database
   - (如使用) Cloud Functions

### 4. 修復 CocoaPods 依賴
**當前狀態**: App 建置失敗（Firebase 模組缺失）

```bash
cd HKBusApp
pod install
```

---

## 檔案清單

### 已建立的文件
- ✅ `FIREBASE_API_KEY_REGENERATION.md` - 完整安全指南
- ✅ `SECURITY_IMMEDIATE_ACTIONS.md` - 快速行動清單
- ✅ `FIREBASE_API_KEY_UPDATE_REPORT.md` - 本報告
- ✅ `.gitignore` - 已更新保護規則
- ✅ `GoogleService-Info.plist.backup-20251222` - 舊檔案備份

### 本地檔案狀態
- ✅ `HKBusApp/HKBusApp/GoogleService-Info.plist` - 新 API key 已生效
- ✅ 檔案未被 Git 追蹤
- ✅ 受 `.gitignore` 保護

---

## 時間軸

| 時間 | 事件 | 狀態 |
|------|------|------|
| 11:49 | Google Cloud 發送警報郵件 | ✅ |
| 12:20 | Git 歷史清理完成 | ✅ |
| 12:25 | 強制推送到 GitHub | ✅ |
| 16:39 | 用戶下載新的 GoogleService-Info.plist | ✅ |
| 17:04 | 新 API key 替換完成 | ✅ |
| 17:05 | `.gitignore` 更新完成 | ✅ |
| **待完成** | 在 Google Cloud Console 設定 API key 限制 | ⏳ |
| **待完成** | 禁用/刪除舊的 API key | ⏳ |
| **待完成** | 設定監控和警報 | ⏳ |
| **待完成** | 修復 CocoaPods 依賴 | ⏳ |

---

## 安全檢查清單

### ✅ 已完成
- [x] GoogleService-Info.plist 從 Git 移除
- [x] 從 Git 歷史中永久刪除
- [x] 強制推送到 GitHub
- [x] 下載新的 GoogleService-Info.plist
- [x] 替換專案中的檔案
- [x] 驗證新 API key 已生效
- [x] 更新 .gitignore 保護規則
- [x] 備份舊檔案
- [x] 建立安全文件和指引

### ⏳ 待完成（關鍵）
- [ ] 在 Google Cloud Console **禁用舊的 API key**
- [ ] 為新 API key 設定 iOS Bundle ID 限制
- [ ] 為新 API key 設定 API 服務限制
- [ ] 設定帳單警報
- [ ] 監控 API 使用情況（2-4 週）
- [ ] 修復 CocoaPods 依賴（`pod install`）
- [ ] 測試 App 建置和 Firebase 連接
- [ ] (可選) 啟用 Firebase App Check

---

## 風險評估

### 當前狀態：中等風險 ⚠️

**為什麼仍有風險？**
- 雖然 GitHub 上的 key 已移除，但舊 key 仍然有效
- 任何在修復前 clone 倉庫的人仍可使用舊 key
- GitHub 快取或搜索引擎可能仍有舊 key 的記錄

**降低風險的行動：**
1. **立即禁用舊 API key**（最關鍵）
2. 為新 key 設定嚴格限制
3. 監控異常使用

### 預期最終狀態：低風險 ✅

完成所有待辦事項後：
- 舊 key 已禁用，無法使用
- 新 key 只能從你的 iOS app 使用（Bundle ID 限制）
- 新 key 只能存取必要的 Firebase 服務
- 有監控機制偵測異常使用

---

## 參考文件

1. **詳細操作指引**:
   - `FIREBASE_API_KEY_REGENERATION.md`
   - `SECURITY_IMMEDIATE_ACTIONS.md`

2. **Google 官方文件**:
   - [API Key Best Practices](https://cloud.google.com/docs/authentication/api-keys)
   - [Firebase Security Rules](https://firebase.google.com/docs/rules)
   - [Firebase App Check](https://firebase.google.com/docs/app-check)

3. **緊急聯絡**:
   - Google Cloud Support: https://cloud.google.com/support
   - Firebase Support: https://firebase.google.com/support

---

## 結論

✅ **Git 清理和 API key 更新已成功完成**

🔴 **關鍵後續步驟**：
1. 在 Google Cloud Console 禁用舊的 API key
2. 為新 API key 設定 iOS Bundle ID 和 API 限制
3. 修復 CocoaPods 依賴並測試 app

**預估完成時間**：30-45 分鐘

**優先級**：高 - 請盡快完成步驟 1-2 以確保舊 API key 無法被濫用。

---

**報告生成時間**: 2025-12-22 17:05
**生成者**: Claude Code
**版本**: 1.0
