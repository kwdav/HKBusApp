import Foundation
import CoreLocation

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
    
    private init() {}
    
    // MARK: - Data Loading
    
    func loadBusData() -> Bool {
        if isLoaded, busData != nil {
            return true
        }
        
        guard let fileURL = Bundle.main.url(forResource: "bus_data", withExtension: "json") else {
            print("❌ LocalBusDataManager: bus_data.json not found in bundle")
            print("📁 Bundle資源: \(Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])")
            return false
        }
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            busData = try decoder.decode(LocalBusData.self, from: jsonData)
            isLoaded = true
            
            print("✅ LocalBusDataManager: Loaded bus data successfully")
            if let summary = busData?.summary {
                print("📊 Routes: \(summary.totalRoutes), Stops: \(summary.totalStops)")
            }
            
            return true
        } catch {
            print("❌ LocalBusDataManager: Failed to load bus data - \(error)")
            return false
        }
    }
    
    // MARK: - Stop Search
    
    func searchStops(query: String, limit: Int = 50) -> [StopSearchResult] {
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
        
        return results
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
            // Get the full route info to determine origin/destination
            let routeId = routeInfo.routeId
            let routeDetail = data.routes[routeId]

            // Format destination with direction prefix
            let formattedDestination: String
            if routeInfo.direction == "inbound" {
                // For return direction, show origin with arrow prefix
                formattedDestination = "→ \(routeDetail?.originTC ?? routeInfo.destination)"
            } else {
                // For outbound direction, show destination with arrow prefix
                formattedDestination = "→ \(routeInfo.destination)"
            }

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
        
        for routeInfo in data.routes.values {
            let routeNumber = routeInfo.routeNumber.uppercased()
            
            if routeNumber.hasPrefix(input) && routeNumber.count > input.count {
                let nextCharIndex = routeNumber.index(routeNumber.startIndex, offsetBy: input.count)
                let nextChar = routeNumber[nextCharIndex]
                possibleChars.insert(nextChar)
            }
        }
        
        return possibleChars
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
}

// MARK: - Data Models

struct LocalBusData: Codable {
    let generatedAt: String
    let routes: [String: LocalRouteInfo]
    let stops: [String: LocalStopInfo]
    let routeStops: [String: [LocalRouteStop]]
    let stopRoutes: [String: [LocalStopRouteInfo]]
    let summary: LocalDataSummary
    
    enum CodingKeys: String, CodingKey {
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