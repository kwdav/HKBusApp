import UIKit
import QuartzCore
import CoreLocation

class SearchViewController: UIViewController {
    
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let customKeyboard = BusRouteKeyboard()
    private let refreshControl = UIRefreshControl()
    private let searchBarBackgroundView = UIView()
    // Remove segmented control for now, only support route search
    
    private var routeSearchResults: [RouteSearchResult] = []
    private var stopSearchResults: [SearchResult] = []
    private var busDisplayData: [BusDisplayData] = []
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    private var isLoading = false
    private var searchTimer: Timer?
    private var currentSearchText = ""
    private let localDataManager = LocalBusDataManager.shared
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var isKeyboardVisible = false
    private var locationTimer: Timer?
    private var isUpdatingFromKeyboard = false  // Flag to prevent circular updates
    
    // Structure to track route with distance and stop name
    private struct RouteWithDistance {
        let stopRoute: StopRoute
        let distance: Double
        let stopName: String
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure content extends under translucent bars
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        setupUI()
        setupSearchBar()
        setupTableView()
        setupCustomKeyboard()
        setupTapGesture()
        setupLocationManager()

        // Immediately load nearby routes without waiting for GPS
        loadNearbyRoutesImmediately()

        // Listen for font size changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fontSizeDidChange),
            name: FontSizeManager.fontSizeDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func fontSizeDidChange() {
        tableView.reloadData()
    }
    
    // Show status bar to display clock and battery
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Sync state between searchBar.text and currentSearchText early
        syncSearchStates()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Don't auto focus search bar - user will use custom keyboard
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Search bar background with clean iOS-style appearance
        searchBarBackgroundView.backgroundColor = UIColor.systemBackground
        searchBarBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        // Search bar
        searchBar.placeholder = "搜尋路線..."
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor.label
        searchBar.backgroundColor = UIColor.systemBackground
        searchBar.barTintColor = UIColor.systemBackground
        searchBar.showsCancelButton = false  // Initially hidden, will show when text is entered
        searchBar.autocapitalizationType = .allCharacters
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Customize search bar appearance for clean visibility
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = UIColor.label
            textField.backgroundColor = UIColor.secondarySystemBackground
            textField.layer.cornerRadius = 10
            textField.layer.borderWidth = 0.5
            textField.layer.borderColor = UIColor.separator.cgColor
        }
        
