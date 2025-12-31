import Foundation

extension Array {
    func uniqued<T: Hashable>(by keyPath: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert(keyPath($0)).inserted }
    }
}

class BusAPIService {
    static let shared = BusAPIService()
    
    private let session = URLSession.shared
    private var stopNameCache: [String: String] = [:]
    
    // MARK: - Cache Properties
    private var routeSearchCache: [String: [RouteSearchResult]] = [:]
    private var stopSearchCache: [String: [StopSearchResult]] = [:]
    private var routeDetailCache: [String: BusRouteDetail] = [:]
    private var allStopsCache: [StopSearchResult] = []
    private let cacheExpiryTime: TimeInterval = 1800 // 30 minutes
    private var cacheTimestamps: [String: Date] = [:]
    
    private init() {}
    
    // MARK: - Cache Methods
    
    private func isCacheValid(for key: String) -> Bool {
        guard let timestamp = cacheTimestamps[key] else { return false }
        return Date().timeIntervalSince(timestamp) < cacheExpiryTime
    }
    
    private func setCacheTimestamp(for key: String) {
        cacheTimestamps[key] = Date()
    }
    
    private func getCachedRouteSearch(for query: String) -> [RouteSearchResult]? {
        let key = "route_\(query.lowercased())"
        guard isCacheValid(for: key) else { return nil }
        return routeSearchCache[key]
    }
    
    private func setCachedRouteSearch(for query: String, results: [RouteSearchResult]) {
        let key = "route_\(query.lowercased())"
        routeSearchCache[key] = results
        setCacheTimestamp(for: key)
    }
    
    private func getCachedStopSearch(for query: String) -> [StopSearchResult]? {
        let key = "stop_\(query.lowercased())"
        guard isCacheValid(for: key) else { return nil }
        return stopSearchCache[key]
    }
    
    private func setCachedStopSearch(for query: String, results: [StopSearchResult]) {
        let key = "stop_\(query.lowercased())"
        stopSearchCache[key] = results
        setCacheTimestamp(for: key)
    }
    
    private func getCachedRouteDetail(for routeId: String) -> BusRouteDetail? {
        guard isCacheValid(for: routeId) else { return nil }
        return routeDetailCache[routeId]
    }
    
    private func setCachedRouteDetail(for routeId: String, detail: BusRouteDetail) {
        routeDetailCache[routeId] = detail
        setCacheTimestamp(for: routeId)
    }
    
    // MARK: - API URLs

    // Support multiple serviceType for KMB routes
    private func etaURLs(for route: BusRoute) -> [URL] {
        switch route.company {
        case .CTB, .NWFB:
            // CTB/NWFB don't have serviceType concept
            guard let url = URL(string: "https://rt.data.gov.hk/v2/transport/citybus/eta/\(route.companyId)/\(route.stopId)/\(route.route)") else { return [] }
            return [url]

        case .KMB:
            // Query serviceType 1-3 in parallel (covers most cases)
            return (1...3).compactMap { serviceType in
                URL(string: "https://data.etabus.gov.hk/v1/transport/kmb/eta/\(route.stopId)/\(route.route)/\(serviceType)")
            }
        }
    }

    // Legacy single URL method (kept for compatibility)
    private func etaURL(for route: BusRoute) -> URL? {
        switch route.company {
        case .CTB, .NWFB:
            return URL(string: "https://rt.data.gov.hk/v2/transport/citybus/eta/\(route.companyId)/\(route.stopId)/\(route.route)")
        case .KMB:
            return URL(string: "https://data.etabus.gov.hk/v1/transport/kmb/eta/\(route.stopId)/\(route.route)/1")
        }
    }
    
    private func stopURL(for route: BusRoute) -> URL? {
        switch route.company {
        case .CTB, .NWFB:
            return URL(string: "https://rt.data.gov.hk/v2/transport/citybus/stop/\(route.stopId)")
        case .KMB:
            return URL(string: "https://data.etabus.gov.hk/v1/transport/kmb/stop/\(route.stopId)")
        }
    }
    
    private func routeURL(for route: BusRoute) -> URL? {
        switch route.company {
        case .CTB, .NWFB:
            return URL(string: "https://rt.data.gov.hk/v2/transport/citybus/route/\(route.companyId)/\(route.route)")
        case .KMB:
            return URL(string: "https://data.etabus.gov.hk/v1/transport/kmb/route/\(route.route)/\(route.direction)/1")
        }
    }
    
    // MARK: - API Methods
    func fetchETA(for route: BusRoute, completion: @escaping (Result<[BusETA], Error>) -> Void) {
        let urls = etaURLs(for: route)
        guard !urls.isEmpty else {
            completion(.failure(APIError.invalidURL))
            return
        }

        if route.company == .KMB {
            // KMB: Query multiple serviceType in parallel
            fetchETAsFromMultipleServices(urls: urls, direction: route.direction, completion: completion)
        } else {
            // CTB/NWFB: Single query (maintain original logic)
            fetchSingleETA(url: urls[0], direction: route.direction, completion: completion)
        }
    }

    // Fetch ETAs from multiple serviceType endpoints in parallel (KMB only)
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
                // Sort by arrival time (merge different serviceType ETAs)
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

    // Fetch ETA from single endpoint (CTB/NWFB)
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

