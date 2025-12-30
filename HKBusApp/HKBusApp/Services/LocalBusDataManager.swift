import Foundation
import CoreLocation
import UIKit

/**
 * LocalBusDataManager - 管理本地 JSON 巴士數據
 * 
 * 使用 Python 腳本生成的完整巴士路線和站點數據
 * 替代 hk-bus-crawling API，提供更完整和可控的數據
 */
class LocalBusDataManager {
    static let shared = LocalBusDataManager()

    private let dataFileName = "bus_data.json"
    private var busData: LocalBusData?
    private var isLoaded = false
    private var cachedSortedRoutes: [LocalRouteInfo]? // Cache sorted routes to avoid re-sorting
    private var routeSearchIndex: [String: [LocalRouteInfo]]? // 路線號 → 路線列表
    private var keyboardStateCache: [String: Set<Character>] = [:] // 前綴 → 可用字符
    private let indexQueue = DispatchQueue(label: "com.hkbusapp.routeindex", qos: .userInitiated)

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // MARK: - Data Loading

    /// Get current loaded data version (for Firebase update check)
    func getCurrentVersion() -> Int? {
        guard loadBusData(), let data = busData else { return nil }
        return data.version
    }

    func loadBusData() -> Bool {
        if isLoaded, busData != nil {
            return true
        }

        // 優先從 Documents 目錄讀取（用戶下載的最新版本）
        guard let fileURL = getBusDataURL() else {
            print("❌ LocalBusDataManager: bus_data.json not found")
            return false
        }

        do {
            let jsonData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            busData = try decoder.decode(LocalBusData.self, from: jsonData)
            isLoaded = true

            print("✅ LocalBusDataManager: Loaded bus data successfully")
            print("📁 Source: \(fileURL.path)")
            if let version = busData?.version {
                let date = Date(timeIntervalSince1970: TimeInterval(version))
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                print("📅 Data version: \(version) (\(formatter.string(from: date)))")
            }
            if let summary = busData?.summary {
                print("📊 Routes: \(summary.totalRoutes), Stops: \(summary.totalStops)")
            }

            return true
        } catch {
            print("❌ LocalBusDataManager: Failed to load bus data - \(error)")
            return false
        }
    }

    /// 重新載入數據（用於 Firebase 更新後）
    func reloadData() -> Bool {
        isLoaded = false
        busData = nil
        cachedSortedRoutes = nil
        routeSearchIndex = nil // 清空索引
        keyboardStateCache.removeAll() // 清空快取

        print("🔄 LocalBusDataManager: Reloading data...")
        let success = loadBusData()

        // 重建索引
        if success {
            buildRouteSearchIndex { }
        }

        return success
    }

    // MARK: - Private Helpers

    /// 獲取 bus_data.json 的 URL（優先從 Documents，降級到 Bundle）
    private func getBusDataURL() -> URL? {
        // 1. 先嘗試從 Documents 目錄讀取（用戶下載的最新版本）
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadedFileURL = documentsURL.appendingPathComponent("bus_data.json")

        if FileManager.default.fileExists(atPath: downloadedFileURL.path) {
            print("📦 使用已下載的數據: Documents/bus_data.json")
            return downloadedFileURL
        }

        // 2. 降級到 Bundle（初次安裝時的預置數據）
        if let bundleURL = Bundle.main.url(forResource: "bus_data", withExtension: "json") {
            print("📦 使用預置數據: Bundle/bus_data.json")
            return bundleURL
        }

        print("❌ 找不到 bus_data.json (檢查了 Documents 和 Bundle)")
        return nil
    }
    
    // MARK: - Stop Search
    
    func searchStops(query: String, location: CLLocation? = nil, limit: Int = 50) -> [StopSearchResult] {
        guard loadBusData(), let data = busData else { return [] }

        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }

        var results: [StopSearchResult] = []

        for (stopId, stopInfo) in data.stops {
            let chineseName = stopInfo.nameTC.lowercased()
            let englishName = stopInfo.nameEN.lowercased()

            if chineseName.contains(searchQuery) || englishName.contains(searchQuery) {
                let routes = getRoutesForStop(stopId: stopId)

                let result = StopSearchResult(
                    stopId: stopId,
                    nameTC: stopInfo.nameTC,
                    nameEN: stopInfo.nameEN,
                    latitude: stopInfo.latitude,
                    longitude: stopInfo.longitude,
                    routes: routes
                )
                results.append(result)

                if results.count >= limit {
                    break
                }
            }
        }

