import Foundation

class BusAPIService {
    static let shared = BusAPIService()
    
    private let session = URLSession.shared
    private var stopNameCache: [String: String] = [:]
    
    private init() {}
    
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