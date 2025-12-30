# 特別巴士路線 UX 設計方案

## 用戶需求
處理特別車路線（如 796X、796P、796R、796S）的顯示方式，提供比競品更好的 UX 體驗

## 技術分析完成 ✅

### 現況總結
**HKBusApp 當前採用「完全分離模式」：**
- 796P、796R、796S、796X 等每個變體都是獨立路線記錄
- 搜尋 "796" 會顯示 4 個獨立的結果（796P、796R、796S、796X）
- 每個路線單獨一行，附帶方向資訊
- 通過路線號字尾隱式識別特別路線類型（X=快速、P=繁忙、R=賽馬、S=特別）

### 數據結構特點
- 路線ID格式：`公司_路線號_方向`（例：CTB_796X_O）
- 每個變體有獨立的起點/終點/站點列表
- 無明確的「主路線/子路線」關係標記
- 目前 serviceType 字段為 null（未使用）

### 關鍵文件位置
- 搜尋邏輯：`SearchViewController.swift` (行 979-1048, 1275-1346)
- 本地數據管理：`LocalBusDataManager.swift` (行 295-528)
- 數據模型：`BusRoute.swift` (RouteSearchResult, DirectionInfo)
- 收藏列表：`BusListViewController.swift`

## 問題診斷總結

### 用戶反映的核心問題
1. **同號不同服務**：796X 有「常規版」和「特別班次」，路線號相同但經過的站點不同
2. **ETA 消失**：在某些站點看不到特別車的到站時間
3. **混合顯示需求**：希望在同一站點看到所有 796X（不管是常規還是特別）的 ETA 混合顯示
4. **設計約束**：不同路線號應保持分離（796P、796S、796X 是不同路線，不要分組）

### 根本原因（技術層面）

**系統完全沒有處理 KMB `serviceType` 的機制：**

1. **API 層**：`BusAPIService.swift` line 77 硬編碼 `serviceType=1`，忽略其他服務類型
2. **數據模型**：`BusRoute.swift` 和 `BusETA.swift` 都沒有 `serviceType` 字段
3. **本地數據**：`bus_data.json` 所有路線都只有 `serviceType: "1"`
4. **數據收集**：Python 腳本在生成 route ID 時丟棄了 `serviceType` 維度

**結果**：用戶只能看到 serviceType=1（常規版）的 ETA，特別班次完全被忽略。

---

## 推薦方案：分階段實施

### 階段 1：快速修復（2-3 天，立即見效）✅ 推薦優先實施

**目標**：讓用戶能看到特別班次的 ETA，無需完整數據模型重構

**核心策略**：並行 API 調用 + 混合顯示

#### 實施步驟

**唯一需修改文件**：`HKBusApp/HKBusApp/Services/BusAPIService.swift`

**變更 1：添加多 serviceType URL 生成方法**（新增，line 72 前）
```swift
private func etaURLs(for route: BusRoute) -> [URL] {
    switch route.company {
    case .CTB, .NWFB:
        guard let url = URL(string: "https://rt.data.gov.hk/v2/transport/citybus/eta/\(route.companyId)/\(route.stopId)/\(route.route)") else { return [] }
        return [url]

    case .KMB:
        // 並行查詢 serviceType 1-3（涵蓋大部分情況）
        return (1...3).compactMap { serviceType in
            URL(string: "https://data.etabus.gov.hk/v1/transport/kmb/eta/\(route.stopId)/\(route.route)/\(serviceType)")
        }
    }
}
```

**變更 2：修改 fetchETA 方法**（替換 line 100-131）
```swift
func fetchETA(for route: BusRoute, completion: @escaping (Result<[BusETA], Error>) -> Void) {
    let urls = etaURLs(for: route)
    guard !urls.isEmpty else {
        completion(.failure(APIError.invalidURL))
        return
    }

    if route.company == .KMB {
        fetchETAsFromMultipleServices(urls: urls, direction: route.direction, completion: completion)
    } else {
        fetchSingleETA(url: urls[0], direction: route.direction, completion: completion)
    }
}
```

