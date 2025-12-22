# Testing Guide - Python Data Collection & Firebase Upload

本文檔說明如何測試新增強的 Python 數據收集和 Firebase 上傳功能。

---

## 前置要求

### 1. 安裝 Python 依賴

```bash
pip3 install requests firebase-admin python-dotenv
```

或使用 requirements.txt:

```bash
pip3 install -r requirements.txt
```

### 2. 配置環境變數

複製 `.env.example` 到 `.env` 並填入實際值：

```bash
cp .env.example .env
nano .env  # 或使用其他編輯器
```

需要配置的變數：
```env
FIREBASE_SERVICE_ACCOUNT_PATH=/path/to/your-service-account.json
FIREBASE_STORAGE_BUCKET=your-project-id.appspot.com
OUTPUT_DIRECTORY=./output
LOG_DIRECTORY=./logs
```

**注意**:
- `FIREBASE_SERVICE_ACCOUNT_PATH` 和 `FIREBASE_STORAGE_BUCKET` 僅在需要 Firebase 上傳時必須
- 本地測試可以先不配置 Firebase，腳本會自動跳過上傳步驟

---

## 階段一測試：增強的數據收集與驗證

### 測試 1: 完整數據收集（無 Firebase）

```bash
cd "/Users/davidwong/Documents/App Development/busApp"
python3 collect_bus_data_optimized_concurrent.py
```

**預期結果**:
```
🚀 Hong Kong Bus Data Collection with Firebase Upload
⚡ KMB: Batch API + CTB: Concurrent + Firebase Storage
====================================================================

⚠️ Firebase libraries not installed. Data will be saved locally only.

==================================================
✅ Found XXXX KMB routes
✅ KMB Complete: XXXX routes processed in XX.XXs

==================================================
✅ Found XXXX CTB routes
📊 Processing XXXX route directions with ThreadPool...
✅ CTB Complete: XXXX routes processed in XXX.XXs

==================================================
🔄 Creating stop-to-routes mapping...
✅ Created mappings for XXXX stops

==================================================
🔍 Validating collected data with enhanced checks...
📄 Validation report saved: ./output/validation_report.json
✅ Data validation PASSED
   Routes: X,XXX
   Stops: X,XXX
   Version: XXXXXXXXXX
   Warnings: X

==================================================
ℹ️  No existing data file to backup

==================================================
📊 Finalizing data...
💾 Saving to ./output/bus_data.json...
✅ Saved in X.XXs
📁 File: XX,XXX,XXX bytes (XX.XX MB)
📂 Location: ./output/bus_data.json

==================================================
📋 Generating metadata file...
✅ Metadata generated: ./output/bus_data_metadata.json
   MD5: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   SHA256: xxxxxxxxxxxxxxxx...
   File size: XX,XXX,XXX bytes (XX.XX MB)

⚠️ Skipping Firebase upload (not configured)

====================================================================
🎉 Collection Complete in XXX.XX seconds!
📄 Local file: ./output/bus_data.json
✅ Ready for iOS app integration!
```

**驗證檢查點**:
- [ ] 路線數量 ≥ 2000
- [ ] 站點數量 ≥ 9000
- [ ] 生成了 `validation_report.json`
- [ ] 生成了 `bus_data_metadata.json`
- [ ] 驗證報告狀態為 "PASS"
- [ ] 所有 7 項檢查均為 "PASS" 或 "WARN"

---

### 測試 2: 驗證報告內容

```bash
cat output/validation_report.json | python3 -m json.tool
```

**預期結構**:
```json
{
  "validation_time": "2025-12-12T...",
  "status": "PASS",
  "checks": {
    "minimum_routes": {"expected": 1500, "actual": 2091, "status": "PASS"},
    "minimum_stops": {"expected": 5000, "actual": 9232, "status": "PASS"},
    "required_fields": {"missing_count": 0, "status": "PASS"},
    "orphaned_routes": {"count": 0, "status": "PASS"},
    "coordinate_validity": {"invalid_count": 0, "status": "PASS"},
    "stop_route_consistency": {"orphaned_stops": 0, "status": "PASS"},
    "direction_consistency": {"invalid_count": 0, "status": "PASS"},
    "company_validity": {"invalid_count": 0, "status": "PASS"}
  },
  "warnings": [],
  "errors": []
}
```