    func fetchStopName(for route: BusRoute, completion: @escaping (Result<String, Error>) -> Void) {
        // Check cache first
        if let cachedName = stopNameCache[route.stopId] {
            completion(.success(cachedName))
            return
        }
        
        guard let url = stopURL(for: route) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
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
                let stopInfo = try JSONDecoder().decode(BusStopInfo.self, from: data)
                let stopName = stopInfo.data.name_tc
                
                // Cache the result
                self.stopNameCache[route.stopId] = stopName
                completion(.success(stopName))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchRouteDestination(for route: BusRoute, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = routeURL(for: route) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
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
                let routeInfo = try JSONDecoder().decode(BusRouteInfo.self, from: data)
                let destination: String
                
                if route.direction == "inbound" {
                    destination = "→ \(routeInfo.data.orig_tc)"
                } else {
                    destination = "→ \(routeInfo.data.dest_tc)"
                }
                
                completion(.success(destination))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchBusDisplayData(for route: BusRoute, completion: @escaping (Result<BusDisplayData, Error>) -> Void) {
        let group = DispatchGroup()
        var stopName = ""
        var destination = ""
        var etas: [BusETA] = []
        var errors: [Error] = []
        
        // Fetch stop name
        group.enter()
        fetchStopName(for: route) { result in
            switch result {
            case .success(let name):
                stopName = name
            case .failure(let error):
                errors.append(error)
            }
            group.leave()
        }
        
        // Fetch destination
        group.enter()
        fetchRouteDestination(for: route) { result in
            switch result {
            case .success(let dest):
                destination = dest
            case .failure(let error):
                errors.append(error)
            }
            group.leave()
        }
        
        // Fetch ETA
        group.enter()
        fetchETA(for: route) { result in
            switch result {
            case .success(let etaData):
                etas = etaData
            case .failure(let error):
                errors.append(error)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if !errors.isEmpty && etas.isEmpty {
                completion(.failure(errors.first!))
            } else {
                let displayData = BusDisplayData(
                    route: route,
                    stopName: stopName,
                    destination: destination,
                    etas: etas
                )
                completion(.success(displayData))
            }
        }
    }
    
    // MARK: - Enhanced Search API Methods
    
    func searchRoutes(routeNumber: String, completion: @escaping (Result<[RouteSearchResult], Error>) -> Void) {
        // Check cache first
        if let cachedResults = getCachedRouteSearch(for: routeNumber) {
            print("使用路線搜尋緩存: \(routeNumber)")
            completion(.success(cachedResults))
            return
        }
        
        let group = DispatchGroup()
        var allRouteResults: [RouteSearchResult] = []
        var searchErrors: [Error] = []
        
        // Search CTB routes
        group.enter()
        searchCTBRoutes(routeNumber: routeNumber) { result in
            switch result {
            case .success(let routes):
                allRouteResults.append(contentsOf: routes)
            case .failure(let error):
                searchErrors.append(error)
            }
            group.leave()
        }
        
        // Search NWFB routes
        group.enter()
        searchNWFBRoutes(routeNumber: routeNumber) { result in
            switch result {
            case .success(let routes):
                allRouteResults.append(contentsOf: routes)
            case .failure(let error):
                searchErrors.append(error)
            }
            group.leave()
        }
        
        // Search KMB routes
        group.enter()
        searchKMBRoutes(routeNumber: routeNumber) { result in
            switch result {
            case .success(let routes):
                allRouteResults.append(contentsOf: routes)
            case .failure(let error):
                searchErrors.append(error)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if allRouteResults.isEmpty && !searchErrors.isEmpty {
                completion(.failure(searchErrors.first!))
            } else {
                // Cache the results
                self.setCachedRouteSearch(for: routeNumber, results: allRouteResults)
                completion(.success(allRouteResults))
            }
        }
    }
    
    private func searchCTBRoutes(routeNumber: String, completion: @escaping (Result<[RouteSearchResult], Error>) -> Void) {
        let urlString = "https://rt.data.gov.hk/v2/transport/citybus/route/CTB"
        print("CTB API搜尋: \(urlString)")
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("CTB API錯誤: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("CTB API沒有資料")
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                let routeResponse = try JSONDecoder().decode(CTBRouteListResponse.self, from: data)
                print("CTB API返回 \(routeResponse.data.count) 條路線")
                
                // Filter routes by search query
                let matchingRoutes = routeResponse.data.filter { route in
                    route.route.uppercased().contains(routeNumber.uppercased())
                }
                print("CTB搜尋 '\(routeNumber)' 找到 \(matchingRoutes.count) 條匹配路線")
                
                // Group by route number
                var groupedResults: [String: RouteSearchResult] = [:]
                
                for route in matchingRoutes {
                    let key = "CTB_\(route.route)"
                    
                    // CTB API doesn't have bound info, so create both directions
                    let outboundDirection = DirectionInfo(
                        direction: "outbound",
                        origin: route.orig_tc,
                        destination: route.dest_tc,
                        stopCount: nil
                    )
                    
                    let inboundDirection = DirectionInfo(
                        direction: "inbound",
                        origin: route.dest_tc,
                        destination: route.orig_tc,
                        stopCount: nil
                    )
                    
                    let result = RouteSearchResult(
                        routeNumber: route.route,
                        company: .CTB,
                        directions: [outboundDirection, inboundDirection]
                    )
                    groupedResults[key] = result
                }
                
                let results = Array(groupedResults.values)
                completion(.success(results))
                
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func searchKMBRoutes(routeNumber: String, completion: @escaping (Result<[RouteSearchResult], Error>) -> Void) {
        let urlString = "https://data.etabus.gov.hk/v1/transport/kmb/route"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
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
                let routeResponse = try JSONDecoder().decode(KMBRouteListResponse.self, from: data)
                
                // Filter routes by search query
                let matchingRoutes = routeResponse.data.filter { route in
                    route.route.uppercased().contains(routeNumber.uppercased())
                }
                
                // Group by route number
                var groupedResults: [String: RouteSearchResult] = [:]
                
                for route in matchingRoutes {
                    let key = "KMB_\(route.route)"
                    
                    let direction = DirectionInfo(
                        direction: route.bound.lowercased() == "o" ? "outbound" : "inbound",
                        origin: route.orig_tc,
                        destination: route.dest_tc,
                        stopCount: nil
                    )
                    
                    if let existing = groupedResults[key] {
                        // Check if direction already exists
                        if !existing.directions.contains(where: { $0.direction == direction.direction }) {
                            let updatedDirections = existing.directions + [direction]
                            let updatedResult = RouteSearchResult(
                                routeNumber: existing.routeNumber,
                                company: .KMB,
                                directions: updatedDirections
                            )
                            groupedResults[key] = updatedResult
                        }
                    } else {
                        let result = RouteSearchResult(
                            routeNumber: route.route,
                            company: .KMB,
                            directions: [direction]
                        )
                        groupedResults[key] = result
                    }
                }
                
                let results = Array(groupedResults.values)
                completion(.success(results))
                
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func searchNWFBRoutes(routeNumber: String, completion: @escaping (Result<[RouteSearchResult], Error>) -> Void) {
        let urlString = "https://rt.data.gov.hk/v2/transport/citybus/route/NWFB"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
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
                let routeResponse = try JSONDecoder().decode(CTBRouteListResponse.self, from: data)
                
                // Filter routes by search query
                let matchingRoutes = routeResponse.data.filter { route in
                    route.route.uppercased().contains(routeNumber.uppercased())
                }
                
                // Group by route number
                var groupedResults: [String: RouteSearchResult] = [:]
                
                for route in matchingRoutes {
                    let key = "NWFB_\(route.route)"
                    
                    // NWFB API uses same structure as CTB, create both directions
                    let outboundDirection = DirectionInfo(
                        direction: "outbound",
                        origin: route.orig_tc,
                        destination: route.dest_tc,
                        stopCount: nil
                    )
                    
                    let inboundDirection = DirectionInfo(
                        direction: "inbound",
                        origin: route.dest_tc,
                        destination: route.orig_tc,
                        stopCount: nil
                    )
                    
                    let result = RouteSearchResult(
                        routeNumber: route.route,
                        company: .NWFB,
                        directions: [outboundDirection, inboundDirection]
                    )
                    groupedResults[key] = result
                }
                
                let results = Array(groupedResults.values)
                completion(.success(results))
                
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchRouteDetail(routeNumber: String, company: BusRoute.Company, direction: String, stopNamesUpdateCallback: @escaping (BusRouteDetail) -> Void = { _ in }, completion: @escaping (Result<BusRouteDetail, Error>) -> Void) {
        let routeId = "\(company.rawValue)_\(routeNumber)_\(direction)"
        
        // Check cache first
        if let cachedDetail = getCachedRouteDetail(for: routeId) {
            print("使用路線詳情緩存: \(routeId)")
            completion(.success(cachedDetail))
            return
        }
        
        // Call real API to get route stops with initial basic info
        fetchRouteStopsWithCallback(routeNumber: routeNumber, company: company, direction: direction, routeId: routeId, stopNamesUpdateCallback: stopNamesUpdateCallback, completion: completion)
    }
    
    private func fetchRouteStopsWithCallback(routeNumber: String, company: BusRoute.Company, direction: String, routeId: String, stopNamesUpdateCallback: @escaping (BusRouteDetail) -> Void, completion: @escaping (Result<BusRouteDetail, Error>) -> Void) {
        
        // First, get basic route structure
        fetchRouteStops(routeNumber: routeNumber, company: company, direction: direction) { [weak self] result in
            switch result {
            case .success(let stops):
                guard let self = self else { return }
                
                let routeDetail = BusRouteDetail(
                    routeNumber: routeNumber,
                    company: company,
                    direction: direction,
                    origin: stops.first?.displayName ?? "起點",
                    destination: stops.last?.displayName ?? "終點",
                    stops: stops,
                    estimatedDuration: nil,
                    operatingHours: nil
                )
                
                // Cache the result
                self.setCachedRouteDetail(for: routeId, detail: routeDetail)
                completion(.success(routeDetail))
                
                // After completion, notify about updates
                stopNamesUpdateCallback(routeDetail)
                
            case .failure(let error):
                print("路線詳情API錯誤: \(error.localizedDescription)")
                // Fallback to mock data
                self?.fetchRouteDetailFallback(routeNumber: routeNumber, company: company, direction: direction, completion: completion)
            }
        }
    }
    
    private func fetchRouteStops(routeNumber: String, company: BusRoute.Company, direction: String, completion: @escaping (Result<[BusStop], Error>) -> Void) {
        let urlString: String
        let directionParam = direction == "outbound" ? "outbound" : "inbound"
        
        switch company {
        case .CTB, .NWFB:
            urlString = "https://rt.data.gov.hk/v2/transport/citybus/route-stop/\(company.rawValue)/\(routeNumber)/\(directionParam)"
        case .KMB:
            urlString = "https://data.etabus.gov.hk/v1/transport/kmb/route-stop/\(routeNumber)/\(directionParam)/1"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        print("取得路線站點: \(urlString)")
        
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("路線站點API錯誤: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                try self.parseRouteStops(data: data, company: company) { updatedStops in
                    // This is already on main queue from fetchStopNamesAsync
                    completion(.success(updatedStops))
                }
            } catch {
                print("路線站點解析錯誤: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    private func parseRouteStops(data: Data, company: BusRoute.Company, completion: @escaping ([BusStop]) -> Void) throws {
        switch company {
        case .CTB, .NWFB:
            let response = try JSONDecoder().decode(CTBRouteStopResponse.self, from: data)
            var stops: [BusStop] = []
            
            // Create basic stops structure
            for stopData in response.data {
                let stop = BusStop(
                    stopId: stopData.stop,
                    sequence: Int(stopData.seq) ?? 1,
                    nameTC: stopNameCache[stopData.stop] ?? "載入中...",
                    nameEN: nil,
                    latitude: nil,
                    longitude: nil
                )
                stops.append(stop)
            }
            
            // Fetch stop names asynchronously and update UI
            fetchStopNamesAsync(for: stops, company: company) { updatedStops in
                completion(updatedStops)
            }
            
        case .KMB:
            let response = try JSONDecoder().decode(KMBRouteStopResponse.self, from: data)
            var stops: [BusStop] = []
            
            for stopData in response.data {
                let stop = BusStop(
                    stopId: stopData.stop,
                    sequence: Int(stopData.seq) ?? 1,
                    nameTC: stopNameCache[stopData.stop] ?? "載入中...",
                    nameEN: nil,
                    latitude: nil,
                    longitude: nil
                )
                stops.append(stop)
            }
            
            // Fetch stop names asynchronously and update UI
            fetchStopNamesAsync(for: stops, company: company) { updatedStops in
                completion(updatedStops)
            }
        }
    }
    
    private func fetchStopNamesAsync(for stops: [BusStop], company: BusRoute.Company, completion: @escaping ([BusStop]) -> Void) {
        let group = DispatchGroup()
        var updatedStops = stops
        
        for (index, stop) in stops.enumerated() {
            // Always try to get coordinates from local data first
            var stopLatitude: Double? = nil
            var stopLongitude: Double? = nil
            var stopName = stop.nameTC
            
            // Get coordinates from local bus data
            if let coordinates = LocalBusDataManager.shared.getStopCoordinates(stopId: stop.stopId) {
                stopLatitude = coordinates.latitude
                stopLongitude = coordinates.longitude
                print("📍 從本地資料獲取座標 \(stop.stopId): (\(coordinates.latitude), \(coordinates.longitude))")
            }
            
            // Get stop info (name and coordinates) from local data if available
            if let localStopInfo = LocalBusDataManager.shared.getStopInfo(stopId: stop.stopId) {
                stopName = localStopInfo.nameTC
                stopLatitude = localStopInfo.latitude
                stopLongitude = localStopInfo.longitude
                print("📍 從本地資料獲取站點資訊 \(stop.stopId): \(localStopInfo.nameTC)")
                
                // Update the stop with local data
                updatedStops[index] = BusStop(
                    stopId: stop.stopId,
                    sequence: stop.sequence,
                    nameTC: stopName,
                    nameEN: localStopInfo.nameEN,
                    latitude: stopLatitude,
                    longitude: stopLongitude
                )
                
                // Cache the name for future use
                stopNameCache[stop.stopId] = stopName
            } else if stopNameCache[stop.stopId] == nil {
                // Fall back to API if not in local data
                group.enter()
                
                // Create a dummy route to use existing stop name fetching
                let dummyRoute = BusRoute(
                    stopId: stop.stopId,
                    route: "temp",
                    companyId: company.rawValue,
                    direction: "outbound",
                    subTitle: ""
                )
                
                fetchStopName(for: dummyRoute) { result in
                    if case .success(let name) = result {
                        print("取得站點名稱: \(stop.stopId) -> \(name)")
                        // Update the stop with the fetched name and coordinates from local data
                        updatedStops[index] = BusStop(
                            stopId: stop.stopId,
                            sequence: stop.sequence,
                            nameTC: name,
                            nameEN: stop.nameEN,
                            latitude: stopLatitude,
                            longitude: stopLongitude
                        )
                    }
                    group.leave()
                }
            } else {
                // Use cached name with coordinates from local data
                let cachedName = stopNameCache[stop.stopId] ?? stop.nameTC
                updatedStops[index] = BusStop(
                    stopId: stop.stopId,
                    sequence: stop.sequence,
                    nameTC: cachedName,
                    nameEN: stop.nameEN,
                    latitude: stopLatitude,
                    longitude: stopLongitude
                )
            }
        }
        
        group.notify(queue: .main) {
            completion(updatedStops)
        }
    }
    
    private func fetchRouteDetailFallback(routeNumber: String, company: BusRoute.Company, direction: String, completion: @escaping (Result<BusRouteDetail, Error>) -> Void) {
        // Fallback to original mock implementation
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Filter matching routes
            let matchingRoutes = BusRouteConfiguration.defaultRoutes.filter { route in
                route.route == routeNumber && 
                route.company.rawValue == company.rawValue && 
                route.direction == direction
            }
            
            guard !matchingRoutes.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(APIError.noData))
                }
                return
            }
            
            // Create mock bus stops for the route
            let mockStops = self.generateMockStops(for: matchingRoutes.first!)
            
            let routeDetail = BusRouteDetail(
                routeNumber: routeNumber,
                company: company,
                direction: direction,
                origin: self.extractOrigin(from: matchingRoutes.first!),
                destination: self.extractDestination(from: matchingRoutes.first!),
                stops: mockStops,
                estimatedDuration: nil,
                operatingHours: nil
            )
            
            DispatchQueue.main.async {
                completion(.success(routeDetail))
            }
        }
    }
    
    func fetchStopETA(stopId: String, routeNumber: String, company: BusRoute.Company, direction: String, completion: @escaping (Result<[BusETA], Error>) -> Void) {
        // Create a BusRoute object to use existing ETA fetching
        let route = BusRoute(
            stopId: stopId,
            route: routeNumber,
            companyId: company.rawValue,
            direction: direction,
            subTitle: ""
        )
        
        fetchETA(for: route, completion: completion)
    }
    
    // MARK: - Stop Search Methods
    
    func fetchAllBusStops(completion: @escaping (Result<[StopSearchResult], Error>) -> Void) {
        // Use StopDataManager for much faster stop data loading
        print("📱 使用 HK Bus Crawling 數據源獲取站點資料...")
        
        StopDataManager.shared.loadStopData { result in
            switch result {
            case .success(let stopData):
                // Convert HK Bus Crawling data to StopSearchResult format
                var stops: [StopSearchResult] = []
                
                for (unifiedId, stopInfo) in stopData.stopList {
                    let stop = StopSearchResult(
                        stopId: unifiedId,
                        nameTC: stopInfo.name.zh,
                        nameEN: stopInfo.name.en,
                        latitude: stopInfo.location.lat,
                        longitude: stopInfo.location.lng,
                        routes: [] // Routes will be populated when needed
                    )
                    stops.append(stop)
                }
                
                print("✅ 成功載入 \(stops.count) 個站點")
                print("  📊 數據來源: HK Bus Crawling (GitHub)")
                
                // Cache the results for legacy compatibility
                self.allStopsCache = stops
                self.setCacheTimestamp(for: "all_stops")
                
                DispatchQueue.main.async {
                    completion(.success(stops))
                }
                
            case .failure(let error):
                print("❌ StopDataManager 載入失敗: \(error.localizedDescription)")
                print("🔄 回退至原有 API 方法...")
                
                // Fallback to original API method if StopDataManager fails
                self.fetchAllBusStopsFromAPIs(completion: completion)
            }
        }
    }
    
    // MARK: - Legacy API Method (Fallback)
    
    private func fetchAllBusStopsFromAPIs(completion: @escaping (Result<[StopSearchResult], Error>) -> Void) {
        print("🚌 開始並行獲取所有巴士公司的站點資料...")
        let group = DispatchGroup()
        var allStops: [StopSearchResult] = []
        var fetchErrors: [Error] = []
        
        // Fetch KMB stops
        print("  📡 發起 KMB API 請求...")
        group.enter()
        fetchKMBStops { result in
            switch result {
            case .success(let stops):
                print("  ✅ KMB 成功獲取 \(stops.count) 個站點")
                allStops.append(contentsOf: stops)
            case .failure(let error):
                print("  ❌ KMB 站點獲取錯誤: \(error.localizedDescription)")
                fetchErrors.append(error)
            }
            group.leave()
        }
        
        // Fetch CTB stops (this will likely fail due to empty API response)
        print("  📡 發起 CTB API 請求...")
        group.enter()
        fetchCTBStops { result in
            switch result {
            case .success(let stops):
                print("  ✅ CTB 成功獲取 \(stops.count) 個站點")
                allStops.append(contentsOf: stops)
            case .failure(let error):
                print("  ❌ CTB 站點獲取錯誤: \(error.localizedDescription)")
                fetchErrors.append(error)
            }
            group.leave()
        }
        
        // Fetch NWFB stops  
        print("  📡 發起 NWFB API 請求...")
        group.enter()
        fetchNWFBStops { result in
            switch result {
            case .success(let stops):
                print("  ✅ NWFB 成功獲取 \(stops.count) 個站點")
                allStops.append(contentsOf: stops)
            case .failure(let error):
                print("  ❌ NWFB 站點獲取錯誤: \(error.localizedDescription)")
                fetchErrors.append(error)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("🔄 所有 API 請求完成，整合結果...")
            
            if !allStops.isEmpty {
                print("✅ 總共獲取 \(allStops.count) 個巴士站點")
                print("  📊 錯誤數量: \(fetchErrors.count) 個API失敗")
                
                // Cache the results
                self.allStopsCache = allStops
                self.setCacheTimestamp(for: "all_stops")
                completion(.success(allStops))
            } else if !fetchErrors.isEmpty {
                print("❌ 所有 API 請求都失敗了")
                completion(.failure(fetchErrors.first!))
            } else {
                print("❌ 沒有數據返回且無錯誤信息")
                completion(.failure(APIError.noData))
            }
        }
    }
    
    private func fetchCTBStops(completion: @escaping (Result<[StopSearchResult], Error>) -> Void) {
        let urlString = "https://rt.data.gov.hk/v2/transport/citybus/stop/CTB"
        guard let url = URL(string: urlString) else {
            print("❌ CTB URL 無效: \(urlString)")
            completion(.failure(APIError.invalidURL))
            return
        }
        
        print("🌐 CTB API 請求: \(urlString)")
        
        session.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 CTB API 回應狀態: \(httpResponse.statusCode)")
            }
            
            if let error = error {
                print("❌ CTB 網絡錯誤: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ CTB 沒有返回數據")
                completion(.failure(APIError.noData))
                return
            }
            
            print("📦 CTB API 返回數據大小: \(data.count) bytes")
            
            // Debug: Print raw response
            if let rawString = String(data: data, encoding: .utf8) {
                let preview = String(rawString.prefix(200))
                print("🔍 CTB API 原始回應前200字符: \(preview)")
            }
            
            do {
                let stopResponse = try JSONDecoder().decode(CTBStopListResponse.self, from: data)
                print("✅ CTB JSON 解析成功")
                print("📊 CTB API 回應: type=\(stopResponse.type), version=\(stopResponse.version)")
                print("📈 CTB 原始數據項目: \(stopResponse.data.stops.count)")
                
                let stops = stopResponse.data.stops.compactMap { stopData -> StopSearchResult? in
                    // Validate that we have coordinates
                    guard let lat = stopData.latitude, let lon = stopData.longitude else {
                        print("⚠️ CTB 站點缺少座標: \(stopData.stop)")
                        return nil
                    }
                    
                    return StopSearchResult(
                        stopId: stopData.stop,
                        nameTC: stopData.name_tc,
                        nameEN: stopData.name_en,
                        latitude: lat,
                        longitude: lon,
                        routes: []
                    )
                }
                
                print("✅ CTB 成功處理 \(stops.count) 個有效站點（共 \(stopResponse.data.stops.count) 個原始項目）")
                completion(.success(stops))
                
            } catch {
                print("❌ CTB JSON 解析失敗: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("  數據損壞: \(context)")
                    case .keyNotFound(let key, let context):
                        print("  缺少鍵: \(key), 上下文: \(context)")
                    case .typeMismatch(let type, let context):
                        print("  類型不匹配: \(type), 上下文: \(context)")
                    case .valueNotFound(let value, let context):
                        print("  值未找到: \(value), 上下文: \(context)")
                    @unknown default:
                        print("  未知解析錯誤")
                    }
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func fetchNWFBStops(completion: @escaping (Result<[StopSearchResult], Error>) -> Void) {
        let urlString = "https://rt.data.gov.hk/v2/transport/citybus/stop/NWFB"
        guard let url = URL(string: urlString) else {
            print("❌ NWFB URL 無效: \(urlString)")
            completion(.failure(APIError.invalidURL))
            return
        }
        
        print("🌐 NWFB API 請求: \(urlString)")
        
        session.dataTask(with: url) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 NWFB API 回應狀態: \(httpResponse.statusCode)")
            }
            
            if let error = error {
                print("❌ NWFB 網絡錯誤: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ NWFB 沒有返回數據")
                completion(.failure(APIError.noData))
                return
            }
            
            print("📦 NWFB API 返回數據大小: \(data.count) bytes")
            
            // Debug: Print raw response
            if let rawString = String(data: data, encoding: .utf8) {
                let preview = String(rawString.prefix(200))
                print("🔍 NWFB API 原始回應前200字符: \(preview)")
            }
            
            do {
                let stopResponse = try JSONDecoder().decode(CTBStopListResponse.self, from: data)
                print("✅ NWFB JSON 解析成功")
                print("📊 NWFB API 回應: type=\(stopResponse.type), version=\(stopResponse.version)")
                print("📈 NWFB 原始數據項目: \(stopResponse.data.stops.count)")
                
                let stops = stopResponse.data.stops.compactMap { stopData -> StopSearchResult? in
                    // Validate that we have coordinates
                    guard let lat = stopData.latitude, let lon = stopData.longitude else {
                        print("⚠️ NWFB 站點缺少座標: \(stopData.stop)")
                        return nil
                    }
                    
                    return StopSearchResult(
                        stopId: stopData.stop,
                        nameTC: stopData.name_tc,
                        nameEN: stopData.name_en,
                        latitude: lat,
                        longitude: lon,
                        routes: []
                    )
                }
                
                print("✅ NWFB 成功處理 \(stops.count) 個有效站點（共 \(stopResponse.data.stops.count) 個原始項目）")
                completion(.success(stops))
                
            } catch {
                print("❌ NWFB JSON 解析失敗: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("  數據損壞: \(context)")
                    case .keyNotFound(let key, let context):
                        print("  缺少鍵: \(key), 上下文: \(context)")
                    case .typeMismatch(let type, let context):
                        print("  類型不匹配: \(type), 上下文: \(context)")
                    case .valueNotFound(let value, let context):
                        print("  值未找到: \(value), 上下文: \(context)")
                    @unknown default:
                        print("  未知解析錯誤")
                    }
                }
                completion(.failure(error))
            }
        }.resume()
    }

    private func fetchKMBStops(completion: @escaping (Result<[StopSearchResult], Error>) -> Void) {
        let urlString = "https://data.etabus.gov.hk/v1/transport/kmb/stop"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        print("獲取 KMB 巴士站列表...")
        
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
                let stopResponse = try JSONDecoder().decode(KMBStopListResponse.self, from: data)
                print("KMB API 返回 \(stopResponse.data.count) 個巴士站")
                
                // Convert KMB stops to StopSearchResult
                let stops = stopResponse.data.compactMap { kmbStop -> StopSearchResult? in
                    guard let lat = kmbStop.latitude, let lon = kmbStop.longitude else {
                        return nil
                    }
                    
                    return StopSearchResult(
                        stopId: kmbStop.stop,
                        nameTC: kmbStop.name_tc,
                        nameEN: kmbStop.name_en,
                        latitude: lat,
                        longitude: lon,
                        routes: [] // Routes will be populated later if needed
                    )
                }
                
                print("轉換完成，有效的巴士站: \(stops.count)")
                completion(.success(stops))
                
            } catch {
                print("KMB 站點解析錯誤: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Stop Routes
    func fetchRoutesForStop(stopId: String, completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        // Get stop location info for nearby search
        getStopLocationInfo(stopId: stopId) { [weak self] locationResult in
            switch locationResult {
            case .success(let location):
                self?.fetchRoutesForStopWithLocation(stopId: stopId, location: location, completion: completion)
            case .failure:
                // Fallback to direct ID matching
                self?.fetchRoutesForStopDirectly(stopId: stopId, completion: completion)
            }
        }
    }
    
    private func fetchRoutesForStopDirectly(stopId: String, completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        print("📍 開始查詢站點路線: \(stopId)")
        
        // First try direct ID match with KMB API
        fetchKMBRoutesForStop(stopId: stopId) { [weak self] kmbResult in
            // Then try CTB/NWFB APIs
            self?.fetchCTBRoutesForStop(stopId: stopId) { ctbResult in
                var allRoutes: [StopRoute] = []
                
                // Combine results from all APIs
                switch kmbResult {
                case .success(let kmbRoutes):
                    print("🚌 KMB API 找到 \(kmbRoutes.count) 條路線")
                    allRoutes.append(contentsOf: kmbRoutes)
                case .failure(let error):
                    print("❌ KMB API 查詢失敗: \(error.localizedDescription)")
                }
                
                switch ctbResult {
                case .success(let ctbRoutes):
                    print("🚍 CTB/NWFB API 找到 \(ctbRoutes.count) 條路線") 
                    allRoutes.append(contentsOf: ctbRoutes)
                case .failure(let error):
                    print("❌ CTB/NWFB API 查詢失敗: \(error.localizedDescription)")
                }
                
                // Remove duplicates and sort
                let uniqueRoutes = Array(Set(allRoutes.map { "\($0.company.rawValue)_\($0.routeNumber)_\($0.direction)" }))
                    .compactMap { uniqueKey -> StopRoute? in
                        allRoutes.first { "\($0.company.rawValue)_\($0.routeNumber)_\($0.direction)" == uniqueKey }
                    }
                    .sorted { $0.routeNumber < $1.routeNumber }
                
                print("✅ 站點 \(stopId) 總共找到 \(uniqueRoutes.count) 條路線")
                
                // If no routes found, try to provide some mock data for testing
                if uniqueRoutes.isEmpty {
                    print("⚠️ 沒有找到路線，嘗試提供測試資料")
                    guard let strongSelf = self else {
                        completion(.success(uniqueRoutes))
                        return
                    }
                    let mockRoutes = strongSelf.generateMockRoutesForStop(stopId: stopId)
                    if !mockRoutes.isEmpty {
                        print("📋 提供 \(mockRoutes.count) 條模擬路線用於測試")
                    }
                    completion(.success(mockRoutes))
                } else {
                    completion(.success(uniqueRoutes))
                }
            }
        }
    }
    
    private func fetchKMBRoutesForStop(stopId: String, completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        // Directly fetch route-stops to find routes passing through this stop
        fetchKMBRouteStopsForStop(stopId: stopId, completion: completion)
    }
    
    private func fetchKMBRouteStopsForStop(stopId: String, completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        // Use KMB route-stop API to get all routes passing through this stop
        let urlString = "https://data.etabus.gov.hk/v1/transport/kmb/route-stop"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
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
                let routeStopResponse = try JSONDecoder().decode(KMBRouteStopResponse.self, from: data)
                
                // Filter routes that pass through this stop
                let routesAtStop = routeStopResponse.data.filter { $0.stop == stopId }
                print("🔍 KMB route-stop API 總共有 \(routeStopResponse.data.count) 條記錄，其中 \(routesAtStop.count) 條經過站點 \(stopId)")
                
                // Debug: Show some sample stop IDs from API for comparison
                if routesAtStop.isEmpty && routeStopResponse.data.count > 0 {
                    let sampleStops = Array(Set(routeStopResponse.data.prefix(10).map { $0.stop }))
                    print("🔍 API 中的一些站點 ID 示例: \(sampleStops.prefix(5))")
                    print("🔍 查詢的站點 ID: '\(stopId)'")
                }
                
                // Convert to StopRoute objects and remove duplicates
                var uniqueRoutes: [String: StopRoute] = [:]
                
                for routeStop in routesAtStop {
                    let key = "\(routeStop.route)_\(routeStop.bound)"
                    
                    if uniqueRoutes[key] == nil {
                        let direction = routeStop.bound.lowercased() == "o" ? "outbound" : "inbound"
                        let stopRoute = StopRoute(
                            routeNumber: routeStop.route,
                            company: .KMB,
                            direction: direction,
                            destination: self.getKMBDestinationPlaceholder(route: routeStop.route, bound: routeStop.bound)
                        )
                        uniqueRoutes[key] = stopRoute
                    }
                }
                
                // Now fetch actual destinations for the routes
                self.enhanceKMBRoutesWithDestinations(Array(uniqueRoutes.values)) { enhancedRoutes in
                    completion(.success(enhancedRoutes.sorted { $0.routeNumber < $1.routeNumber }))
                }
                
            } catch {
                print("KMB 路線站點解析錯誤: \(error.localizedDescription)")
                // Print raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔍 原始響應前 500 字符: \(String(responseString.prefix(500)))")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func getKMBDestinationPlaceholder(route: String, bound: String) -> String {
        // Provide some common destinations as placeholders
        // This could be enhanced with a lookup table
        return bound.lowercased() == "o" ? "→ 終點站" : "→ 起點站"
    }
    
    private func enhanceKMBRoutesWithDestinations(_ routes: [StopRoute], completion: @escaping ([StopRoute]) -> Void) {
        // For now, just return the routes as-is
        // This could be enhanced to fetch actual destination names from KMB route API
        completion(routes)
    }
    
    private func fetchCTBRoutesForStop(stopId: String, completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        print("🚍 開始查詢 CTB/NWFB 路線，站點: \(stopId)")
        
        let dispatchGroup = DispatchGroup()
        var allCTBRoutes: [StopRoute] = []
        
        // Query both CTB and NWFB
        dispatchGroup.enter()
        fetchCTBRouteStopsForCompany(stopId: stopId, company: "CTB") { result in
            switch result {
            case .success(let routes):
                print("🟨 CTB 找到 \(routes.count) 條路線")
                allCTBRoutes.append(contentsOf: routes)
            case .failure(let error):
                print("❌ CTB 查詢失敗: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchCTBRouteStopsForCompany(stopId: stopId, company: "NWFB") { result in
            switch result {
            case .success(let routes):
                print("🟠 NWFB 找到 \(routes.count) 條路線")
                allCTBRoutes.append(contentsOf: routes)
            case .failure(let error):
                print("❌ NWFB 查詢失敗: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            let uniqueRoutes = allCTBRoutes.uniqued { route in
                "\(route.company.rawValue)_\(route.routeNumber)_\(route.direction)"
            }
            print("✅ CTB/NWFB 總共找到 \(uniqueRoutes.count) 條路線")
            completion(.success(uniqueRoutes))
        }
    }
    
    private func fetchCTBRouteStopsForCompany(stopId: String, company: String, completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        let urlString = "https://rt.data.gov.hk/v2/transport/citybus/route-stop/\(company)"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
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
                let routeStopResponse = try JSONDecoder().decode(CTBRouteStopResponse.self, from: data)
                
                // Filter routes that pass through this stop
                let routesAtStop = routeStopResponse.data.filter { $0.stop == stopId }
                
                // Convert to StopRoute objects and remove duplicates
                var stopRoutes: [StopRoute] = []
                let group = DispatchGroup()
                
                for routeStop in routesAtStop {
                    let key = "\(routeStop.route)_\(routeStop.dir)"
                    
                    // Skip if we already processed this route-direction combination
                    if !stopRoutes.contains(where: { $0.routeNumber == routeStop.route && $0.direction == (routeStop.dir.lowercased() == "o" ? "outbound" : "inbound") }) {
                        group.enter()
                        
                        let direction = routeStop.dir.lowercased() == "o" ? "outbound" : "inbound"
                        let busCompany: BusRoute.Company = company == "CTB" ? .CTB : .NWFB
                        
                        // Get real destination from route API
                        self.getCTBRouteDestination(route: routeStop.route, company: company, direction: routeStop.dir) { destination in
                            let stopRoute = StopRoute(
                                routeNumber: routeStop.route,
                                company: busCompany,
                                direction: direction,
                                destination: destination
                            )
                            stopRoutes.append(stopRoute)
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    let results = stopRoutes.sorted { $0.routeNumber < $1.routeNumber }
                    completion(.success(results))
                }
                
            } catch {
                print("\(company) 路線站點解析錯誤: \(error.localizedDescription)")
                completion(.success([])) // Return empty instead of error to continue with other APIs
            }
        }.resume()
    }
    
    private func getCTBRouteDestination(route: String, company: String, direction: String, completion: @escaping (String) -> Void) {
        let urlString = "https://rt.data.gov.hk/v2/transport/citybus/route/\(company)/\(route)"
        guard let url = URL(string: urlString) else {
            // Use full direction string for comparison
            let isOutbound = direction == "outbound" || direction.lowercased() == "o"
            completion(isOutbound ? "→ 終點站" : "→ 起點站")
            return
        }

        session.dataTask(with: url) { data, response, error in
            guard let data = data,
                  error == nil else {
                let isOutbound = direction == "outbound" || direction.lowercased() == "o"
                completion(isOutbound ? "→ 終點站" : "→ 起點站")
                return
            }

            do {
                let routeResponse = try JSONDecoder().decode(BusRouteInfo.self, from: data)
                // Use full direction string for comparison
                let isOutbound = direction == "outbound" || direction.lowercased() == "o"
                let destinationName = isOutbound ?
                    routeResponse.data.dest_tc :
                    routeResponse.data.orig_tc
                let formattedDestination = "→ \(destinationName)"
                completion(formattedDestination)
            } catch {
                let isOutbound = direction == "outbound" || direction.lowercased() == "o"
                completion(isOutbound ? "→ 終點站" : "→ 起點站")
            }
        }.resume()
    }
    
    private func generateMockRoutesForStop(stopId: String) -> [StopRoute] {
        // Provide some mock routes for testing popular Hong Kong bus stops
        let mockRouteData: [String: [StopRoute]] = [
            // Tseung Kwan O Station
            "TK561": [
                StopRoute(routeNumber: "796X", company: .CTB, direction: "outbound", destination: "機場"),
                StopRoute(routeNumber: "98D", company: .KMB, direction: "outbound", destination: "尖沙咀東"),
                StopRoute(routeNumber: "290A", company: .KMB, direction: "inbound", destination: "將軍澳"),
            ],
            // Central
            "001826": [
                StopRoute(routeNumber: "5B", company: .CTB, direction: "outbound", destination: "銅鑼灣"),
                StopRoute(routeNumber: "15", company: .CTB, direction: "outbound", destination: "中環"),
            ],
            // Admiralty
            "002917": [
                StopRoute(routeNumber: "11", company: .CTB, direction: "outbound", destination: "中環"),
                StopRoute(routeNumber: "970", company: .CTB, direction: "inbound", destination: "蘇屋"),
            ]
        ]
        
        return mockRouteData[stopId] ?? []
    }
    
    // MARK: - Location-based Route Search
    private func getStopLocationInfo(stopId: String, completion: @escaping (Result<(lat: Double, lon: Double), Error>) -> Void) {
        // Find the stop in our cached stop data
        if let cachedStops = self.getCachedStops() {
            for stop in cachedStops {
                if stop.stopId == stopId, let lat = stop.latitude, let lon = stop.longitude {
                    completion(.success((lat: lat, lon: lon)))
                    return
                }
            }
        }
        completion(.failure(APIError.noData))
    }
    
    private func fetchRoutesForStopWithLocation(stopId: String, location: (lat: Double, lon: Double), completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        print("📍 使用位置查詢站點路線: \(stopId) at (\(location.lat), \(location.lon))")
        
        // Find nearby actual KMB stops within ~200m radius
        fetchNearbyKMBStops(latitude: location.lat, longitude: location.lon, radiusMeters: 200) { [weak self] nearbyResult in
            switch nearbyResult {
            case .success(let nearbyStops):
                print("🔍 找到 \(nearbyStops.count) 個附近的 KMB 站點")
                self?.fetchRoutesForNearbyStops(nearbyStops, completion: completion)
                
            case .failure(let error):
                print("❌ 附近站點查詢失敗: \(error.localizedDescription)")
                // Fallback to direct ID matching
                self?.fetchRoutesForStopDirectly(stopId: stopId, completion: completion)
            }
        }
    }
    
    private func fetchNearbyKMBStops(latitude: Double, longitude: Double, radiusMeters: Double, completion: @escaping (Result<[String], Error>) -> Void) {
        // Get all KMB stops and filter by distance
        let urlString = "https://data.etabus.gov.hk/v1/transport/kmb/stop"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
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
                let stopResponse = try JSONDecoder().decode(KMBStopListResponse.self, from: data)
                
                let nearbyStops = stopResponse.data.compactMap { stop -> String? in
                    guard let stopLat = stop.latitude, let stopLon = stop.longitude else { return nil }
                    
                    // Calculate distance using Haversine formula
                    let distance = self.calculateDistance(
                        lat1: latitude, lon1: longitude,
                        lat2: stopLat, lon2: stopLon
                    )
                    
                    return distance <= radiusMeters ? stop.stop : nil
                }
                
                completion(.success(nearbyStops))
                
            } catch {
                print("KMB 站點解析錯誤: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func fetchRoutesForNearbyStops(_ nearbyStops: [String], completion: @escaping (Result<[StopRoute], Error>) -> Void) {
        var allRoutes: [StopRoute] = []
        let group = DispatchGroup()
        
        for stopId in nearbyStops.prefix(5) { // Limit to first 5 nearby stops
            group.enter()
            fetchKMBRoutesForStop(stopId: stopId) { result in
                if case .success(let routes) = result {
                    allRoutes.append(contentsOf: routes)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Remove duplicates
            let uniqueRoutes = Array(Set(allRoutes.map { "\($0.company.rawValue)_\($0.routeNumber)_\($0.direction)" }))
                .compactMap { uniqueKey -> StopRoute? in
                    allRoutes.first { "\($0.company.rawValue)_\($0.routeNumber)_\($0.direction)" == uniqueKey }
                }
                .sorted { $0.routeNumber < $1.routeNumber }
            
            print("✅ 附近站點總共找到 \(uniqueRoutes.count) 條獨特路線")
            completion(.success(uniqueRoutes))
        }
    }
    
    // Calculate distance between two coordinates using Haversine formula
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth's radius in meters
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon/2) * sin(dLon/2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        return R * c
    }
    
    private func getCachedStops() -> [StopSearchResult]? {
        // Return cached stops from previous searches if available
        // This could be enhanced to use a persistent cache
        return nil
    }
    
    func searchStops(stopName: String, completion: @escaping (Result<[StopSearchResult], Error>) -> Void) {
        // Check cache first
        if let cachedResults = getCachedStopSearch(for: stopName) {
            print("使用站點搜尋緩存: \(stopName)")
            completion(.success(cachedResults))
            return
        }
        
        // Search from all stops
        fetchAllBusStops { [weak self] result in
            switch result {
            case .success(let allStops):
                let queryLower = stopName.lowercased()
                
                // Filter stops that match the search query
                let matchingStops = allStops.filter { stop in
                    stop.nameTC.lowercased().contains(queryLower) ||
                    (stop.nameEN?.lowercased().contains(queryLower) ?? false)
                }
                
                let results = Array(matchingStops.prefix(20)) // Limit to 20 results
                
                // Cache the results
                self?.setCachedStopSearch(for: stopName, results: results)
                completion(.success(results))
                
            case .failure(_):
                // Fallback to mock data
                print("從真實 API 搜尋失敗，使用模擬資料")
                let mockResults = self?.generateMockStopSearchResults(for: stopName) ?? []
                self?.setCachedStopSearch(for: stopName, results: mockResults)
                completion(.success(mockResults))
            }
        }
    }
    
    private func generateMockStopSearchResults(for query: String) -> [StopSearchResult] {
        let queryLower = query.lowercased()
        
        var results: [StopSearchResult] = []
        
        // Mock data for common stops that match the query
        if queryLower.contains("雍明") || queryLower.contains("wing ming") {
            let routes = [
                StopRoute(routeNumber: "793", company: .CTB, direction: "outbound", destination: "機場博覽館"),
                StopRoute(routeNumber: "795X", company: .CTB, direction: "outbound", destination: "機場(地面運輸中心)"),
                StopRoute(routeNumber: "796X", company: .CTB, direction: "outbound", destination: "機場(客運大樓)"),
                StopRoute(routeNumber: "798", company: .CTB, direction: "outbound", destination: "火炭站")
            ]
            results.append(StopSearchResult(
                stopId: "003472",
                nameTC: "雍明苑巴士總站",
                nameEN: "Wing Ming Estate Bus Terminus",
                latitude: 22.3128,
                longitude: 114.2598,
                routes: routes
            ))
        }
        
        if queryLower.contains("調景嶺") || queryLower.contains("tiu keng leng") {
            let routes = [
                StopRoute(routeNumber: "793", company: .CTB, direction: "outbound", destination: "機場博覽館"),
                StopRoute(routeNumber: "793", company: .CTB, direction: "inbound", destination: "雍明苑"),
                StopRoute(routeNumber: "796X", company: .CTB, direction: "outbound", destination: "機場(客運大樓)"),
                StopRoute(routeNumber: "796X", company: .CTB, direction: "inbound", destination: "雍明苑"),
                StopRoute(routeNumber: "40", company: .KMB, direction: "outbound", destination: "麗港城")
            ]
            results.append(StopSearchResult(
                stopId: "002917",
                nameTC: "調景嶺站",
                nameEN: "Tiu Keng Leng Station",
                latitude: 22.3140,
                longitude: 114.2610,
                routes: routes
            ))
        }
        
        if queryLower.contains("機場") || queryLower.contains("airport") {
            let routes = [
                StopRoute(routeNumber: "A21", company: .CTB, direction: "outbound", destination: "機場(地面運輸中心)"),
                StopRoute(routeNumber: "A22", company: .CTB, direction: "outbound", destination: "機場(地面運輸中心)"),
                StopRoute(routeNumber: "E23", company: .CTB, direction: "outbound", destination: "機場(客運大樓)")
            ]
            results.append(StopSearchResult(
                stopId: "001234",
                nameTC: "機場(地面運輸中心)",
                nameEN: "Airport (Ground Transportation Centre)",
                latitude: 22.3089,
                longitude: 113.9378,
                routes: routes
            ))
        }
        
        if queryLower.contains("中環") || queryLower.contains("central") {
            let routes = [
                StopRoute(routeNumber: "1", company: .CTB, direction: "outbound", destination: "跑馬地(上)"),
                StopRoute(routeNumber: "5B", company: .CTB, direction: "outbound", destination: "銅鑼灣"),
                StopRoute(routeNumber: "11", company: .CTB, direction: "outbound", destination: "中環碼頭"),
                StopRoute(routeNumber: "15", company: .CTB, direction: "outbound", destination: "山頂")
            ]
            results.append(StopSearchResult(
                stopId: "001001",
                nameTC: "中環(港澳碼頭)",
                nameEN: "Central (Macau Ferry)",
                latitude: 22.2877,
                longitude: 114.1546,
                routes: routes
            ))
        }
        
        if queryLower.contains("尖沙咀") || queryLower.contains("tsim sha tsui") {
            let routes = [
                StopRoute(routeNumber: "1", company: .KMB, direction: "outbound", destination: "竹園邨"),
                StopRoute(routeNumber: "6", company: .KMB, direction: "outbound", destination: "荔枝角"),
                StopRoute(routeNumber: "9", company: .KMB, direction: "outbound", destination: "尖沙咀碼頭"),
                StopRoute(routeNumber: "N216", company: .KMB, direction: "outbound", destination: "油塘")
            ]
            results.append(StopSearchResult(
                stopId: "002001",
                nameTC: "尖沙咀碼頭巴士總站",
                nameEN: "Star Ferry Pier Bus Terminus",
                latitude: 22.294,
                longitude: 114.1691,
                routes: routes
            ))
        }
        
        return results.prefix(10).map { $0 } // Return max 10 results
    }
    
    // MARK: - Helper Methods
    
    private func extractOrigin(from route: BusRoute) -> String {
        // Extract origin from subtitle or provide default
        if route.subTitle.contains("雍明苑") {
            return "雍明苑"
        } else if route.subTitle.contains("調景嶺") {
            return "調景嶺站"
        }
        return "起點"
    }
    
    private func extractDestination(from route: BusRoute) -> String {
        // This would normally come from route API
        // For now, provide common destinations
        switch route.route {
        case "793":
            return route.direction == "outbound" ? "機場博覽館" : "雍明苑"
        case "795X":
            return route.direction == "outbound" ? "機場(地面運輸中心)" : "雍明苑"
        case "796X":
            return route.direction == "outbound" ? "機場(客運大樓)" : "調景嶺站"
        case "796P":
            return route.direction == "outbound" ? "機場(地面運輸中心)" : "調景嶺站"
        case "798":
            return route.direction == "outbound" ? "火炭站" : "雍明苑"
        default:
            return "目的地"
        }
    }
    
    private func generateMockStops(for route: BusRoute) -> [BusStop] {
        // Generate realistic stops based on route
        switch route.route {
        case "793":
            return [
                BusStop(stopId: "003472", sequence: 1, nameTC: "雍明苑巴士總站", nameEN: "Wing Ming Estate Bus Terminus", latitude: 22.3128, longitude: 114.2598),
                BusStop(stopId: "003473", sequence: 2, nameTC: "雍明苑", nameEN: "Wing Ming Estate", latitude: 22.3130, longitude: 114.2600),
                BusStop(stopId: "003474", sequence: 3, nameTC: "尚德邨尚美樓", nameEN: "Sheung Tak Estate Sheung Mei House", latitude: 22.3135, longitude: 114.2605),
                BusStop(stopId: "002917", sequence: 4, nameTC: "調景嶺站", nameEN: "Tiu Keng Leng Station", latitude: 22.3140, longitude: 114.2610)
            ]
        case "795X":
            return [
                BusStop(stopId: "003472", sequence: 1, nameTC: "雍明苑巴士總站", nameEN: "Wing Ming Estate Bus Terminus", latitude: 22.3128, longitude: 114.2598),
                BusStop(stopId: "003475", sequence: 2, nameTC: "厚德邨", nameEN: "Hau Tak Estate", latitude: 22.3132, longitude: 114.2602),
                BusStop(stopId: "002917", sequence: 3, nameTC: "調景嶺站", nameEN: "Tiu Keng Leng Station", latitude: 22.3140, longitude: 114.2610)
            ]
        default:
            return [
                BusStop(stopId: route.stopId, sequence: 1, nameTC: "巴士站", nameEN: "Bus Stop", latitude: nil, longitude: nil)
            ]
        }
    }
    
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .noData:
            return "沒有資料"
        case .decodingError:
            return "資料解析錯誤"
        }
    }
}