        // Sort results before returning
        if let userLocation = location {
            // Sort by distance when location available (nearest first)
            results.sort { stop1, stop2 in
                guard let lat1 = stop1.latitude, let lon1 = stop1.longitude,
                      let lat2 = stop2.latitude, let lon2 = stop2.longitude else {
                    return false
                }
                let distance1 = userLocation.distance(from: CLLocation(latitude: lat1, longitude: lon1))
                let distance2 = userLocation.distance(from: CLLocation(latitude: lat2, longitude: lon2))
                return distance1 < distance2
            }
        } else {
            // Sort alphabetically by Chinese name when no location
            results.sort { $0.nameTC < $1.nameTC }
        }

        return Array(results.prefix(limit))
    }
    
    func getNearbyStops(location: CLLocation, radiusKm: Double = 2.0, limit: Int = 15) -> [StopSearchResult] {
        guard loadBusData(), let data = busData else { return [] }
        
        var nearbyStops: [StopSearchResult] = []
        
        for (stopId, stopInfo) in data.stops {
            let stopLocation = CLLocation(latitude: stopInfo.latitude, longitude: stopInfo.longitude)
            let distance = location.distance(from: stopLocation)
            
            if distance <= radiusKm * 1000 {
                let routes = getRoutesForStop(stopId: stopId)
                
                let result = StopSearchResult(
                    stopId: stopId,
                    nameTC: stopInfo.nameTC,
                    nameEN: stopInfo.nameEN,
                    latitude: stopInfo.latitude,
                    longitude: stopInfo.longitude,
                    routes: routes
                )
                nearbyStops.append(result)
            }
        }
        
        // Sort by distance
        let sortedStops = nearbyStops.sorted { stop1, stop2 in
            let location1 = CLLocation(latitude: stop1.latitude!, longitude: stop1.longitude!)
            let location2 = CLLocation(latitude: stop2.latitude!, longitude: stop2.longitude!)
            return location.distance(from: location1) < location.distance(from: location2)
        }
        
        return Array(sortedStops.prefix(limit))
    }
    
    func getRoutesForStop(stopId: String) -> [StopRoute] {
        guard loadBusData(), let data = busData else { return [] }

        guard let stopRoutes = data.stopRoutes[stopId] else { return [] }

        return stopRoutes.map { routeInfo in
            // Get route details to determine correct destination
            let routeDetail = data.routes[routeInfo.routeId]

            // CTB/NWFB: inbound 需要對調（使用 origin 作為 destination）
            // KMB: destination 已經正確
            let shouldSwap = (routeInfo.company == "CTB" || routeInfo.company == "NWFB") && routeInfo.direction == "inbound"
            let correctDestination = shouldSwap ? (routeDetail?.originTC ?? routeInfo.destination) : routeInfo.destination

            let formattedDestination = "→ \(correctDestination)"

            return StopRoute(
                routeNumber: routeInfo.routeNumber,
                company: BusRoute.Company(rawValue: routeInfo.company) ?? .CTB,
                direction: routeInfo.direction,
                destination: formattedDestination
            )
        }
    }
    
    // MARK: - Route Information
    
    func getAllRoutes(limit: Int = 50) -> [LocalRouteInfo] {
        guard loadBusData(), let data = busData else { return [] }
        
        // Use cached sorted routes if available
        if cachedSortedRoutes == nil {
            let startTime = CFAbsoluteTimeGetCurrent()
            let allRoutes = Array(data.routes.values)
            cachedSortedRoutes = allRoutes.sorted { route1, route2 in
                // Sort by route number, then by company
                if route1.routeNumber != route2.routeNumber {
                    return route1.routeNumber.localizedStandardCompare(route2.routeNumber) == .orderedAscending
                }
                return route1.company < route2.company
            }
            let endTime = CFAbsoluteTimeGetCurrent()
            print("🔄 路線排序耗時: \(String(format: "%.3f", endTime - startTime))秒，共 \(allRoutes.count) 條路線")
        }
        
        guard let sortedRoutes = cachedSortedRoutes else { return [] }
        return Array(sortedRoutes.prefix(limit))
    }
    
    func getRouteDetail(routeId: String) -> LocalRouteInfo? {
        guard loadBusData(), let data = busData else { return nil }
        return data.routes[routeId]
    }
    
    func getRouteStops(routeId: String) -> [LocalRouteStop] {
        guard loadBusData(), let data = busData else { return [] }
        return data.routeStops[routeId] ?? []
    }
    
    // MARK: - Statistics
    
    func getDataSummary() -> LocalDataSummary? {
        guard loadBusData(), let data = busData else { return nil }
        return data.summary
    }
    
    // MARK: - Smart Keyboard Support
    
    func getAvailableRoutePrefixes() -> Set<String> {
        guard loadBusData(), let data = busData else { return [] }
        
        var prefixes: Set<String> = []
        
        for routeInfo in data.routes.values {
            let routeNumber = routeInfo.routeNumber
            
            // Add all possible prefixes for this route number
            for i in 1...routeNumber.count {
                let prefix = String(routeNumber.prefix(i))
                prefixes.insert(prefix.uppercased())
            }
        }
        
        return prefixes
    }
    
    func isValidRoutePrefix(_ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }
        return getAvailableRoutePrefixes().contains(prefix.uppercased())
    }
    
    func getPossibleNextCharacters(for currentInput: String) -> Set<Character> {
        guard loadBusData(), let data = busData else { return [] }

        let input = currentInput.uppercased()
        var possibleChars: Set<Character> = []
        var validatedRoutes: Set<String> = []  // 已檢查過的路線
        var validRoutes: Set<String> = []  // 有站點的有效路線

        for routeInfo in data.routes.values {
            let routeNumber = routeInfo.routeNumber.uppercased()

            if routeNumber.hasPrefix(input) && routeNumber.count > input.count {
                let nextCharIndex = routeNumber.index(routeNumber.startIndex, offsetBy: input.count)
                let nextChar = routeNumber[nextCharIndex]

                // 🔍 驗證：檢查該路線是否有任何方向包含站點資料
                // 避免重複驗證相同路線號（不同公司可能有相同路線號）
                let routeKey = "\(routeInfo.company)_\(routeNumber)"

                if !validatedRoutes.contains(routeKey) {
                    validatedRoutes.insert(routeKey)

                    // 檢查兩個方向：outbound (O) 和 inbound (I)
                    let outboundId = "\(routeInfo.company)_\(routeNumber)_O"
                    let inboundId = "\(routeInfo.company)_\(routeNumber)_I"

                    let hasOutbound = (data.routeStops[outboundId]?.count ?? 0) > 0
                    let hasInbound = (data.routeStops[inboundId]?.count ?? 0) > 0

                    // 只要有任一方向有站點，該路線即為有效
                    if hasOutbound || hasInbound {
                        validRoutes.insert(routeKey)
                        possibleChars.insert(nextChar)
                    }
                } else if validRoutes.contains(routeKey) {
                    // 已驗證過且確認為有效路線
                    possibleChars.insert(nextChar)
                }
                // else: 已驗證過但無站點，不加入 possibleChars
            }
        }

        return possibleChars
    }

    /// 獲取可能的下一個字符（快取版）
    func getPossibleNextCharactersCached(for currentInput: String) -> Set<Character> {
        let input = currentInput.uppercased()

        // 檢查快取
        if let cached = keyboardStateCache[input] {
            return cached
        }

        // 計算新值（呼叫現有方法）
        let possibleChars = getPossibleNextCharacters(for: currentInput)

        // 儲存快取
        keyboardStateCache[input] = possibleChars

        // 限制快取大小（最多 100 個項目）
        if keyboardStateCache.count > 100 {
            keyboardStateCache.removeAll()
        }

        return possibleChars
    }

    // MARK: - Route Search

    /// App 啟動時建立路線搜尋索引（異步）
    func buildRouteSearchIndex(completion: @escaping () -> Void) {
        indexQueue.async { [weak self] in
            guard let self = self, self.loadBusData(), let data = self.busData else {
                DispatchQueue.main.async { completion() }
                return
            }

            let startTime = CFAbsoluteTimeGetCurrent()
            var index: [String: [LocalRouteInfo]] = [:]

            // 按路線號分組（遍歷 routes 字典的 values）
            for routeInfo in data.routes.values {
                let routeNumber = routeInfo.routeNumber.uppercased()
                if index[routeNumber] == nil {
                    index[routeNumber] = []
                }
                index[routeNumber]?.append(routeInfo)
            }

            self.routeSearchIndex = index

            let endTime = CFAbsoluteTimeGetCurrent()
            let timeElapsed = String(format: "%.3f", endTime - startTime)
            print("⚡ 路線搜尋索引建立完成 - 耗時: \(timeElapsed)秒，索引 \(index.count) 個路線號")

            DispatchQueue.main.async { completion() }
        }
    }

    /// 本地化路線搜尋（替代 API 呼叫）
    func searchRoutesLocally(query: String) -> [RouteSearchResult] {
        guard !query.isEmpty, let index = routeSearchIndex else { return [] }

        let startTime = CFAbsoluteTimeGetCurrent()
        let searchQuery = query.uppercased()
        var results: [String: [LocalRouteInfo]] = [:] // routeNumber → routes

        // 使用索引找出匹配的路線
        for (routeNumber, routes) in index where routeNumber.hasPrefix(searchQuery) {
            results[routeNumber] = routes
        }

        // 轉換為 RouteSearchResult 格式（按公司分組）
        var searchResults: [RouteSearchResult] = []

        for (routeNumber, routes) in results {
            print("🔍 路線 \(routeNumber): 找到 \(routes.count) 個條目")

            // 按公司分組
            let groupedByCompany = Dictionary(grouping: routes) { $0.company }

            for (company, companyRoutes) in groupedByCompany {
                print("   📍 公司 \(company): \(companyRoutes.count) 個方向")

                // 收集該公司的所有方向
                // CTB/NWFB: API 返回相同的起終點，inbound 需要對調
                // KMB: API 已返回正確的起終點，不需要對調
                let directions = companyRoutes.compactMap { route -> DirectionInfo? in
                    // 🔍 檢查該方向是否有站點資料
                    let routeId = "\(route.company)_\(route.routeNumber)_\(route.direction == "outbound" ? "O" : "I")"
                    guard let stopCount = getRouteStopCount(routeId: routeId), stopCount > 0 else {
                        print("      ⚠️ 跳過無站點方向: \(route.direction)")
                        return nil  // 過濾掉無站點的方向
                    }

                    let shouldSwap = (route.company == "CTB" || route.company == "NWFB") && route.direction == "inbound"

                    let origin = shouldSwap ? route.destTC : route.originTC
                    let destination = shouldSwap ? route.originTC : route.destTC

                    print("      ✅ \(route.direction): \(origin) → \(destination) (\(stopCount)個站)")
                    return DirectionInfo(
                        direction: route.direction,
                        origin: origin,
                        destination: destination,
                        stopCount: stopCount  // ✅ 設定實際站點數
                    )
                }

                // 🚫 如果所有方向都無站點，不加入搜尋結果
                guard !directions.isEmpty else {
                    print("   ⚠️ 路線 \(routeNumber) (\(company)) 所有方向均無站點，跳過")
                    continue  // 跳過這個公司的結果
                }

                let result = RouteSearchResult(
                    routeNumber: routeNumber,
                    company: BusRoute.Company(rawValue: company) ?? .CTB,
                    directions: directions
                )
                searchResults.append(result)
            }
        }

        // 排序：路線號優先，公司次之
        searchResults.sort { r1, r2 in
            if r1.routeNumber != r2.routeNumber {
                return r1.routeNumber.localizedStandardCompare(r2.routeNumber) == .orderedAscending
            }
            return r1.company.rawValue < r2.company.rawValue
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let timeElapsed = String(format: "%.1f", (endTime - startTime) * 1000)
        print("⚡ 本地搜尋完成 - 查詢: '\(query)', 結果: \(searchResults.count), 耗時: \(timeElapsed)ms")

        return searchResults
    }

    // MARK: - Memory Management

    @objc private func handleMemoryWarning() {
        print("⚠️ 記憶體警告 - 清空鍵盤快取")
        keyboardStateCache.removeAll()
    }
    
    // MARK: - Stop Coordinates
    
    func getStopCoordinates(stopId: String) -> (latitude: Double, longitude: Double)? {
        guard loadBusData(), let data = busData else { return nil }
        
        if let stopInfo = data.stops[stopId] {
            return (latitude: stopInfo.latitude, longitude: stopInfo.longitude)
        }
        
        return nil
    }
    
    func getStopInfo(stopId: String) -> LocalStopInfo? {
        guard loadBusData(), let data = busData else { return nil }
        return data.stops[stopId]
    }

    // MARK: - Route Validation

    /// 檢查指定路線是否有站點資料
    /// - Parameter routeId: 路線 ID（格式：CTB_90C_O）
    /// - Returns: 站點數量，nil 表示路線不存在
    func getRouteStopCount(routeId: String) -> Int? {
        guard loadBusData(), let data = busData else { return nil }

        guard let stops = data.routeStops[routeId] else {
            return nil  // 路線不存在或無站點資料
        }

        return stops.count
    }

    /// 檢查路線方向是否有效（有站點資料）
    /// - Parameters:
    ///   - routeNumber: 路線號碼（如 "90C"）
    ///   - company: 巴士公司
    ///   - direction: 方向（"outbound" 或 "inbound"）
    /// - Returns: true 表示有站點，false 表示無站點
    func isValidRouteDirection(routeNumber: String, company: String, direction: String) -> Bool {
        let routeId = "\(company)_\(routeNumber)_\(direction == "outbound" ? "O" : "I")"

        if let count = getRouteStopCount(routeId: routeId) {
            return count > 0
        }

        return false
    }
}

