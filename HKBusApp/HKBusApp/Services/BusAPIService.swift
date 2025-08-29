import Foundation

class BusAPIService {
    static let shared = BusAPIService()
    
    private let session = URLSession.shared
    private var stopNameCache: [String: String] = [:]
    
    // MARK: - Cache Properties
    private var routeSearchCache: [String: [RouteSearchResult]] = [:]
    private var stopSearchCache: [String: [StopSearchResult]] = [:]
    private var routeDetailCache: [String: BusRouteDetail] = [:]
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
        guard let url = etaURL(for: route) else {
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
                let etaResponse = try JSONDecoder().decode(BusETAResponse.self, from: data)
                
                // Filter by direction
                let directionPrefix = route.direction.prefix(1).uppercased()
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
                    destination = "返：\(routeInfo.data.orig_tc)"
                } else {
                    destination = "往：\(routeInfo.data.dest_tc)"
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
                    estimatedDuration: self.estimateDuration(for: routeNumber),
                    operatingHours: "06:00 - 23:30"
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
                    sequence: stopData.seq,
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
                    sequence: stopData.seq,
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
            if stopNameCache[stop.stopId] == nil {
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
                        // Update the stop with the fetched name
                        updatedStops[index] = BusStop(
                            stopId: stop.stopId,
                            sequence: stop.sequence,
                            nameTC: name,
                            nameEN: stop.nameEN,
                            latitude: stop.latitude,
                            longitude: stop.longitude
                        )
                    }
                    group.leave()
                }
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
                estimatedDuration: self.estimateDuration(for: routeNumber),
                operatingHours: "06:00 - 23:30"
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
    
    func searchStops(stopName: String, completion: @escaping (Result<[StopSearchResult], Error>) -> Void) {
        // Check cache first
        if let cachedResults = getCachedStopSearch(for: stopName) {
            print("使用站點搜尋緩存: \(stopName)")
            completion(.success(cachedResults))
            return
        }
        
        // For now, create mock data as stop search API is more complex
        // In a real implementation, you would call actual stop search APIs
        DispatchQueue.global(qos: .userInitiated).async {
            
            // Mock stop search results based on common stop names
            let mockResults = self.generateMockStopSearchResults(for: stopName)
            
            DispatchQueue.main.async {
                // Cache the results
                self.setCachedStopSearch(for: stopName, results: mockResults)
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
    
    private func estimateDuration(for routeNumber: String) -> Int {
        // Estimate journey time in minutes
        switch routeNumber {
        case "793": return 45
        case "795X": return 50
        case "796X": return 40
        case "796P": return 35
        case "798": return 30
        default: return 25
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