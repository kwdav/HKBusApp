import Foundation
import CoreLocation

// MARK: - Enhanced Search Models

struct BusRouteDetail: Codable, Hashable {
    let routeNumber: String
    let company: BusRoute.Company
    let direction: String
    let origin: String
    let destination: String
    let stops: [BusStop]
    let estimatedDuration: Int?
    let operatingHours: String?
    
    var displayDirection: String {
        return "\(origin) → \(destination)"
    }
    
    var uniqueId: String {
        return "\(company.rawValue)_\(routeNumber)_\(direction)"
    }
}

struct BusStop: Codable, Hashable {
    let stopId: String
    let sequence: Int
    let nameTC: String
    let nameEN: String?
    let latitude: Double?
    let longitude: Double?
    
    var location: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var displayName: String {
        return nameTC
    }
}

struct RouteSearchResult: Codable, Hashable {
    let routeNumber: String
    let company: BusRoute.Company
    let directions: [DirectionInfo]
    
    var uniqueId: String {
        return "\(company.rawValue)_\(routeNumber)"
    }
}

struct DirectionInfo: Codable, Hashable {
    let direction: String
    let origin: String
    let destination: String
    let stopCount: Int?
    
    var displayText: String {
        if let count = stopCount {
            return "\(origin) → \(destination) (\(count)個站)"
        } else {
            return "\(origin) → \(destination)"
        }
    }
}

// MARK: - Stop Search Models

struct StopSearchResult {
    let stopId: String
    let nameTC: String
    let nameEN: String?
    let latitude: Double?
    let longitude: Double?
    let routes: [StopRoute]
    
    var displayName: String {
        return nameTC
    }
    
    var routeCount: Int {
        return routes.count
    }
    
    var routeNumbers: String {
        return routes.map { $0.routeNumber }.prefix(5).joined(separator: ", ") + 
               (routes.count > 5 ? "..." : "")
    }
}

struct StopRoute {
    let routeNumber: String
    let company: BusRoute.Company
    let direction: String
    let destination: String
}

// MARK: - Original Models

struct BusRoute: Codable, Hashable {
    let stopId: String
    let route: String
    let companyId: String
    let direction: String
    let subTitle: String
    
    enum Company: String, CaseIterable, Codable {
        case CTB = "CTB"
        case KMB = "KMB"
        case NWFB = "NWFB"
    }
    
    var company: Company {
        return Company(rawValue: companyId) ?? .CTB
    }
    
    var uniqueId: String {
        return "\(companyId)_\(stopId)_\(route)_\(direction)"
    }
}

struct BusRouteConfiguration {
    static let defaultRoutes: [BusRoute] = [
        BusRoute(stopId: "003472", route: "793", companyId: "CTB", direction: "outbound", subTitle: "由雍明苑出發"),
        BusRoute(stopId: "003472", route: "795X", companyId: "CTB", direction: "outbound", subTitle: "由雍明苑出發"),
        BusRoute(stopId: "003472", route: "796X", companyId: "CTB", direction: "outbound", subTitle: "由雍明苑出發"),
        BusRoute(stopId: "003472", route: "796P", companyId: "CTB", direction: "outbound", subTitle: "由雍明苑出發"),
        BusRoute(stopId: "001826", route: "798", companyId: "CTB", direction: "outbound", subTitle: "由雍明苑出發"),
        BusRoute(stopId: "002917", route: "793", companyId: "CTB", direction: "outbound", subTitle: "到達調景嶺站"),
        BusRoute(stopId: "002917", route: "795X", companyId: "CTB", direction: "outbound", subTitle: "到達調景嶺站"),
        BusRoute(stopId: "002917", route: "796X", companyId: "CTB", direction: "outbound", subTitle: "到達調景嶺站"),
        BusRoute(stopId: "002917", route: "796P", companyId: "CTB", direction: "outbound", subTitle: "到達調景嶺站"),
        BusRoute(stopId: "002917", route: "793", companyId: "CTB", direction: "inbound", subTitle: "由調景嶺回家方向"),
        BusRoute(stopId: "002917", route: "796X", companyId: "CTB", direction: "inbound", subTitle: "由調景嶺回家方向"),
        BusRoute(stopId: "001764", route: "795X", companyId: "CTB", direction: "inbound", subTitle: "由調景嶺回家方向"),
        BusRoute(stopId: "001764", route: "796P", companyId: "CTB", direction: "inbound", subTitle: "由調景嶺回家方向"),
        BusRoute(stopId: "A60AE774B09A5E44", route: "40", companyId: "KMB", direction: "outbound", subTitle: "其他")
    ]
}