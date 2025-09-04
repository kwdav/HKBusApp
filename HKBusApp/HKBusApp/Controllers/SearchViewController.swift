import UIKit
import QuartzCore
import CoreLocation

class SearchViewController: UIViewController {
    
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let customKeyboard = BusRouteKeyboard()
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
    
    // Structure to track route with distance and stop name
    private struct RouteWithDistance {
        let stopRoute: StopRoute
        let distance: Double
        let stopName: String
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearchBar()
        setupTableView()
        setupCustomKeyboard()
        setupTapGesture()
        setupLocationManager()
        
        // Immediately load nearby routes without waiting for GPS
        loadNearbyRoutesImmediately()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Sync state between searchBar.text and currentSearchText
        syncSearchStates()
        
        // Don't auto focus search bar - user will use custom keyboard
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black
        
        // Search bar
        searchBar.placeholder = "搜尋路線..."
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor.white
        searchBar.barTintColor = UIColor.black
        searchBar.showsCancelButton = false  // Initially hidden, will show when text is entered
        searchBar.autocapitalizationType = .allCharacters
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Customize search bar appearance for both light and dark mode
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = UIColor.label
            textField.backgroundColor = UIColor.secondarySystemBackground
        }
        
        // Customize Cancel button text
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).title = "重設"
        
        // No segmented control - only route search for now
        
        // Table view
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(customKeyboard)
        
        NSLayoutConstraint.activate([
            // Search bar - pin to top without extra spacing
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 44),
            
            // Table view - full height from search bar to bottom
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Custom keyboard - overlaid on top of table view, full width coverage
            customKeyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customKeyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customKeyboard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            customKeyboard.heightAnchor.constraint(equalToConstant: 260)  // Updated from 240 to 260 (20px increase for 4 rows * 5px)
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
        tableView.backgroundColor = UIColor.black
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0 // Reduce top padding for iOS 15+
        tableView.register(SearchResultTableViewCell.self, forCellReuseIdentifier: SearchResultTableViewCell.identifier)
        tableView.register(BusETATableViewCell.self, forCellReuseIdentifier: BusETATableViewCell.identifier)
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
        
        // Adjust table view insets when keyboard is hidden
        updateTableViewInsets()
    }
    
    private func updateTableViewInsets() {
        var bottomInset: CGFloat = 0
        
        if isKeyboardVisible {
            // When keyboard is visible, add keyboard height + margin to bottom inset
            bottomInset = 260 + 16 // keyboard height + margin for content visibility
        } else {
            // When keyboard is hidden, no bottom padding needed as table is full height
            bottomInset = 0
        }
        
        UIView.animate(withDuration: 0.25) {
            self.tableView.contentInset.bottom = bottomInset
            self.tableView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }
    
    
    private func startLocationTimeout() {
        locationTimer?.invalidate()
        locationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            print("⏰ 位置獲取超時，保持顯示默認路線")
            self.locationManager.stopUpdatingLocation()
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
        var routeDistanceMap = [String: (RouteWithDistance, Double)]() // Map route key to closest stop data
        
        for stopResult in nearbyStops {
            let stopLocation = CLLocation(latitude: stopResult.latitude!, longitude: stopResult.longitude!)
            let distance = location.distance(from: stopLocation)
            
            for stopRoute in stopResult.routes {
                // Create unique key: company + route + direction
                let routeKey = "\(stopRoute.company.rawValue)_\(stopRoute.routeNumber)_\(stopRoute.direction)"
                
                let routeWithDistance = RouteWithDistance(
                    stopRoute: stopRoute,
                    distance: distance,
                    stopName: stopResult.displayName
                )
                
                // Keep only the closest stop for each unique route
                if let existingEntry = routeDistanceMap[routeKey] {
                    if distance < existingEntry.1 {
                        routeDistanceMap[routeKey] = (routeWithDistance, distance)
                    }
                } else {
                    routeDistanceMap[routeKey] = (routeWithDistance, distance)
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
            
            return BusDisplayData(
                route: busRoute,
                stopName: routeWithDistance.stopName,
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
                self.loadETABatch(batch: batch, batchIndex: batchIndex)
            }
        }
    }
    
    private func loadETABatch(batch: [RouteWithDistance], batchIndex: Int) {
        print("📦 載入批次 \(batchIndex + 1)，包含 \(batch.count) 條路線")
        
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
                            // Reload only the specific row to avoid full table refresh
                            let indexPath = IndexPath(row: globalIndex, section: 0)
                            if self?.tableView.indexPathsForVisibleRows?.contains(indexPath) == true {
                                self?.tableView.reloadRows(at: [indexPath], with: .none)
                            }
                        }
                    }
                    print("✅ ETA載入成功: \(stopRoute.routeNumber) (\(etas.count) 班次)")
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        // Update loading state even on failure
                        if globalIndex < self?.busDisplayData.count ?? 0 {
                            self?.busDisplayData[globalIndex].isLoadingETAs = false
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
        }
    }
    

    
    private func performSearch(for query: String) {
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
        // Clear all search-related data
        searchBar.text = ""
        currentSearchText = ""
        routeSearchResults = []
        
        // Hide cancel button since text is now empty
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        
        // Reload nearby routes to restore the initial state
        loadNearbyRoutesImmediately()
        
        tableView.reloadData()
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
                title: "\(routeResult.company.rawValue) \(routeResult.routeNumber)",
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
        // Show header only when displaying initial nearby routes (not search results)
        if routeSearchResults.isEmpty && !busDisplayData.isEmpty {
            return 32
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Show "附近路線" header only when displaying initial nearby routes
        if routeSearchResults.isEmpty && !busDisplayData.isEmpty {
            let headerView = UIView()
            headerView.backgroundColor = UIColor.black
            
            let titleLabel = UILabel()
            titleLabel.text = "附近路線"
            titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            titleLabel.textColor = UIColor.white
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            headerView.addSubview(titleLabel)
            
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
                titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -4)
            ])
            
            return headerView
        }
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
        // Show keyboard when scrolled to top AND user is not actively using keyboard
        // Only show keyboard if scroll was intentional (not during keyboard usage)
        if scrollView.contentOffset.y <= 0 && !isKeyboardVisible && !scrollView.isDragging {
            showKeyboard()
        }
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
        performSearchWithCurrentText()
    }
    
    func keyboardDidTapLetter(_ letter: String) {
        currentSearchText += letter
        updateSearchBar()
        performSearchWithCurrentText()
    }
    
    func keyboardDidTapBackspace() {
        if !currentSearchText.isEmpty {
            currentSearchText.removeLast()
            updateSearchBar()
            performSearchWithCurrentText()
        }
    }
    
    
    private func updateSearchBar() {
        searchBar.text = currentSearchText
        
        // Update cancel button visibility based on text content
        let hasText = !currentSearchText.trimmingCharacters(in: .whitespaces).isEmpty
        searchBar.setShowsCancelButton(hasText, animated: true)
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
            if let location = currentLocation {
                loadRoutesFromNearbyStops(location: location)
            } else {
                loadNearbyRoutesImmediately()
            }
            searchBar.setShowsCancelButton(false, animated: false)
        } else if searchBarIsEmpty && !currentTextIsEmpty {
            // searchBar empty but currentText has value - clear currentText to match
            print("⚠️ searchBar空但currentText有值，清空currentText")
            currentSearchText = ""
            routeSearchResults = []
            if let location = currentLocation {
                loadRoutesFromNearbyStops(location: location)
            } else {
                loadNearbyRoutesImmediately()
            }
            searchBar.setShowsCancelButton(false, animated: false)
        } else if !searchBarIsEmpty && currentTextIsEmpty {
            // currentText empty but searchBar has value - sync currentText to searchBar
            print("⚠️ currentText空但searchBar有值，同步currentText")
            currentSearchText = searchBarText
            performSearch(for: currentSearchText)
        } else if searchBarText != currentSearchText {
            // Both have values but they're different - use searchBar as source of truth
            print("⚠️ 兩者都有值但不一致，以searchBar為準")
            currentSearchText = searchBarText
            performSearch(for: currentSearchText)
        }
        
        // Ensure cancel button state is correct
        let hasText = !currentSearchText.trimmingCharacters(in: .whitespaces).isEmpty
        searchBar.setShowsCancelButton(hasText, animated: false)
    }
    
    private func performSearchWithCurrentText() {
        performSearch(for: currentSearchText)
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