**變更 3：新增並行查詢方法**（新增，line 131 後）
```swift
private func fetchETAsFromMultipleServices(urls: [URL], direction: String, completion: @escaping (Result<[BusETA], Error>) -> Void) {
    let group = DispatchGroup()
    var allETAs: [BusETA] = []
    var errors: [Error] = []
    let lock = NSLock()

    for url in urls {
        group.enter()
        session.dataTask(with: url) { data, response, error in
            defer { group.leave() }

            if let error = error {
                lock.lock()
                errors.append(error)
                lock.unlock()
                return
            }

            guard let data = data else { return }

            do {
                let etaResponse = try JSONDecoder().decode(BusETAResponse.self, from: data)
                let directionPrefix = direction.prefix(1).uppercased()
                let filteredETAs = etaResponse.data.filter { eta in
                    eta.dir.uppercased() == directionPrefix
                }

                lock.lock()
                allETAs.append(contentsOf: filteredETAs)
                lock.unlock()
            } catch {
                lock.lock()
                errors.append(error)
                lock.unlock()
            }
        }.resume()
    }

    group.notify(queue: .main) {
        if allETAs.isEmpty && !errors.isEmpty {
            completion(.failure(errors.first!))
        } else {
            // 按到站時間排序（混合顯示不同 serviceType）
            let sortedETAs = allETAs.sorted { eta1, eta2 in
                guard let time1 = eta1.arrivalTime, let time2 = eta2.arrivalTime else {
                    return eta1.arrivalTime != nil
                }
                return time1 < time2
            }
            completion(.success(sortedETAs))
        }
    }
}
```

**變更 4：新增單一查詢方法**（新增，用於 CTB/NWFB）
```swift
private func fetchSingleETA(url: URL, direction: String, completion: @escaping (Result<[BusETA], Error>) -> Void) {
    session.dataTask(with: url) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let data = data else {
            completion(.failure(APIError.noData))
            return
        }

        do {
            let etaResponse = try JSONDecoder().decode(BusETAResponse.self, from: data)
            let directionPrefix = direction.prefix(1).uppercased()
            let filteredETAs = etaResponse.data.filter { eta in
                eta.dir.uppercased() == directionPrefix
            }
            completion(.success(filteredETAs))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}
```

#### UI 變更
**無需變更** - 混合顯示的 ETA 按時間排序，用戶無需區分是哪種服務類型。

#### 測試計劃
1. 796X @ 雍明苑站 - 驗證能看到所有班次
2. 1 號 @ 任意站點 - 驗證 CTB 路線無破壞
3. 性能測試 - 驗證延遲 < 2.0s

---

### 階段 2：完整解決方案（1-2 週，數據模型升級）

**目標**：在數據層面正式支持 serviceType，消除架構債

#### 2.1 Python 數據收集腳本重構

**文件**：`collect_bus_data_optimized_concurrent.py`

**變更位置**：Line 263-285（KMB 路線處理）

**關鍵改動**：
```python
# 修改 route ID 包含 service_type
unique_route_id = f"KMB_{route_num}_{bound}_{service_type}"  # 原：KMB_{route_num}_{bound}

# 每個 service_type 獨立保存
if unique_route_id not in self.bus_data['routes']:
    self.bus_data['routes'][unique_route_id] = {
        'route_number': route_num,
        'company': 'KMB',
        'direction': 'inbound' if bound == 'I' else 'outbound',
        'origin_tc': route_info['orig_tc'],
        'dest_tc': route_info['dest_tc'],
        'service_type': service_type  # 保留完整資訊
    }
```

**影響**：
- `bus_data.json` 從 ~2,113 條路線增加至 ~2,500 條
- 文件大小從 17.76MB 增加至 ~20MB

#### 2.2 Swift 數據模型更新