// MARK: - Data Models

struct LocalBusData: Codable {
    let version: Int?  // Unix timestamp for version tracking (optional for backward compatibility)
    let generatedAt: String
    let routes: [String: LocalRouteInfo]
    let stops: [String: LocalStopInfo]
    let routeStops: [String: [LocalRouteStop]]
    let stopRoutes: [String: [LocalStopRouteInfo]]
    let summary: LocalDataSummary

    enum CodingKeys: String, CodingKey {
        case version
        case generatedAt = "generated_at"
        case routes, stops
        case routeStops = "route_stops"
        case stopRoutes = "stop_routes"
        case summary
    }
}

struct LocalRouteInfo: Codable {
    let routeNumber: String
    let company: String
    let direction: String
    let originTC: String
    let originEN: String
    let destTC: String
    let destEN: String
    let serviceType: String?
    
    enum CodingKeys: String, CodingKey {
        case routeNumber = "route_number"
        case company, direction
        case originTC = "origin_tc"
        case originEN = "origin_en"
        case destTC = "dest_tc"
        case destEN = "dest_en"
        case serviceType = "service_type"
    }
}

struct LocalStopInfo: Codable {
    let nameTC: String
    let nameEN: String
    let latitude: Double
    let longitude: Double
    let company: String
    
    enum CodingKeys: String, CodingKey {
        case nameTC = "name_tc"
        case nameEN = "name_en"
        case latitude, longitude, company
    }
}