        // Customize Cancel button text
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).title = "重設"
        
        // No segmented control - only route search for now
        
        // Table view
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        view.addSubview(searchBarBackgroundView)  // Add background first
        view.addSubview(searchBar)  // Add search bar on top
        view.addSubview(customKeyboard)
        
        NSLayoutConstraint.activate([
            // Search bar background - full width at top, under status bar but above safe area
            searchBarBackgroundView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBarBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBarBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBarBackgroundView.heightAnchor.constraint(equalToConstant: 44),
            
            // Search bar - positioned at safe area top (below status bar)
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),  // Keep some padding for text
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),  // Keep some padding for text
            searchBar.heightAnchor.constraint(equalToConstant: 44),
            
            // Table view - starts below search bar background to avoid overlay
            tableView.topAnchor.constraint(equalTo: searchBarBackgroundView.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor), // Extend under tab bar
            
            // Custom keyboard - overlaid on top of table view, positioned above tab bar
            customKeyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customKeyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customKeyboard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), // Above tab bar
            customKeyboard.heightAnchor.constraint(equalToConstant: 260)
        ])
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.returnKeyType = .search
        
        // Disable the system keyboard - we use custom keyboard
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.inputView = UIView() // Empty input view to hide system keyboard
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        // Enable automatic content inset for translucent bars
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.sectionHeaderTopPadding = 0 // Reduce top padding for iOS 15+
        tableView.register(SearchResultTableViewCell.self, forCellReuseIdentifier: SearchResultTableViewCell.identifier)
        tableView.register(BusETATableViewCell.self, forCellReuseIdentifier: BusETATableViewCell.identifier)
        
        // Setup refresh control for pull-to-refresh
        refreshControl.tintColor = UIColor.label
        refreshControl.attributedTitle = NSAttributedString(
            string: "更新附近路線",
            attributes: [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14)]
        )
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func setupCustomKeyboard() {
        customKeyboard.delegate = self
        customKeyboard.isHidden = true // Initially hidden
        isKeyboardVisible = false
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Only update if moved 100m
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        
        // Only dismiss keyboard if tap is outside the keyboard area
        if isKeyboardVisible && !customKeyboard.frame.contains(location) {
            view.endEditing(true)
            hideKeyboard()
        }
    }
    
    private func showKeyboard() {
        guard !isKeyboardVisible else { return }
        customKeyboard.show(animated: true)
        isKeyboardVisible = true
        
        // Adjust table view insets when keyboard is shown
        updateTableViewInsets()
    }
    
    private func hideKeyboard() {
        guard isKeyboardVisible else { return }
        customKeyboard.hide(animated: true)
        isKeyboardVisible = false

        // Sync states when hiding keyboard to ensure consistency
        syncSearchStates()

        // Adjust table view insets when keyboard is hidden
        updateTableViewInsets()
    }
    
    private func updateTableViewInsets() {
        var bottomInset: CGFloat = 0
        
        if isKeyboardVisible {
            // When keyboard is visible, add keyboard height since it's now positioned above tab bar
            bottomInset = 260 // keyboard height (no extra margin needed since keyboard is above tab bar)
        } else {
            // When keyboard is hidden, account for tab bar height
            bottomInset = 0
        }
        
        UIView.animate(withDuration: 0.25) {
            self.tableView.contentInset.bottom = bottomInset
            self.tableView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }
    
    @objc private func handleRefresh() {
        print("🔄 用戶下拉刷新附近路線")
        
        // Hide keyboard if visible
        if isKeyboardVisible {
            hideKeyboard()
            searchBar.resignFirstResponder()
        }
        
        // Clear current search results to show only nearby routes
        routeSearchResults = []
        currentSearchText = ""
        searchBar.text = ""
        searchBar.setShowsCancelButton(false, animated: true)
        
        // Force refresh nearby routes with new location
        currentLocation = nil // Clear cached location to force new location request
        
        // Start location updates for fresh data
        locationManager.requestLocation()
        
        // Also load immediately with cached/fallback location
        loadNearbyRoutesImmediately()
        
        // End refresh after a short delay to show completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshControl.endRefreshing()
        }
    }
    
    
    private func startLocationTimeout() {
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            print("⏰ 位置獲取超時，保持顯示默認路線")
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    // MARK: - Public Methods for Tab Interaction
    func showKeyboardOnTabSwitch() {
        // This method is now only called when user taps the route search tab repeatedly
        // Always show keyboard when called (no conditions needed)
        if !isKeyboardVisible {
            showKeyboard()
            searchBar.becomeFirstResponder()
        }
    }
    
    // MARK: - Immediate Loading
    private func loadNearbyRoutesImmediately() {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("⚡ 開始快速載入附近路線...")
        
        // Strategy 1: Try to use cached/last known location first
        if let cachedLocation = getCachedLocation() {
            print("📍 使用緩存位置: \(cachedLocation.coordinate.latitude), \(cachedLocation.coordinate.longitude)")
            loadRoutesFromNearbyStops(location: cachedLocation)
            return
        }
        
        // Strategy 2: Use significant location change for faster location
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer  // Lower accuracy for speed
        locationManager.requestLocation()
        
        // Strategy 3: Fallback to Central HK if no location within 0.8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if self.currentLocation == nil {
                let centralLocation = CLLocation(latitude: 22.2819, longitude: 114.1585)
                print("⚡ 0.8秒內無法獲取位置，使用Central作為預設位置")
                self.loadRoutesFromNearbyStops(location: centralLocation)
            }
        }
        
        let setupTime = CFAbsoluteTimeGetCurrent()
        print("⚡ 快速載入設置完成，耗時: \(String(format: "%.3f", setupTime - startTime))秒")
    }
    
    private func getCachedLocation() -> CLLocation? {
        // Try to get last known location from UserDefaults
        let defaults = UserDefaults.standard
        if let lat = defaults.object(forKey: "lastKnownLat") as? Double,
           let lng = defaults.object(forKey: "lastKnownLng") as? Double {
            let cachedTime = defaults.object(forKey: "lastKnownTime") as? TimeInterval ?? 0
            
            // Use cached location if it's less than 10 minutes old
            if Date().timeIntervalSince1970 - cachedTime < 600 {
                return CLLocation(latitude: lat, longitude: lng)
            }
        }
        return nil
    }
    
    private func saveCachedLocation(_ location: CLLocation) {
        let defaults = UserDefaults.standard
        defaults.set(location.coordinate.latitude, forKey: "lastKnownLat")
        defaults.set(location.coordinate.longitude, forKey: "lastKnownLng")
        defaults.set(Date().timeIntervalSince1970, forKey: "lastKnownTime")
    }
    
    private func loadRoutesFromNearbyStops(location: CLLocation) {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔍 開始載入附近站點路線，位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Ensure data is loaded first (this should be fast due to caching)
        guard localDataManager.loadBusData() else {
            print("❌ 無法載入巴士數據")
            return
        }
        
        // Step 1: Find nearest stops within 1km (maximum 30 stops for speed)
        let nearbyStops = localDataManager.getNearbyStops(location: location, radiusKm: 1.0, limit: 30)
        let findTime = CFAbsoluteTimeGetCurrent()
        print("📍 找到1km內站點: \(nearbyStops.count) 個，耗時: \(String(format: "%.3f", findTime - startTime))秒")
        
        if nearbyStops.isEmpty {
            print("⚠️ 1km內沒有找到站點")
            return // Keep showing default routes
        }
        
        // Step 2: Collect unique routes and find the closest stop for each route
        // Use simple key (company + route) to avoid showing same route number multiple times
        var routeDistanceMap = [String: (RouteWithDistance, Double)]() // Map route key to closest stop data
        
        for stopResult in nearbyStops {
            let stopLocation = CLLocation(latitude: stopResult.latitude!, longitude: stopResult.longitude!)
            let distance = location.distance(from: stopLocation)
            
            for stopRoute in stopResult.routes {
                // Create simple unique key: company + route (ignoring direction and destination)
                // This ensures each route number appears only once
                let routeKey = "\(stopRoute.company.rawValue)_\(stopRoute.routeNumber)"
                
                let routeWithDistance = RouteWithDistance(
                    stopRoute: stopRoute,
                    distance: distance,
                    stopName: stopResult.displayName
                )
                
                // Keep only the closest stop for each route number
                if let existingEntry = routeDistanceMap[routeKey] {
                    if distance < existingEntry.1 {
                        routeDistanceMap[routeKey] = (routeWithDistance, distance)
                        print("🔄 更新路線 \(stopRoute.routeNumber) 到更近的站點 \(stopResult.displayName) (距離: \(Int(distance))米)")
                    } else {
                        print("⏭️ 跳過較遠的站點 \(stopResult.displayName) for 路線 \(stopRoute.routeNumber) (距離: \(Int(distance))米 vs \(Int(existingEntry.1))米)")
                    }
                } else {
                    routeDistanceMap[routeKey] = (routeWithDistance, distance)
                    print("➕ 新增路線 \(stopRoute.routeNumber) from 站點 \(stopResult.displayName) (距離: \(Int(distance))米)")
                }
            }
        }
        
        // Extract the routes data from the map
        let routesData = Array(routeDistanceMap.values.map { $0.0 })
        
        let processTime = CFAbsoluteTimeGetCurrent()
        print("🚌 處理到 \(routesData.count) 條獨特路線，耗時: \(String(format: "%.3f", processTime - findTime))秒")
        
        if routesData.isEmpty {
            return // Keep showing default routes
        }
        
        // Step 3: Sort by distance and route number
        let sortedRoutes = routesData.sorted { route1, route2 in
            // First by distance
            if route1.distance != route2.distance {
                return route1.distance < route2.distance
            }
            // Then by route number
            return route1.stopRoute.routeNumber.localizedStandardCompare(route2.stopRoute.routeNumber) == .orderedAscending
        }
        
        // Step 4: Create display data with stop IDs resolved immediately
        busDisplayData = sortedRoutes.compactMap { routeWithDistance in
            // Find the stop ID for this route from our nearby stops
            guard let matchingStop = nearbyStops.first(where: { stopResult in
                return stopResult.routes.contains { stopRoute in
                    stopRoute.routeNumber == routeWithDistance.stopRoute.routeNumber &&
                    stopRoute.company == routeWithDistance.stopRoute.company &&
                    stopRoute.direction == routeWithDistance.stopRoute.direction
                }
            }) else {
                print("⚠️ 找不到對應站點 ID for route: \(routeWithDistance.stopRoute.routeNumber)")
                return nil
            }
            
            let stopRoute = routeWithDistance.stopRoute
            let busRoute = BusRoute(
                stopId: matchingStop.stopId, // Now we have the correct stop ID
                route: stopRoute.routeNumber,
                companyId: stopRoute.company.rawValue,
                direction: stopRoute.direction,
                subTitle: stopRoute.destination
            )
            
            // Format distance for display
            let distanceText: String
            if routeWithDistance.distance < 1000 {
                // Less than 1km, show in meters
                distanceText = "(\(Int(routeWithDistance.distance))米)"
            } else {
                // 1km or more, show in km with 1 decimal place
                distanceText = "(\(String(format: "%.1f", routeWithDistance.distance / 1000.0))公里)"
            }
            
            return BusDisplayData(
                route: busRoute,
                stopName: "\(routeWithDistance.stopName) \(distanceText)",
                destination: stopRoute.destination,
                etas: [],
                isLoadingETAs: true // Show "..." initially
            )
        }
        
        let displayTime = CFAbsoluteTimeGetCurrent()
        print("✅ 附近路線準備完成，總耗時: \(String(format: "%.3f", displayTime - startTime))秒")
        
        // Step 5: Update UI immediately
        DispatchQueue.main.async {
            self.tableView.reloadData()
            print("📱 附近路線顯示完成，開始載入ETA...")
            // Step 6: Load ETAs after UI update
            self.loadETAsForNearbyRoutes(routesWithDistance: sortedRoutes)
        }
    }
    
    private func loadETAsForNearbyRoutes(routesWithDistance: [RouteWithDistance]) {
        print("🔄 開始載入ETA資料，共 \(routesWithDistance.count) 條路線")
        
        // Load ETAs in batches to avoid API rate limiting
        let batchSize = 5 // Process 5 routes at a time
        let batches = routesWithDistance.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            // Delay each batch to prevent API overload (stagger requests)
            let delay = Double(batchIndex) * 0.5 // 0.5 second delay between batches
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let isLastBatch = (batchIndex == batches.count - 1)
                self.loadETABatch(batch: batch, batchIndex: batchIndex, isLastBatch: isLastBatch)
            }
        }
    }
    
    private func loadETABatch(batch: [RouteWithDistance], batchIndex: Int, isLastBatch: Bool = false) {
        print("📦 載入批次 \(batchIndex + 1)，包含 \(batch.count) 條路線，是否最後批次: \(isLastBatch)")
        
        let dispatchGroup = DispatchGroup()
        
        for (routeIndex, routeWithDistance) in batch.enumerated() {
            let globalIndex = (batchIndex * 5) + routeIndex
            guard globalIndex < busDisplayData.count else { continue }
            
            let stopRoute = routeWithDistance.stopRoute
            
            // Get stop ID from busDisplayData (already resolved)
            guard globalIndex < self.busDisplayData.count,
                  !self.busDisplayData[globalIndex].route.stopId.isEmpty else {
                print("❌ 沒有找到站點ID for route: \(stopRoute.routeNumber)")
                continue
            }
            
            let stopId = self.busDisplayData[globalIndex].route.stopId
            
            dispatchGroup.enter()
            
            // Fetch ETA for this specific route and stop
            self.apiService.fetchStopETA(
                stopId: stopId,
                routeNumber: stopRoute.routeNumber,
                company: stopRoute.company,
                direction: stopRoute.direction
            ) { [weak self] result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .success(let etas):
                    DispatchQueue.main.async {
                        // Update the corresponding busDisplayData item
                        if globalIndex < self?.busDisplayData.count ?? 0 {
                            self?.busDisplayData[globalIndex].etas = etas
                            self?.busDisplayData[globalIndex].isLoadingETAs = false
                            
                            // Just reload the specific row, no need to resort
                            let indexPath = IndexPath(row: globalIndex, section: 0)
                            if self?.tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                                self?.tableView.reloadRows(at: [indexPath], with: .none)
                            }
                        }
                    }
                    print("✅ ETA載入成功: \(stopRoute.routeNumber) (\(etas.count) 班次)")
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        // Update loading state and clear ETAs on failure
                        if globalIndex < self?.busDisplayData.count ?? 0 {
                            self?.busDisplayData[globalIndex].isLoadingETAs = false
                            self?.busDisplayData[globalIndex].etas = [] // Ensure empty ETAs for sorting
                            
                            // Just reload the specific row, no need to resort
                            let indexPath = IndexPath(row: globalIndex, section: 0)
                            if self?.tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                                self?.tableView.reloadRows(at: [indexPath], with: .none)
                            }
                        }
                    }
                    print("❌ ETA載入失敗: \(stopRoute.routeNumber) - \(error.localizedDescription)")
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            print("📦 批次 \(batchIndex + 1) 載入完成")
            // Only trigger resort on the last batch completion
            if isLastBatch {
                print("🏁 最後批次完成，進行距離排序")
                self.resortBusDisplayData()
            }
        }
    }
    
    
    private func checkAndResortIfAllBatchesComplete() {
        // Check if all items have finished loading (no more isLoadingETAs = true)
        let stillLoading = busDisplayData.contains { $0.isLoadingETAs }
        
        if !stillLoading {
            print("📊 所有ETA載入完成，開始重新排序")
            resortBusDisplayData()
        }
    }
    
    private func resortBusDisplayData() {
        print("🔄 開始重新排序附近路線，按距離排序")
        
        busDisplayData.sort { item1, item2 in
            // 提取距離信息（從stopName中解析，格式如"站名 (100米)"）
            let distance1 = extractDistance(from: item1.stopName)
            let distance2 = extractDistance(from: item2.stopName)
            
            // 第一優先級：距離較近的在前
            if distance1 != distance2 {
                return distance1 < distance2
            }
            
            // 第二優先級：同樣距離下，按路線號碼排序
            return item1.route.route.localizedStandardCompare(item2.route.route) == .orderedAscending
        }
        
        print("✅ 排序完成：按距離排序，共 \(busDisplayData.count) 條路線")
        
        // Reload table view with animation
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    private func extractDistance(from stopName: String) -> Double {
        // 解析距離信息，格式如"站名 (100米)" 或 "站名 (1.2公里)"
        let pattern = #"(\d+(?:\.\d+)?)(米|公里)"#
        
        if let range = stopName.range(of: pattern, options: .regularExpression),
           let match = stopName[range].firstMatch(of: /(\d+(?:\.\d+)?)(米|公里)/) {
            let number = Double(String(match.1)) ?? 0.0
            let unit = String(match.2)
            
            // 統一轉換為米
            if unit == "公里" {
                return number * 1000.0
            } else {
                return number
            }
        }
        
        // 如果無法解析距離，返回一個很大的數字讓它排在最後
        return Double.greatestFiniteMagnitude
    }
    

    
    private func performSearch(for query: String) {
        // Verify state consistency before searching
        let searchBarText = searchBar.text ?? ""
        if query != currentSearchText {
            print("⚠️ 搜尋一致性警告 - query: '\(query)', currentSearchText: '\(currentSearchText)'")
            // Use currentSearchText as source of truth
            if !currentSearchText.isEmpty && currentSearchText != query {
                print("🔧 使用 currentSearchText 作為真實來源: '\(currentSearchText)'")
                performSearch(for: currentSearchText)
                return
            }
        }

        if query != searchBarText {
            print("⚠️ 搜尋一致性警告 - query: '\(query)', searchBar.text: '\(searchBarText)'")
        }

        // Only search if query has meaningful content (at least 1 character)
        guard query.count >= 1 else {
            // Show initial routes when no search query
            routeSearchResults = []
            if let location = currentLocation {
                loadRoutesFromNearbyStops(location: location)
            } else {
                // Reload nearby routes immediately
                loadNearbyRoutesImmediately()
            }
            return
        }

        searchRoutes(query: query)
    }
    
    private func searchRoutes(query: String) {
        guard !isLoading && !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        
        // Show loading state
        DispatchQueue.main.async {
            // Could add loading indicator here
        }
        
        apiService.searchRoutes(routeNumber: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let results):
                    print("搜尋結果: \(results.count) 個路線")
                    self?.routeSearchResults = results
                    self?.busDisplayData = [] // Clear initial routes when showing search results
                    self?.tableView.reloadData()
                    
                    // Scroll to top to show search results from the beginning
                    if !results.isEmpty {
                        self?.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
                    }
                case .failure(let error):
                    print("搜尋錯誤: \(error.localizedDescription)")
                    self?.routeSearchResults = []
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // If update is from custom keyboard, skip to prevent circular updates
        if isUpdatingFromKeyboard {
            print("⏭️ textDidChange 跳過 - 來自自定義鍵盤更新")
            return
        }

        print("📝 textDidChange 觸發 - 外部輸入: '\(searchText)'")

        // Sync currentSearchText with searchBar when user types via other means (paste, etc.)
        currentSearchText = searchText

        // Update keyboard button states based on new input
        if !searchText.isEmpty {
            customKeyboard.updateButtonStates(for: searchText)
        } else {
            customKeyboard.resetAllButtons()
        }

        // Show/hide cancel button based on text content
        let hasText = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
        searchBar.setShowsCancelButton(hasText, animated: true)

        // Cancel previous search timer
        searchTimer?.invalidate()

        guard hasText else {
            routeSearchResults = []
            tableView.reloadData()
            return
        }

        // Debounce search with 0.3 second delay
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
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
        // Clear all search-related data - ensure both states are reset
        searchBar.text = ""
        currentSearchText = ""
        routeSearchResults = []

        // Reset keyboard button states to default
        customKeyboard.resetAllButtons()

        // Hide cancel button since text is now empty
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()

        // Hide keyboard if visible
        if isKeyboardVisible {
            hideKeyboard()
        }

        // Reload nearby routes to restore the initial state
        loadNearbyRoutesImmediately()

        tableView.reloadData()

        print("🔄 重設搜尋 - searchBar和currentText都已清空")
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Show custom keyboard when search bar is tapped
        showKeyboard()
        return true
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        return true
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !routeSearchResults.isEmpty {
            return routeSearchResults.count
        } else {
            return busDisplayData.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // If showing search results, use SearchResultTableViewCell
        if !routeSearchResults.isEmpty {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultTableViewCell.identifier, for: indexPath) as? SearchResultTableViewCell else {
                return UITableViewCell()
            }
            
            let routeResult = routeSearchResults[indexPath.row]
            let searchResult = SearchResult(
                type: .route,
                title: routeResult.routeNumber,
                subtitle: routeResult.directions.map { $0.displayText }.joined(separator: " | "),
                route: nil,
                routeSearchResult: routeResult
            )
            cell.configure(with: searchResult)
            return cell
        }
        // If showing initial routes, use BusETATableViewCell (same as bus time page)
        else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: BusETATableViewCell.identifier, for: indexPath) as? BusETATableViewCell else {
                return UITableViewCell()
            }

            let busData = busDisplayData[indexPath.row]
            cell.configure(with: busData)

            // Show star button and set favorite state
            cell.setStarButtonVisible(true)
            let isFavorite = favoritesManager.isFavorite(busData.route)
            cell.setFavoriteState(isFavorite)

            // Set favorite toggle callback
            cell.onFavoriteToggle = { [weak self] in
                self?.toggleFavorite(for: busData.route)
            }

            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Use different heights for different cell types
        if !routeSearchResults.isEmpty {
            return 70 // SearchResultTableViewCell
        } else {
            return 82 // BusETATableViewCell (same as bus time page)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Remove headers to maximize space usage
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Remove headers to maximize space usage
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Handle different modes
        if !routeSearchResults.isEmpty {
            // Search results mode
            let routeResult = routeSearchResults[indexPath.row]
            
            // If only one direction, go straight to route detail
            // If multiple directions, show direction selection
            if routeResult.directions.count == 1 {
                let direction = routeResult.directions[0]
                showRouteDetail(routeNumber: routeResult.routeNumber, 
                              company: routeResult.company, 
                              direction: direction.direction)
            } else {
                let sourceRect = tableView.rectForRow(at: indexPath)
                showDirectionSelection(for: routeResult, sourceRect: sourceRect)
            }
        } else {
            // Initial routes mode - go to route detail directly
            let busData = busDisplayData[indexPath.row]
            showRouteDetail(routeNumber: busData.route.route,
                          company: busData.route.company,
                          direction: busData.route.direction)
        }
    }
    
    private func showDirectionSelection(for routeResult: RouteSearchResult, sourceRect: CGRect) {
        let actionSheet = UIAlertController(title: "\(routeResult.company.rawValue) \(routeResult.routeNumber)", 
                                          message: "請選擇路線方向", 
                                          preferredStyle: .actionSheet)
        
        for direction in routeResult.directions {
            let action = UIAlertAction(title: direction.displayText, style: .default) { _ in
                self.showRouteDetail(routeNumber: routeResult.routeNumber, 
                                   company: routeResult.company, 
                                   direction: direction.direction)
            }
            actionSheet.addAction(action)
        }
        
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // For iPad
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = sourceRect
        }
        
        present(actionSheet, animated: true)
    }
    
    private func showRouteDetail(routeNumber: String, company: BusRoute.Company, direction: String) {
        let routeDetailVC = RouteDetailViewController(
            routeNumber: routeNumber,
            company: company,
            direction: direction
        )
        
        // Custom transition animation
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .moveIn
        transition.subtype = .fromRight
        navigationController?.view.layer.add(transition, forKey: kCATransition)
        
        navigationController?.pushViewController(routeDetailVC, animated: false)
    }
    
    // MARK: - Scroll Detection for Keyboard Handling
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Hide keyboard and unfocus search field when user starts scrolling
        if isKeyboardVisible {
            hideKeyboard()
            searchBar.resignFirstResponder()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Remove auto keyboard trigger when scrolling to top
        // Users can manually tap search bar to activate keyboard
    }
}

