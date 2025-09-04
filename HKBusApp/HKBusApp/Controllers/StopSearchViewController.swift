import UIKit
import QuartzCore
import CoreLocation


class StopSearchViewController: UIViewController {
    
    // MARK: - Properties
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    private let locationManager = CLLocationManager()
    
    private var stopSearchResults: [StopSearchResult] = []
    private var nearbyStops: [StopSearchResult] = []
    private var isLoading = false
    private var searchTimer: Timer?
    private var isShowingNearby = true
    private var currentLocation: CLLocation?
    private var lastTapTime: TimeInterval = 0
    private let tapCooldown: TimeInterval = 1.0 // 1 second cooldown between taps
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearchBar()
        setupTableView()
        setupTapGesture()
        setupLocationManager()
        requestLocationAndLoadNearbyStops()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // No auto-focus - let user manually tap search bar
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Search bar
        searchBar.placeholder = "搜尋巴士站名稱"
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor.label
        searchBar.barTintColor = UIColor.systemBackground
        searchBar.showsCancelButton = false
        searchBar.autocapitalizationType = .none
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Customize search bar appearance for both light and dark mode
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = UIColor.label
            textField.backgroundColor = UIColor.secondarySystemBackground
        }
        
        // Table view
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0 // Reduce top padding for iOS 15+
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 44),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.returnKeyType = .search
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(StopSearchResultTableViewCell.self, forCellReuseIdentifier: StopSearchResultTableViewCell.identifier)
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Location Management
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // 100 meters
    }
    
    private func requestLocationAndLoadNearbyStops() {
        let status = locationManager.authorizationStatus
        print("📱 位置權限狀態: \(status.rawValue) - \(authorizationDescription(status))")
        
        switch status {
        case .notDetermined:
            print("🔒 請求位置權限...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ 位置權限已授予，開始更新位置")
            startLocationUpdates()
        case .denied, .restricted:
            print("❌ 位置權限被拒絕，使用香港中心位置")
            loadNearbyStopsWithFallbackLocation()
        @unknown default:
            print("⚠️ 未知位置權限狀態，使用香港中心位置")
            loadNearbyStopsWithFallbackLocation()
        }
    }
    
    private func authorizationDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未決定"
        case .restricted: return "受限制"
        case .denied: return "已拒絕"
        case .authorizedAlways: return "總是允許"
        case .authorizedWhenInUse: return "使用時允許"
        @unknown default: return "未知"
        }
    }
    
    private func startLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    private func loadNearbyStops(from location: CLLocation) {
        print("🔍 使用 LocalBusDataManager 獲取附近巴士站...")
        
        // LocalBusDataManager loads synchronously
        guard LocalBusDataManager.shared.loadBusData() else {
            print("❌ LocalBusDataManager 載入失敗，顯示熱門站點")
            showPopularStops()
            return
        }
        
        print("✅ LocalBusDataManager 數據已載入，開始搜索附近站點")
        
        // Use LocalBusDataManager for much faster nearby stops loading
        let nearbyStops = LocalBusDataManager.shared.getNearbyStops(location: location, radiusKm: 1.0, limit: 50)
                
        if nearbyStops.isEmpty {
            print("⚠️ 在1公里範圍內未找到巴士站，擴大搜索範圍...")
            let expandedStops = LocalBusDataManager.shared.getNearbyStops(location: location, radiusKm: 3.0, limit: 50)
                    
            if expandedStops.isEmpty {
                print("❌ 在3公里範圍內仍未找到巴士站，顯示熱門站點")
                showPopularStops()
                return
            }
                    
            print("✅ 在3公里範圍內找到 \(expandedStops.count) 個巴士站")
            updateNearbyStopsUI(expandedStops, location: location)
        } else {
            print("✅ 在1公里範圍內找到 \(nearbyStops.count) 個巴士站")
            updateNearbyStopsUI(nearbyStops, location: location)
        }
    }
    
    private func updateNearbyStopsUI(_ stops: [StopSearchResult], location: CLLocation) {
        // Debug: Print the nearest stops and their distances
        print("🎯 最近的5個巴士站：")
        for (index, stop) in stops.prefix(5).enumerated() {
            guard let lat = stop.latitude, let lon = stop.longitude else { continue }
            let distance = location.distance(from: CLLocation(latitude: lat, longitude: lon))
            print("  \(index + 1). \(stop.nameTC) (ID: \(stop.stopId)) - \(Int(distance))米")
        }
        
        DispatchQueue.main.async {
            self.nearbyStops = stops
            self.isShowingNearby = true
            self.tableView.reloadData()
        }
    }
    
    private func loadNearbyStopsWithFallbackLocation() {
        print("🌏 使用香港中心位置進行距離計算")
        
        // Use Hong Kong center location (Tsim Sha Tsui) as fallback
        let hongKongCenter = CLLocation(latitude: 22.2976, longitude: 114.1722)
        self.currentLocation = hongKongCenter
        
        // Use the same logic as real location, just with fallback coordinates
        loadNearbyStops(from: hongKongCenter)
    }
    
    private func showPopularStops() {
        print("🔥 顯示香港熱門巴士站")
        
        // Create some popular Hong Kong bus stops as fallback
        let popularStops = [
            StopSearchResult(
                stopId: "popular_1",
                nameTC: "中環 (港澳碼頭)",
                nameEN: "Central (Macau Ferry)",
                latitude: 22.288274,
                longitude: 114.150422,
                routes: []
            ),
            StopSearchResult(
                stopId: "popular_2", 
                nameTC: "跑馬地 (上)",
                nameEN: "Happy Valley (Upper)",
                latitude: 22.264400,
                longitude: 114.188642,
                routes: []
            ),
            StopSearchResult(
                stopId: "popular_3",
                nameTC: "尖沙咀 (中間道)",
                nameEN: "Tsim Sha Tsui (Middle Road)",
                latitude: 22.297600,
                longitude: 114.172200,
                routes: []
            ),
            StopSearchResult(
                stopId: "popular_4",
                nameTC: "銅鑼灣 (恩平道)",
                nameEN: "Causeway Bay (Yun Ping Road)",
                latitude: 22.278800,
                longitude: 114.181500,
                routes: []
            ),
            StopSearchResult(
                stopId: "popular_5",
                nameTC: "旺角 (西洋菜街)",
                nameEN: "Mong Kok (Sai Yeung Choi Street)",
                latitude: 22.318700,
                longitude: 114.169400,
                routes: []
            )
        ]
        
        DispatchQueue.main.async {
            self.nearbyStops = popularStops
            self.isShowingNearby = true
            self.tableView.reloadData()
            print("✅ 已顯示 \(popularStops.count) 個熱門巴士站")
        }
    }
    
    
    // MARK: - Search Methods
    private func performSearch(for query: String) {
        // If query is empty, show nearby stops or popular stops if nearby is empty
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            isShowingNearby = true
            // If we don't have nearby stops, show popular stops
            if nearbyStops.isEmpty {
                showPopularStops()
            } else {
                tableView.reloadData()
            }
            return
        }
        
        // Only search if query has meaningful content (at least 2 characters for stops)
        guard query.count >= 2 else {
            isShowingNearby = true
            stopSearchResults = []
            tableView.reloadData()
            return
        }
        
        isShowingNearby = false
        searchStops(query: query)
    }
    
    private func searchStops(query: String) {
        guard !isLoading && !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        
        // LocalBusDataManager loads synchronously
        guard LocalBusDataManager.shared.loadBusData() else {
            print("❌ LocalBusDataManager 載入失敗")
            DispatchQueue.main.async {
                self.isLoading = false
                self.stopSearchResults = []
                self.isShowingNearby = false
                self.tableView.reloadData()
            }
            return
        }
        
        // Use LocalBusDataManager for much faster search
        let searchResults = LocalBusDataManager.shared.searchStops(query: query, limit: 50)
        
        DispatchQueue.main.async {
            self.isLoading = false
            print("站點搜尋結果: \(searchResults.count) 個站點")
            self.stopSearchResults = searchResults
            self.isShowingNearby = false
            self.tableView.reloadData()
        }
    }
}

