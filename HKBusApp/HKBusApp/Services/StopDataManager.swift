import Foundation
import CoreLocation

/**
 * StopDataManager - 管理香港巴士站點數據
 * 
 * 數據來源：HK Bus Crawling@2021
 * GitHub: https://github.com/hkbus/hk-bus-crawling
 * 授權：GPL-2.0 License
 * 
 * This project uses data from hk-bus-crawling which is licensed under GPL-2.0.
 * We acknowledge and thank the hk-bus-crawling project contributors for providing
 * comprehensive Hong Kong bus stop data.
 */
class StopDataManager {
    static let shared = StopDataManager()
    
    private let hkBusCrawlingURL = "https://data.hkbus.app/routeFareList.min.json"
    private let cacheFileName = "HKBusStopData.json"
    private let lastUpdateKey = "StopDataLastUpdate"
    private let updateInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    private var cachedStopData: HKBusStopData?
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Public Methods
    
    func loadStopData(completion: @escaping (Result<HKBusStopData, Error>) -> Void) {
        // Check if we have cached data
        if let cachedData = cachedStopData {
            completion(.success(cachedData))
            return
        }
        
        // Try to load from local cache first
        if let localData = loadFromLocalCache() {
            cachedStopData = localData
            completion(.success(localData))
            
            // Check if update is needed in background
            if isUpdateNeeded() {
                print("🔄 Stand data is outdated, updating in background...")
                downloadAndCacheData { result in
                    if case .success(let newData) = result {
                        self.cachedStopData = newData
                        print("✅ Background update completed")
                    }
                }
            }
            return
        }
        
        // No local cache, download fresh data
        print("📥 No local cache found, downloading stop data...")
        downloadAndCacheData(completion: completion)
    }
    
    func forceUpdateData(completion: @escaping (Result<HKBusStopData, Error>) -> Void) {
        print("🔄 Force updating stop data...")
        downloadAndCacheData(completion: completion)
    }
    
    func searchStops(query: String, limit: Int = 50) -> [StopSearchResult] {
        guard let stopData = cachedStopData else { return [] }
        
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }
        
        var results: [StopSearchResult] = []
        
        for (unifiedId, stopInfo) in stopData.stopList {
            let chineseName = stopInfo.name.zh.lowercased()
            let englishName = stopInfo.name.en.lowercased()
            
            // Check if query matches Chinese or English name
            if chineseName.contains(searchQuery) || englishName.contains(searchQuery) {
                // Get routes for this stop from stopMap
                let routes = getRoutesForStop(stopId: unifiedId)
                
                print("🚏 Stop \(stopInfo.name.zh) (ID: \(unifiedId)) has \(routes.count) routes")
                
                let result = StopSearchResult(
                    stopId: unifiedId,
                    nameTC: stopInfo.name.zh,
                    nameEN: stopInfo.name.en,
                    latitude: stopInfo.location.lat,
                    longitude: stopInfo.location.lng,
                    routes: routes
                )
                results.append(result)
                
                if results.count >= limit {
                    break
                }
            }
        }
        