---

### 測試 3: Metadata 內容

```bash
cat output/bus_data_metadata.json | python3 -m json.tool
```

**預期結構**:
```json
{
  "version": 1761795570,
  "generated_at": "2025-12-12T...",
  "file_size_bytes": 18623456,
  "md5_checksum": "a1b2c3d4e5f6...",
  "sha256_checksum": "x1y2z3...",
  "summary": {
    "total_routes": 2091,
    "total_stops": 9232,
    "total_mappings": 127000,
    "companies": ["KMB", "CTB", "NWFB"]
  },
  "download_url": "gs://your-bucket.appspot.com/bus_data.json"
}
```

---

### 測試 4: 自動備份機制

第一次運行後，再次運行腳本：

```bash
python3 collect_bus_data_optimized_concurrent.py
```

**預期結果**:
```
==================================================
💾 Backup created: ./output/backup/bus_data_20251212_143000.json
✅ Backup complete (keeping 1 backups)
```

檢查備份目錄：
```bash
ls -lh output/backup/
```

運行 8 次以上後，驗證只保留 7 個備份：
```bash
# 應該只看到最近 7 個備份文件
ls -1 output/backup/ | wc -l  # 應輸出: 7
```

---

## 階段二測試：Firebase 手動上傳

**前提**: 必須先完成 Firebase 設置（見 `FIREBASE_SETUP.md`）並配置 `.env` 文件。

### 測試 5: 環境驗證

```bash
python3 manual_upload_firebase.py
```

**如果環境未配置，預期錯誤**:
```
❌ Environment configuration errors:
   - FIREBASE_SERVICE_ACCOUNT_PATH not set in .env
   - FIREBASE_STORAGE_BUCKET not set in .env
```

**修復**: 編輯 `.env` 文件並填入正確的值。

---

### 測試 6: 手動上傳到 Firebase

配置好 `.env` 後：

```bash
python3 manual_upload_firebase.py
```

**預期成功輸出**:
```
======================================================================
🔥 HKBusApp - Manual Firebase Upload
======================================================================

📂 Data file: ./output/bus_data.json

✅ Metadata file exists and matches: ./output/bus_data_metadata.json

✅ Firebase initialized: your-project.appspot.com

📤 Uploading bus_data.json...
✅ Uploaded: bus_data.json (18,623,456 bytes / 17.76 MB)

📤 Uploading bus_data_metadata.json...
✅ Uploaded: bus_data_metadata.json (523 bytes / 0.00 MB)

======================================================================
🎉 Upload Complete!

📊 Upload Summary:
   Version: 1761795570
   Generated: 2025-12-12T14:30:00.123456
   File size: 18,623,456 bytes
   MD5: a1b2c3d4e5f6...
   Routes: 2,091
   Stops: 9,232

☁️  Firebase URL: gs://your-project.appspot.com/bus_data.json
✅ Ready for iOS app download!
======================================================================
```

---

### 測試 7: 驗證 Firebase Storage

