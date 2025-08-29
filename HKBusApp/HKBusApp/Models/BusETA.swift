import Foundation

struct BusETA: Codable {
    let eta: String?
    let dir: String
    let route: String?
    let stopId: String?
    
    var arrivalTime: Date? {
        guard let eta = eta else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.date(from: eta)
    }
    
    var minutesUntilArrival: Int {
        guard let arrivalTime = arrivalTime else { return -1 }
        let now = Date()
        let difference = arrivalTime.timeIntervalSince(now)
        return max(0, Int(round(difference / 60.0)))
    }
    
    var formattedETA: String {
        guard let arrivalTime = arrivalTime else { return "未有資料" }
        
        let minutes = minutesUntilArrival
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: arrivalTime)
        
        if minutes <= 0 {
            return "即將到達"
        } else {
            return "\(minutes)分鐘 (\(timeString))"
        }
    }
    
    var formattedETAWithSeparateTime: (minutes: String, time: String) {
        guard let arrivalTime = arrivalTime else { return ("未有資料", "") }
        
        let minutes = minutesUntilArrival
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: arrivalTime)
        
        if minutes <= 0 {
            return ("即將到達", "")
        } else {
            return ("\(minutes)分鐘", "(\(timeString))")
        }
    }
}

struct BusETAResponse: Codable {
    let data: [BusETA]
}

struct BusStopInfo: Codable {
    let data: BusStopData
}

struct BusStopData: Codable {
    let name_tc: String
    let name_en: String?
}

struct BusRouteInfo: Codable {
    let data: BusRouteData
}

struct BusRouteData: Codable {
    let orig_tc: String
    let dest_tc: String
    let orig_en: String?
    let dest_en: String?
}

struct BusDisplayData {
    let route: BusRoute
    let stopName: String
    let destination: String
    let etas: [BusETA]
    
    init(route: BusRoute, stopName: String = "", destination: String = "", etas: [BusETA] = []) {
        self.route = route
        self.stopName = stopName
        self.destination = destination
        self.etas = etas
    }
}

// MARK: - Route List API Response Models

struct CTBRouteListResponse: Codable {
    let data: [CTBRouteData]
}

struct CTBRouteData: Codable {
    let co: String
    let route: String
    let orig_tc: String
    let dest_tc: String
    let orig_en: String
    let dest_en: String
    let orig_sc: String?
    let dest_sc: String?
    let data_timestamp: String?
}

struct KMBRouteListResponse: Codable {
    let data: [KMBRouteData]
}

struct KMBRouteData: Codable {
    let route: String
    let bound: String
    let service_type: String
    let orig_tc: String
    let dest_tc: String
    let orig_en: String
    let dest_en: String
}

// MARK: - Route Stop API Response Models

struct CTBRouteStopResponse: Codable {
    let data: [CTBRouteStopData]
}

struct CTBRouteStopData: Codable {
    let co: String
    let route: String
    let dir: String
    let seq: Int
    let stop: String
}

struct KMBRouteStopResponse: Codable {
    let data: [KMBRouteStopData]
}

struct KMBRouteStopData: Codable {
    let route: String
    let bound: String
    let service_type: String
    let seq: Int
    let stop: String
}