        return results
    }
    
    func getNearbyStops(location: CLLocation, radiusKm: Double = 2.0, limit: Int = 15) -> [StopSearchResult] {
        guard let stopData = cachedStopData else { return [] }
        
        var nearbyStops: [StopSearchResult] = []
        
        for (unifiedId, stopInfo) in stopData.stopList {
            let stopLocation = CLLocation(latitude: stopInfo.location.lat, longitude: stopInfo.location.lng)
            let distance = location.distance(from: stopLocation)
            
            // Filter by radius (convert km to meters)
            if distance <= radiusKm * 1000 {
                // Get routes for this stop from stopMap
                let routes = getRoutesForStop(stopId: unifiedId)
                
                print("🚏 Nearby stop \(stopInfo.name.zh) (ID: \(unifiedId)) has \(routes.count) routes")
                
                let result = StopSearchResult(
                    stopId: unifiedId,
                    nameTC: stopInfo.name.zh,
                    nameEN: stopInfo.name.en,
                    latitude: stopInfo.location.lat,
                    longitude: stopInfo.location.lng,
                    routes: routes
                )
                nearbyStops.append(result)
            }
        }
        
        // Sort by distance and limit results
        let sortedStops = nearbyStops.sorted { (stop1, stop2) in
            let location1 = CLLocation(latitude: stop1.latitude!, longitude: stop1.longitude!)
            let location2 = CLLocation(latitude: stop2.latitude!, longitude: stop2.longitude!)
            return location.distance(from: location1) < location.distance(from: location2)
        }
        
        return Array(sortedStops.prefix(limit))
    }
    
    func getLastUpdateTime() -> Date? {
        return UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
    }
    
    func getRoutesForStop(stopId: String) -> [StopRoute] {
        guard let stopData = cachedStopData else {
            print("❌ getRoutesForStop: cachedStopData is nil")
            return []
        }
        
        guard let routeEntries = stopData.stopMap[stopId] else { 
            print("ℹ️ getRoutesForStop: Stop \(stopId) has no route data in hk-bus-crawling (this is normal - not all stops have route data)")
            return [] 
        }
        
        print("🔍 Found \(routeEntries.count) route entries for stopId \(stopId)")
        
        var routes: [StopRoute] = []
        var skippedCount = 0
        
        for routeEntry in routeEntries {
            // routeEntry format: ["company", "routeId"]
            guard routeEntry.count >= 2 else { 
                print("⚠️ Invalid route entry format: \(routeEntry)")
                continue 
            }
            
            let companyCode = routeEntry[0]
            let routeId = routeEntry[1]
            
            print("📍 Processing route: \(companyCode) - \(routeId)")
            
            // Map company codes to our enum
            let company: BusRoute.Company
            switch companyCode.lowercased() {
            case "kmb":
                company = .KMB
            case "ctb":
                company = .CTB
            case "nwfb":
                company = .NWFB
            default:
                // Skip unknown companies for now
                print("⏭️ Skipping unknown company: \(companyCode)")
                skippedCount += 1
                continue
            }
            
            // For now, we'll use placeholders for route number and destination
            // Later we can enhance this by cross-referencing with routeList data
            let route = StopRoute(
                routeNumber: extractRouteNumber(from: routeId),
                company: company,
                direction: "unknown", // Will be enhanced later
                destination: "載入中..." // Will be enhanced later
            )
            
            routes.append(route)
        }
        
        print("✅ getRoutesForStop: Returning \(routes.count) routes (skipped \(skippedCount))")
        
        return routes
    }
    
    private func extractRouteNumber(from routeId: String) -> String {
        // For now, just return the routeId as is
        // Later we can implement logic to extract meaningful route numbers
        return routeId
    }
    
    // MARK: - Private Methods
    
    private func downloadAndCacheData(completion: @escaping (Result<HKBusStopData, Error>) -> Void) {
        guard let url = URL(string: hkBusCrawlingURL) else {
            completion(.failure(StopDataError.invalidURL))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(StopDataError.noData))
                return
            }
            
            do {
                let stopData = try JSONDecoder().decode(HKBusStopData.self, from: data)
                
                // Cache to local storage
                self?.saveToLocalCache(data: data)
                self?.cachedStopData = stopData
                
                // Update last update time
                UserDefaults.standard.set(Date(), forKey: self?.lastUpdateKey ?? "")
                
                print("✅ Stop data downloaded and cached successfully")
                print("📊 Total stops: \(stopData.stopList.count)")
                
                completion(.success(stopData))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func loadFromLocalCache() -> HKBusStopData? {
        guard let cacheURL = getCacheFileURL(),
              let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }
        
        do {
            let stopData = try JSONDecoder().decode(HKBusStopData.self, from: data)
            print("✅ Loaded stop data from local cache")
            print("📊 Total stops: \(stopData.stopList.count)")
            return stopData
        } catch {
            print("❌ Failed to decode cached stop data: \(error)")
            return nil
        }
    }
    
    private func saveToLocalCache(data: Data) {
        guard let cacheURL = getCacheFileURL() else { return }
        
        do {
            try data.write(to: cacheURL)
            print("💾 Stop data cached to local storage")
        } catch {
            print("❌ Failed to cache stop data: \(error)")
        }
    }
    
    private func getCacheFileURL() -> URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(cacheFileName)
    }
    
    private func isUpdateNeeded() -> Bool {
        guard let lastUpdate = getLastUpdateTime() else { return true }
        return Date().timeIntervalSince(lastUpdate) > updateInterval
    }
}

// MARK: - Data Models

struct HKBusStopData: Codable {
    let stopList: [String: HKBusStop]
    let stopMap: [String: [[String]]]
    
    // We only need stopList for now, but keep stopMap for future route mapping
}

struct HKBusStop: Codable {
    let location: HKBusLocation
    let name: HKBusName
}

struct HKBusLocation: Codable {
    let lat: Double
    let lng: Double
}

struct HKBusName: Codable {
    let zh: String
    let en: String
}

// MARK: - Error Types

enum StopDataError: Error {
    case invalidURL
    case noData
    case decodingError
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL for stop data"
        case .noData:
            return "No data received from stop data API"
        case .decodingError:
            return "Failed to decode stop data"
        }
    }
}