// MARK: - UISearchBarDelegate
extension StopSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Cancel previous search timer
        searchTimer?.invalidate()
        
        // Debounce search with 0.5 second delay (longer for stop names)
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.performSearch(for: searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let searchText = searchBar.text, !searchText.isEmpty {
            performSearch(for: searchText)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        isShowingNearby = true
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension StopSearchViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isShowingNearby ? nearbyStops.count : stopSearchResults.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: StopSearchResultTableViewCell.identifier, for: indexPath) as? StopSearchResultTableViewCell else {
            return UITableViewCell()
        }
        
        let stopResult = isShowingNearby ? nearbyStops[indexPath.row] : stopSearchResults[indexPath.row]
        let distance = calculateDistanceText(to: stopResult)
        cell.configure(with: stopResult, distance: distance)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension StopSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isShowingNearby && !nearbyStops.isEmpty {
            return 32 // Reduced from default
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isShowingNearby && !nearbyStops.isEmpty {
            let headerView = UIView()
            headerView.backgroundColor = UIColor.systemBackground
            
            let titleLabel = UILabel()
            titleLabel.text = "附近站點"
            titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            titleLabel.textColor = UIColor.label
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            headerView.addSubview(titleLabel)
            
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12), // Reduced margin
                titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -4)
            ])
            
            return headerView
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Prevent rapid consecutive taps
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastTapTime < tapCooldown {
            print("⚠️ 點擊過快，請稍等...")
            return
        }
        lastTapTime = currentTime
        
        let stopResult = isShowingNearby ? nearbyStops[indexPath.row] : stopSearchResults[indexPath.row]
        
        // No need to save to history for nearby stops since it's location-based
        
        // Navigate to stop routes view
        showStopRoutes(stopResult: stopResult)
    }
    
    private func showStopRoutes(stopResult: StopSearchResult) {
        print("🔍 showStopRoutes: stopId=\(stopResult.stopId), routes=\(stopResult.routes.count)")
        for (index, route) in stopResult.routes.enumerated() {
            print("  Route \(index + 1): \(route.company.rawValue) \(route.routeNumber)")
        }
        
        let stopRoutesVC = StopRoutesViewController(stopResult: stopResult)
        
        // Custom transition animation
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .moveIn
        transition.subtype = .fromRight
        navigationController?.view.layer.add(transition, forKey: kCATransition)
        
        navigationController?.pushViewController(stopRoutesVC, animated: false)
    }
    
    // MARK: - Distance Calculation
    private func calculateDistanceText(to stopResult: StopSearchResult) -> String {
        guard let currentLocation = currentLocation,
              let stopLat = stopResult.latitude,
              let stopLon = stopResult.longitude else {
            print("⚠️ 無法計算距離 - 當前位置: \(currentLocation?.description ?? "nil"), 站點座標: \(stopResult.latitude?.description ?? "nil"), \(stopResult.longitude?.description ?? "nil")")
            return ""
        }
        
        let stopLocation = CLLocation(latitude: stopLat, longitude: stopLon)
        let distance = currentLocation.distance(from: stopLocation)
        
        // Debug: Log the first few distance calculations
        if stopResult.stopId == nearbyStops.first?.stopId {
            print("🔍 距離計算 - 用戶: (\(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)), 站點 '\(stopResult.nameTC)': (\(stopLat), \(stopLon)), 距離: \(Int(distance))米")
        }
        
        // Format distance based on range
        if distance < 1000 {
            // Less than 1km, show in meters
            return "\(Int(distance))米"
        } else {
            // 1km or more, show in km with 1 decimal place
            return String(format: "%.1f公里", distance / 1000.0)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension StopSearchViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            loadNearbyStopsWithFallbackLocation()
        case .notDetermined:
            break // Wait for user to respond
        @unknown default:
            loadNearbyStopsWithFallbackLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Stop location updates to save battery
        locationManager.stopUpdatingLocation()
        
        // Store current location
        currentLocation = location
        print("📍 用戶位置: 緯度 \(location.coordinate.latitude), 經度 \(location.coordinate.longitude)")
        
        // Load nearby stops based on current location
        loadNearbyStops(from: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置服務錯誤: \(error.localizedDescription)")
        print("🌏 位置服務失敗，使用香港中心位置")
        loadNearbyStopsWithFallbackLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📱 位置權限狀態變更: \(status.rawValue) - \(authorizationDescription(status))")
        requestLocationAndLoadNearbyStops()
    }
}