// MARK: - Supporting Types
enum SearchType {
    case route
    case stop
}

struct SearchResult {
    let type: SearchType
    let title: String
    let subtitle: String
    let route: BusRoute?
    let routeSearchResult: RouteSearchResult?
    
    init(type: SearchType, title: String, subtitle: String, route: BusRoute?, routeSearchResult: RouteSearchResult? = nil) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.route = route
        self.routeSearchResult = routeSearchResult
    }
}

// MARK: - BusRouteKeyboardDelegate

extension SearchViewController: BusRouteKeyboardDelegate {
    
    func keyboardDidTapNumber(_ number: String) {
        currentSearchText += number
        updateSearchBar()

        // Update smart keyboard button states immediately for better UX
        customKeyboard.updateButtonStates(for: currentSearchText)

        // Debounce search to avoid excessive API calls (same 0.3s as textDidChange)
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.performSearchWithCurrentText()
        }
    }

    func keyboardDidTapLetter(_ letter: String) {
        currentSearchText += letter
        updateSearchBar()

        // Update smart keyboard button states immediately for better UX
        customKeyboard.updateButtonStates(for: currentSearchText)

        // Debounce search to avoid excessive API calls (same 0.3s as textDidChange)
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.performSearchWithCurrentText()
        }
    }
    
    func keyboardDidTapBackspace() {
        // Ensure both states are in sync before processing backspace
        let searchBarText = searchBar.text ?? ""

        if !currentSearchText.isEmpty {
            currentSearchText.removeLast()
            updateSearchBar()

            // Update smart keyboard button states immediately
            if !currentSearchText.isEmpty {
                customKeyboard.updateButtonStates(for: currentSearchText)
            } else {
                customKeyboard.resetAllButtons()
            }

            print("⌫ Backspace: '\(currentSearchText)'")

            // Debounce search (same 0.3s as other inputs)
            searchTimer?.invalidate()
            if !currentSearchText.isEmpty {
                searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                    self?.performSearchWithCurrentText()
                }
            } else {
                // Clear search results immediately when empty
                routeSearchResults = []
                tableView.reloadData()
            }
        } else if !searchBarText.isEmpty {
            // Edge case: currentSearchText is empty but searchBar has text
            // This means states are out of sync - clear searchBar too
            print("⚠️ 狀態不同步 - searchBar有值但currentText為空，強制清空searchBar")
            searchBar.text = ""
            searchBar.setShowsCancelButton(false, animated: true)
            customKeyboard.resetAllButtons()

            // Reload nearby routes since search is cleared
            routeSearchResults = []
            if let location = currentLocation {
                loadRoutesFromNearbyStops(location: location)
            } else {
                loadNearbyRoutesImmediately()
            }
        } else {
            // Both are empty - reset all buttons
            customKeyboard.resetAllButtons()
        }
    }
    
    
    private func updateSearchBar() {
        // Set flag to prevent textDidChange from triggering
        isUpdatingFromKeyboard = true

        searchBar.text = currentSearchText

        // Update cancel button visibility based on text content
        let hasText = !currentSearchText.trimmingCharacters(in: .whitespaces).isEmpty
        searchBar.setShowsCancelButton(hasText, animated: true)

        // Reset flag after a short delay to allow textDidChange to complete
        DispatchQueue.main.async {
            self.isUpdatingFromKeyboard = false
        }
    }
    
    private func syncSearchStates() {
        let searchBarText = searchBar.text ?? ""
        let searchBarIsEmpty = searchBarText.trimmingCharacters(in: .whitespaces).isEmpty
        let currentTextIsEmpty = currentSearchText.trimmingCharacters(in: .whitespaces).isEmpty

        // Debug logging
        print("🔄 同步搜尋狀態 - searchBar: '\(searchBarText)', currentText: '\(currentSearchText)'")

        if searchBarIsEmpty && currentTextIsEmpty {
            // Both empty - ensure we show nearby routes
            print("✅ 兩者都為空，載入附近路線")
            routeSearchResults = []

            // Reset keyboard to show all buttons
            customKeyboard.resetAllButtons()

            // Only load nearby routes if we don't have any display data
            if busDisplayData.isEmpty {
                if let location = currentLocation {
                    loadRoutesFromNearbyStops(location: location)
                } else {
                    loadNearbyRoutesImmediately()
                }
            }

            searchBar.setShowsCancelButton(false, animated: false)
        } else if searchBarIsEmpty && !currentTextIsEmpty {
            // searchBar empty but currentText has value - clear currentText to match
            print("⚠️ searchBar空但currentText有值，清空currentText")
            currentSearchText = ""
            routeSearchResults = []

            // Reset keyboard to show all buttons
            customKeyboard.resetAllButtons()

            // Reload nearby routes only if needed
            if busDisplayData.isEmpty {
                if let location = currentLocation {
                    loadRoutesFromNearbyStops(location: location)
                } else {
                    loadNearbyRoutesImmediately()
                }
            }

            searchBar.setShowsCancelButton(false, animated: false)
        } else if !searchBarIsEmpty && currentTextIsEmpty {
            // currentText empty but searchBar has value - sync currentText to searchBar
            print("⚠️ currentText空但searchBar有值，同步currentText")
            currentSearchText = searchBarText
            performSearch(for: currentSearchText)

            // Update keyboard button states based on current input
            customKeyboard.updateButtonStates(for: currentSearchText)
        } else if searchBarText != currentSearchText {
            // Both have values but they're different - use searchBar as source of truth
            print("⚠️ 兩者都有值但不一致，以searchBar為準")
            currentSearchText = searchBarText
            performSearch(for: currentSearchText)

            // Update keyboard button states based on current input
            customKeyboard.updateButtonStates(for: currentSearchText)
        }

        // Ensure cancel button state is correct
        let hasText = !currentSearchText.trimmingCharacters(in: .whitespaces).isEmpty
        searchBar.setShowsCancelButton(hasText, animated: false)
    }
    
    private func performSearchWithCurrentText() {
        performSearch(for: currentSearchText)
    }

    private func toggleFavorite(for busRoute: BusRoute) {
        let isFavorite = favoritesManager.isFavorite(busRoute)

        if isFavorite {
            favoritesManager.removeFavorite(busRoute)
        } else {
            favoritesManager.addFavorite(busRoute)
        }

        // Reload the table to update favorite state
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension SearchViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Cancel timeout timer
        locationTimer?.invalidate()
        locationTimer = nil
        
        currentLocation = location
        locationManager.stopUpdatingLocation()
        
        // Save location for future fast loading
        saveCachedLocation(location)
        
        print("✅ 位置獲取成功: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Only load routes if we haven't loaded them yet (avoid duplicate loading)
        if busDisplayData.isEmpty {
            loadRoutesFromNearbyStops(location: location)
        } else {
            print("📱 路線已載入，更新為真實位置的路線")
            loadRoutesFromNearbyStops(location: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Cancel timeout timer
        locationTimer?.invalidate()
        locationTimer = nil
        
        print("❌ 位置獲取失敗: \(error.localizedDescription)")
        // Keep showing default routes, don't reload
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ 獲得位置權限，開始請求位置")
            manager.requestLocation()
            startLocationTimeout() // Add timeout for this request too
        case .denied, .restricted:
            print("⚠️ 位置權限被拒絕，保持顯示默認路線")
            // Don't reload default routes, they're already showing
        case .notDetermined:
            print("📍 位置權限待定")
            break
        @unknown default:
            print("⚠️ 未知位置權限狀態")
        }
    }
}

// MARK: - Array Extension for Batch Processing
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}