struct LocalRouteStop: Codable {
    let stopId: String
    let sequence: Int
    
    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case sequence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stopId = try container.decode(String.self, forKey: .stopId)
        
        // Handle sequence as either String or Int for compatibility
        if let seqInt = try? container.decode(Int.self, forKey: .sequence) {
            sequence = seqInt
        } else if let seqString = try? container.decode(String.self, forKey: .sequence) {
            sequence = Int(seqString) ?? 0
        } else {
            sequence = 0
        }
    }
}

struct LocalStopRouteInfo: Codable {
    let routeNumber: String
    let company: String
    let direction: String
    let destination: String
    let sequence: Int
    let routeId: String
    
    enum CodingKeys: String, CodingKey {
        case routeNumber = "route_number"
        case company, direction, destination, sequence
        case routeId = "route_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routeNumber = try container.decode(String.self, forKey: .routeNumber)
        company = try container.decode(String.self, forKey: .company)
        direction = try container.decode(String.self, forKey: .direction)
        destination = try container.decode(String.self, forKey: .destination)
        routeId = try container.decode(String.self, forKey: .routeId)
        
        // Handle sequence as either String or Int for compatibility
        if let seqInt = try? container.decode(Int.self, forKey: .sequence) {
            sequence = seqInt
        } else if let seqString = try? container.decode(String.self, forKey: .sequence) {
            sequence = Int(seqString) ?? 0
        } else {
            sequence = 0
        }
    }
}

struct LocalDataSummary: Codable {
    let totalRoutes: Int
    let totalStops: Int
    let totalStopRouteMappings: Int
    
    enum CodingKeys: String, CodingKey {
        case totalRoutes = "total_routes"
        case totalStops = "total_stops"
        case totalStopRouteMappings = "total_stop_route_mappings"
    }
}