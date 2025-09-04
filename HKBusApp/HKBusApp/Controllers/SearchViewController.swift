import UIKit
import QuartzCore
import CoreLocation

class SearchViewController: UIViewController {
    
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearchBar()
        setupTableView()
        setupCustomKeyboard()
        setupTapGesture()
        setupLocationManager()
        requestLocationAndLoadRoutes()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Don't auto focus search bar - user will use custom keyboard
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black
        
        // Search bar
        searchBar.placeholder = "搜尋路線或站點"
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor.white
        searchBar.barTintColor = UIColor.black
        searchBar.showsCancelButton = true
        searchBar.autocapitalizationType = .allCharacters
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Customize search bar appearance for both light and dark mode
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = UIColor.label
            textField.backgroundColor = UIColor.secondarySystemBackground
        }
        
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
            customKeyboard.heightAnchor.constraint(equalToConstant: 220)
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
            bottomInset = 220 + 16 // keyboard height + margin for content visibility
        } else {
            // When keyboard is hidden, no bottom padding needed as table is full height
            bottomInset = 0
        }
        
        UIView.animate(withDuration: 0.25) {
            self.tableView.contentInset.bottom = bottomInset
            self.tableView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }
    
    private func requestLocationAndLoadRoutes() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            // Load default routes if location access denied
            loadDefaultRoutes()
        @unknown default:
            loadDefaultRoutes()
        }
    }
    
    private func loadRoutesFromNearbyStops(location: CLLocation) {
        print("🔍 開始載入附近站點路線，位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Get nearby stops within 2km
        let nearbyStops = localDataManager.getNearbyStops(location: location, radiusKm: 2.0, limit: 30)
        print("📍 找到附近站點: \(nearbyStops.count) 個")
        
        if nearbyStops.isEmpty {
            print("⚠️ 沒有找到附近站點，載入默認路線")
            loadDefaultRoutes()
            return
        }
        
        // Create structure to track route with distance and stop name
        struct RouteWithDistance {
            let stopRoute: StopRoute
            let distance: Double
            let stopName: String
        }
        
        // Collect all unique routes from nearby stops with distance info
        var routesSet = Set<String>() // Use Set to avoid duplicates based on route key
        var routesWithDistance: [RouteWithDistance] = []
        
        for stopResult in nearbyStops {
            // Calculate distance to this stop
            let stopLocation = CLLocation(latitude: stopResult.latitude!, longitude: stopResult.longitude!)
            let distance = location.distance(from: stopLocation)
            
            print("🚏 站點: \(stopResult.displayName) (距離: \(Int(distance))m), 路線數: \(stopResult.routes.count)")
            
            for stopRoute in stopResult.routes {
                // Create unique key: company + route number + destination (to distinguish directions)
                let routeKey = "\(stopRoute.company.rawValue)_\(stopRoute.routeNumber)_\(stopRoute.destination)"
                if !routesSet.contains(routeKey) {
                    routesSet.insert(routeKey)
                    let routeWithDistance = RouteWithDistance(
                        stopRoute: stopRoute,
                        distance: distance,
                        stopName: stopResult.displayName
                    )
                    routesWithDistance.append(routeWithDistance)
                    print("✅ 添加路線: \(stopRoute.company.rawValue) \(stopRoute.routeNumber) → \(stopRoute.destination) (距離: \(Int(distance))m)")
                }
            }
        }
        
        print("📊 總共收集到路線: \(routesWithDistance.count) 條")
        
        if routesWithDistance.isEmpty {
            print("⚠️ 沒有找到有效路線，載入默認路線")
            loadDefaultRoutes()
            return
        }
        
        // Sort by distance (closest stops first), then by route number
        let sortedRoutes = routesWithDistance.sorted { route1, route2 in
            if abs(route1.distance - route2.distance) > 50 { // If distance difference > 50m
                return route1.distance < route2.distance
            }
            // If distances are similar, sort by route number
            if route1.stopRoute.routeNumber != route2.stopRoute.routeNumber {
                return route1.stopRoute.routeNumber.localizedStandardCompare(route2.stopRoute.routeNumber) == .orderedAscending
            }
            return route1.stopRoute.company.rawValue < route2.stopRoute.company.rawValue
        }
        
        let limitedRoutes = Array(sortedRoutes.prefix(50))
        
        busDisplayData = limitedRoutes.map { routeWithDistance in
            // Convert RouteWithDistance to BusDisplayData
            let stopRoute = routeWithDistance.stopRoute
            let busRoute = BusRoute(
                stopId: "", // Not needed for route display
                route: stopRoute.routeNumber,
                companyId: stopRoute.company.rawValue,
                direction: stopRoute.direction,
                subTitle: stopRoute.destination
            )
            
            return BusDisplayData(
                route: busRoute,
                stopName: routeWithDistance.stopName, // Use JSON stop name
                destination: stopRoute.destination,
                etas: []
            )
        }
        
        print("🚌 成功載入 \(busDisplayData.count) 條附近路線")
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    private func loadDefaultRoutes() {
        // Fallback to general routes if no location
        let routes = localDataManager.getAllRoutes(limit: 50)
        
        busDisplayData = routes.map { routeInfo in
            let busRoute = BusRoute(
                stopId: "",
                route: routeInfo.routeNumber,
                companyId: routeInfo.company,
                direction: routeInfo.direction,
                subTitle: "\(routeInfo.originTC) → \(routeInfo.destTC)"
            )
            
            return BusDisplayData(
                route: busRoute,
                stopName: routeInfo.originTC,
                destination: routeInfo.destTC,
                etas: []
            )
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
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
                loadDefaultRoutes()
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
        // Cancel previous search timer
        searchTimer?.invalidate()
        
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
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
        searchBar.text = ""
        searchBar.resignFirstResponder()
        routeSearchResults = []
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
        // Hide keyboard when user starts scrolling
        if isKeyboardVisible {
            hideKeyboard()
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
    
    func keyboardDidTapSearch() {
        if !currentSearchText.isEmpty {
            performSearchWithCurrentText()
        }
    }
    
    private func updateSearchBar() {
        searchBar.text = currentSearchText
    }
    
    private func performSearchWithCurrentText() {
        performSearch(for: currentSearchText)
    }
}

// MARK: - CLLocationManagerDelegate
extension SearchViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationManager.stopUpdatingLocation()
        
        print("✅ 搜尋頁面獲取到位置: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        loadRoutesFromNearbyStops(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 搜尋頁面位置獲取失敗: \(error.localizedDescription)")
        loadDefaultRoutes()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            print("⚠️ 搜尋頁面位置權限被拒絕，使用默認路線")
            loadDefaultRoutes()
        case .notDetermined:
            break
        @unknown default:
            loadDefaultRoutes()
        }
    }
}