1. 打開 [Firebase Console](https://console.firebase.google.com/)
2. 選擇你的專案
3. 進入 **Storage**
4. 確認看到兩個文件：
   - `bus_data.json` (~18 MB)
   - `bus_data_metadata.json` (~0.5 KB)
5. 點擊文件可查看元數據（metadata），確認包含：
   - `version`
   - `generated_at`
   - `total_routes`
   - `total_stops`

---

## 常見問題排查

### 問題 1: 數據收集失敗

**症狀**: 腳本在 KMB 或 CTB 階段卡住或失敗

**排查步驟**:
```bash
# 測試 API 連接
curl -I https://data.etabus.gov.hk/v1/transport/kmb/route
curl -I https://rt.data.gov.hk/v2/transport/citybus/route/CTB
```

**可能原因**:
- 網絡連接問題
- 政府 API 暫時不可用
- API 速率限制

**解決方案**: 稍後重試

---

### 問題 2: 驗證失敗

**症狀**: 驗證報告顯示 "FAIL"

**排查步驟**:
```bash
# 查看詳細錯誤
cat output/validation_report.json | grep -A 10 '"errors"'
```

**常見原因**:
- 數據量不足（routes < 1500 或 stops < 5000）
- 坐標無效（NaN/Infinity/0.0）
- 必要欄位缺失

**解決方案**:
- 檢查 API 是否返回完整數據
- 重新運行數據收集
- 查看 `logs/` 目錄中的詳細日誌

---

### 問題 3: Firebase 上傳失敗

**症狀**: "Permission denied" 或 "Invalid credentials"

**排查步驟**:
```bash
# 檢查服務帳戶文件是否存在
ls -l /path/to/your-service-account.json

# 驗證 JSON 格式
python3 -c "import json; json.load(open('/path/to/your-service-account.json'))"

# 檢查環境變數
echo $FIREBASE_SERVICE_ACCOUNT_PATH
echo $FIREBASE_STORAGE_BUCKET
```

**可能原因**:
- 服務帳戶文件路徑錯誤
- JSON 文件損壞
- Firebase Storage 未啟用
- Storage bucket 名稱錯誤

**解決方案**:
1. 重新下載服務帳戶密鑰
2. 確認 `.env` 文件中的路徑正確
3. 確認 Firebase Storage 已啟用（見 `FIREBASE_SETUP.md`）

---

### 問題 4: Metadata 校驗不匹配

**症狀**: iOS app 下載後顯示文件損壞

**排查步驟**:
```bash
# 本地驗證 MD5
md5sum output/bus_data.json
# 對比 metadata 中的 md5_checksum
cat output/bus_data_metadata.json | grep md5_checksum
```

**解決方案**:
- 如果不匹配，重新運行 `python3 collect_bus_data_optimized_concurrent.py`
- 如果匹配，問題可能在 Firebase 傳輸過程，重新上傳

---

## 效能基準

**預期執行時間** (在正常網絡條件下):

| 階段 | 時間 |
|------|------|
| KMB 數據收集 | 5-10 秒 |
| CTB 數據收集 | 3-5 分鐘 |
| 反向映射 | < 1 秒 |
| 驗證 | < 1 秒 |
| 保存 | 1-2 秒 |
| Metadata 生成 | < 1 秒 |
| **總計** | **4-6 分鐘** |

**Firebase 上傳時間**:
- `bus_data.json` (18 MB): 10-30 秒（取決於上傳速度）
- `bus_data_metadata.json` (0.5 KB): < 1 秒

---

## 下一步

完成所有測試後：

1. ✅ **階段一完成**: Python 數據收集與驗證功能正常
2. ✅ **階段二完成**: Firebase 手動上傳流程正常
3. 📱 **階段三**: 實施 iOS App 智能下載機制（見計劃文件）
4. 📊 **階段四**: 整合 Google Analytics
5. 🤖 **階段五**: 自動化 NAS Cron 作業（App 上線後）

---

## 附錄：測試清單

### Python 數據收集測試
- [ ] 語法檢查通過（`python3 -m py_compile`）
- [ ] 完整數據收集成功
- [ ] 路線數量 ≥ 2000
- [ ] 站點數量 ≥ 9000
- [ ] 驗證報告生成（`validation_report.json`）
- [ ] 驗證狀態為 "PASS"
- [ ] 所有檢查項目正常
- [ ] Metadata 文件生成（`bus_data_metadata.json`）
- [ ] MD5 和 SHA256 校驗碼正確
- [ ] 自動備份機制正常
- [ ] 備份數量限制為 7 個

### Firebase 上傳測試
- [ ] 環境變數配置正確
- [ ] `manual_upload_firebase.py` 語法檢查通過
- [ ] Firebase 初始化成功
- [ ] `bus_data.json` 上傳成功
- [ ] `bus_data_metadata.json` 上傳成功
- [ ] Firebase Console 顯示兩個文件
- [ ] 文件大小正確
- [ ] Blob metadata 設置正確

### 日誌與輸出測試
- [ ] 日誌文件生成（`logs/bus_data_collection_*.log`）
- [ ] 日誌包含詳細步驟信息
- [ ] 錯誤信息清晰易懂
- [ ] 輸出格式一致且易讀

---

**測試完成時間**: ____年____月____日

**測試人員**: ________________

**備註**: ________________________________________________