**文件 A**：`HKBusApp/HKBusApp/Models/BusRoute.swift`（Line 101-121）
```swift
struct BusRoute: Codable, Hashable {
    let stopId: String
    let route: String
    let companyId: String
    let direction: String
    let subTitle: String
    let serviceType: String?  // 新增（可選，向後兼容）

    var uniqueId: String {
        if company == .KMB, let st = serviceType {
            return "\(companyId)_\(stopId)_\(route)_\(direction)_\(st)"
        }
        return "\(companyId)_\(stopId)_\(route)_\(direction)"
    }
}
```

**文件 B**：`HKBusApp/HKBusApp/Models/BusETA.swift`（Line 3-8）
```swift
struct BusETA: Codable {
    let eta: String?
    let dir: String
    let route: String?
    let stopId: String?
    let serviceType: String?  // 新增（用於辨識來源）

    // 原有代碼保持不變
}
```

#### 2.3 LocalBusDataManager 搜索邏輯更新

**文件**：`HKBusApp/HKBusApp/Services/LocalBusDataManager.swift`

**變更位置**：Line 395-473（`searchRoutesLocally` 方法）

**關鍵邏輯**：
- 保持按 `routeNumber` 分組（不按 serviceType 分組）
- 收集所有 serviceType 的站點數據
- 驗證時檢查至少一個 serviceType 有站點

---

### 階段 3：進階功能（可選，根據反饋決定）

1. **實時服務可用性判斷**：根據時段過濾 serviceType
2. **服務時間提示**：在路線詳情頁顯示特別班次運行時間
3. **智能標籤**：為特別班次添加視覺標籤（如 [特快]、[繁忙]）

---

## 關鍵文件清單

### 階段 1（快速修復）
- ✅ `HKBusApp/HKBusApp/Services/BusAPIService.swift` - 唯一需修改

### 階段 2（完整方案）
- `collect_bus_data_optimized_concurrent.py` - 數據收集腳本
- `HKBusApp/HKBusApp/Models/BusRoute.swift` - 路線模型
- `HKBusApp/HKBusApp/Models/BusETA.swift` - ETA 模型
- `HKBusApp/HKBusApp/Services/LocalBusDataManager.swift` - 本地數據管理
- `HKBusApp/HKBusApp/Services/BusAPIService.swift` - API 服務（使用 serviceType）

---

## 風險與緩解

### 風險 1：性能影響
- **風險**：並行查詢 3 個 serviceType 增加延遲（從 ~1.0s 增至 ~1.5s）
- **緩解**：可接受的性能損失，換取完整數據；階段 2 可優化為智能查詢

### 風險 2：API 調用失敗率
- **風險**：某些路線可能沒有 serviceType=2 或 3，導致 404 錯誤
- **緩解**：錯誤處理邏輯已忽略失敗的請求，只要有一個成功即可

### 風險 3：向後兼容性
- **風險**：舊版 App 無法讀取新的 `bus_data.json`
- **緩解**：`serviceType` 設為可選字段，舊代碼仍可運行

---

## 成功指標

- ✅ 796X @ 雍明苑站可看到完整 ETA（包括特別班次）
- ✅ API 調用成功率 > 95%
- ✅ ETA 顯示延遲 < 2.0s
- ✅ CTB/NWFB 路線無破壞性變更
- ✅ 用戶反映「看不到特別車」的問題消失

---

## 實施時間線

- **階段 1**：2-3 天（立即修復，推薦優先）
- **階段 2**：1-2 週（完整方案，技術債清理）
- **階段 3**：後期優化（根據用戶反饋決定）

---

## 推薦執行順序

1. ✅ **先實施階段 1** - 快速解決用戶痛點，驗證技術可行性
2. 📊 **收集反饋** - 觀察真實使用情況和性能表現
3. 🔧 **評估階段 2** - 如果階段 1 效果良好，進行完整重構
4. 🎨 **考慮階段 3** - 根據用戶需求決定是否需要進階功能
