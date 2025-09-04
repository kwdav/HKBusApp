import Foundation

struct BusRoute: Codable, Hashable {
    let stopId: String
    let route: String
    let companyId: String
    let direction: String
    let subTitle: String
    
    enum Company: String, CaseIterable {
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