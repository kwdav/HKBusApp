import UIKit
import QuartzCore
import CoreLocation


class StopSearchViewController: UIViewController {
    
    // MARK: - Properties
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let searchBarBackgroundView = UIView()
    private let refreshControl = UIRefreshControl()
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

    // MARK: - Performance Caches
    private var distanceCache: [String: String] = [:] // stopId -> formatted distance string
    private var routeDisplayTextCache: [String: String] = [:] // stopId -> "1, 2, 3A..."

    // MARK: - Floating Refresh Button
    private let floatingRefreshButton = UIButton(type: .system)
    private var floatingButtonContainer: UIVisualEffectView!
    private let floatingButtonLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private var lastManualRefreshTime: Date?
    private let refreshCooldown: TimeInterval = 5.0
    private var floatingButtonWidthConstraint: NSLayoutConstraint?
    private var isFloatingButtonAnimating = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Ensure content extends under translucent bars
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        setupUI()
        setupSearchBar()
        setupTableView()
        setupTapGesture()
        setupLocationManager()
        setupFloatingRefreshButton()
        layoutFloatingRefreshButton()
        requestLocationAndLoadNearbyStops()
    }
    
    // Show status bar to display clock and battery
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Sync search bar state and ensure correct display
        syncSearchState()
        
        // No auto-focus - let user manually tap search bar
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Search bar background with clean iOS-style appearance
        searchBarBackgroundView.backgroundColor = UIColor.systemBackground
        searchBarBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        // Search bar
        searchBar.placeholder = "搜尋站點..."
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor.label
        searchBar.backgroundColor = UIColor.systemBackground
        searchBar.barTintColor = UIColor.systemBackground
        searchBar.showsCancelButton = false  // Initially hidden, will show when text is entered
        searchBar.autocapitalizationType = .none
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
        
        // Table view
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.sectionHeaderTopPadding = 0 // Reduce top padding for iOS 15+
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        view.addSubview(searchBarBackgroundView)  // Add background first
        view.addSubview(searchBar)  // Add search bar on top
        
        NSLayoutConstraint.activate([
            // Search bar background - full width at safe area top (below status bar)
            searchBarBackgroundView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBarBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBarBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBarBackgroundView.heightAnchor.constraint(equalToConstant: 44),
            
            // Search bar - positioned at safe area top (below status bar)
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),  // Keep some padding for text
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),  // Keep some padding for text
            searchBar.heightAnchor.constraint(equalToConstant: 44),
            
            // Table view - starts below search bar with 4px spacing
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor) // Extend under tab bar
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
        // Enable automatic content inset for translucent bars
        tableView.contentInsetAdjustmentBehavior = .automatic

        // Add bottom padding for floating button
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 49
        let floatingButtonPadding: CGFloat = 80
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: tabBarHeight + floatingButtonPadding, right: 0)
        tableView.verticalScrollIndicatorInsets = tableView.contentInset

        // Setup refresh control
        refreshControl.tintColor = UIColor.label
        refreshControl.attributedTitle = NSAttributedString(
            string: "更新站點",
            attributes: [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14)]
        )
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    // MARK: - Floating Refresh Button Setup

    private func setupFloatingRefreshButton() {
        // 1. Create shadow container view
        let shadowView = UIView()
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.backgroundColor = .clear
        shadowView.layer.cornerRadius = 24
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowView.layer.shadowOpacity = 0.15
        shadowView.layer.shadowRadius = 8
        shadowView.layer.masksToBounds = false
        shadowView.tag = 998
        view.addSubview(shadowView)

        // 2. Create blur effect container
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        floatingButtonContainer = UIVisualEffectView(effect: blurEffect)
        floatingButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        floatingButtonContainer.layer.cornerRadius = 24
        floatingButtonContainer.clipsToBounds = true
        floatingButtonContainer.tag = 999
        shadowView.addSubview(floatingButtonContainer)

        // 3. Create vibrancy effect for enhanced glass effect
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        floatingButtonContainer.contentView.addSubview(vibrancyView)

        // 4. Configure button with dynamic font
        var config = UIButton.Configuration.plain()
        config.title = "重新整理"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        config.baseForegroundColor = UIColor.label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            let fontSize: CGFloat = FontSizeManager.shared.isLargeFontEnabled ? 18 : 16
            outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            return outgoing
        }
        floatingRefreshButton.configuration = config
        floatingRefreshButton.translatesAutoresizingMaskIntoConstraints = false
        floatingRefreshButton.addTarget(self, action: #selector(floatingRefreshButtonTapped), for: .touchUpInside)

        // 5. Configure loading indicator
        floatingButtonLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        floatingButtonLoadingIndicator.hidesWhenStopped = true
        floatingButtonLoadingIndicator.color = UIColor.label

        // 6. Add button and indicator to vibrancy view
        vibrancyView.contentView.addSubview(floatingRefreshButton)
        vibrancyView.contentView.addSubview(floatingButtonLoadingIndicator)

        // 7. Setup constraints
        NSLayoutConstraint.activate([
            vibrancyView.topAnchor.constraint(equalTo: floatingButtonContainer.contentView.topAnchor),
            vibrancyView.leadingAnchor.constraint(equalTo: floatingButtonContainer.contentView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: floatingButtonContainer.contentView.trailingAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: floatingButtonContainer.contentView.bottomAnchor),

            floatingRefreshButton.topAnchor.constraint(equalTo: vibrancyView.contentView.topAnchor),
            floatingRefreshButton.leadingAnchor.constraint(equalTo: vibrancyView.contentView.leadingAnchor),
            floatingRefreshButton.trailingAnchor.constraint(equalTo: vibrancyView.contentView.trailingAnchor),
            floatingRefreshButton.bottomAnchor.constraint(equalTo: vibrancyView.contentView.bottomAnchor),

            floatingButtonLoadingIndicator.centerXAnchor.constraint(equalTo: vibrancyView.contentView.centerXAnchor),
            floatingButtonLoadingIndicator.centerYAnchor.constraint(equalTo: vibrancyView.contentView.centerYAnchor)
        ])

        // Initially hidden
        shadowView.isHidden = true
        shadowView.alpha = 0.95
    }

    private func layoutFloatingRefreshButton() {
        guard let shadowView = view.viewWithTag(998),
              let container = view.viewWithTag(999) as? UIVisualEffectView else {
            return
        }

        shadowView.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false

        // Calculate bottom position relative to tab bar
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 49
        let widthConstraint = shadowView.widthAnchor.constraint(equalToConstant: 160)
        floatingButtonWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            shadowView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadowView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -(tabBarHeight + 16)
            ),
            widthConstraint,
            shadowView.heightAnchor.constraint(equalToConstant: 48),

            container.topAnchor.constraint(equalTo: shadowView.topAnchor),
            container.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor)
        ])
    }

    // MARK: - Floating Button Actions

    @objc private func floatingRefreshButtonTapped() {
        guard !isFloatingButtonAnimating else {
            print("🔒 按鈕動畫中，無法點擊")
            return
        }

        guard canPerformManualRefresh() else {
            print("⏰ 刷新冷卻中，請稍後再試")
            return
        }

        print("🔄 浮動按鈕點擊 - 觸發刷新")

        // Track manual refresh event
        AnalyticsManager.shared.track(.manualTriggered(
            source: "stop_search_page",
            method: "floating_button"
        ))

        isFloatingButtonAnimating = true

        // Animate button to circle with loading
        animateButtonToCircle {
            // Trigger refresh (reuse existing handleRefresh logic)
            self.handleRefresh()
        }

        // Record refresh time
        lastManualRefreshTime = Date()

        // Reset animation flag after 4 seconds (3s loading + 1s cooldown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.isFloatingButtonAnimating = false
        }
    }

    private func animateButtonToCircle(completion: @escaping () -> Void) {
        guard let widthConstraint = floatingButtonWidthConstraint else { return }

        // 1. Shrink to circle (48px)
        widthConstraint.constant = 48

        // 2. Hide text and icon
        var config = floatingRefreshButton.configuration
        config?.title = ""
        config?.image = nil
        floatingRefreshButton.configuration = config

        // 3. Show loading indicator
        floatingButtonLoadingIndicator.startAnimating()

        // 4. Animate with spring effect
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut],
            animations: {
                self.view.layoutIfNeeded()
            },
            completion: { _ in
                // Execute refresh
                completion()

                // Wait 3 seconds then expand back
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.animateButtonToNormal()
                }
            }
        )
    }

    private func animateButtonToNormal() {
        guard let widthConstraint = floatingButtonWidthConstraint else { return }

        // 1. Stop loading indicator
        floatingButtonLoadingIndicator.stopAnimating()

        // 2. Expand to normal size (160px)
        widthConstraint.constant = 160

        // 3. Restore text and icon
        var config = floatingRefreshButton.configuration
        config?.title = "重新整理"
        config?.image = UIImage(systemName: "arrow.clockwise")
        floatingRefreshButton.configuration = config

        // 4. Animate with spring effect
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut],
            animations: {
                self.view.layoutIfNeeded()
            }
        )
    }

    private func canPerformManualRefresh() -> Bool {
        guard let lastRefresh = lastManualRefreshTime else {
            return true
        }

        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceLastRefresh >= refreshCooldown
    }

    private func showFloatingButton(animated: Bool) {
        guard let shadowView = view.viewWithTag(998) else { return }

        if animated {
            UIView.animate(withDuration: 0.3) {
                shadowView.isHidden = false
                shadowView.alpha = 0.95
            }
        } else {
            shadowView.isHidden = false
            shadowView.alpha = 0.95
        }
    }

    private func hideFloatingButton(animated: Bool) {
        guard let shadowView = view.viewWithTag(998) else { return }

        if animated {
            UIView.animate(withDuration: 0.3) {
                shadowView.alpha = 0
            } completion: { _ in
                shadowView.isHidden = true
            }
        } else {
            shadowView.isHidden = true
            shadowView.alpha = 0
        }
    }

    private func updateFloatingButtonFont() {
        guard var config = floatingRefreshButton.configuration else { return }

        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            let fontSize: CGFloat = FontSizeManager.shared.isLargeFontEnabled ? 18 : 16
            outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            return outgoing
        }

        floatingRefreshButton.configuration = config
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

            // Cache distances and route text for better scrolling performance
            self.cacheDistances(for: stops)
            self.cacheRouteDisplayText(for: stops)

            // Show floating button when displaying nearby stops
            self.showFloatingButton(animated: true)

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
    
    private func syncSearchState() {
        let searchText = searchBar.text ?? ""
        let isEmpty = searchText.trimmingCharacters(in: .whitespaces).isEmpty
        
        print("🔄 同步搜尋狀態 - searchBar: '\(searchText)', isEmpty: \(isEmpty)")
        
        if isEmpty {
            // Search bar is empty - ensure we show nearby stops and hide cancel button
            print("✅ 搜尋欄為空，顯示附近站點")
            isShowingNearby = true
            stopSearchResults = []
            searchBar.setShowsCancelButton(false, animated: false)
            
            // If no nearby stops, try to load them
            if nearbyStops.isEmpty {
                print("⚠️ 沒有附近站點，重新載入")
                requestLocationAndLoadNearbyStops()
            }
            
            tableView.reloadData()
        } else {
            // Search bar has text - ensure cancel button is shown
            searchBar.setShowsCancelButton(true, animated: false)
        }
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

    @objc private func handleRefresh() {
        print("🔄 用戶下拉刷新站點")

        // Track pull refresh event
        AnalyticsManager.shared.track(.pullTriggered(source: "stop_search_page"))

        // Clear search results to show nearby stops
        stopSearchResults = []
        searchBar.text = ""
        searchBar.setShowsCancelButton(false, animated: true)
        isShowingNearby = true

        // Force refresh nearby stops with new location
        currentLocation = nil // Clear cached location

        // Reload nearby stops
        requestLocationAndLoadNearbyStops()

        // End refresh after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshControl.endRefreshing()
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
        
        // Only search if query has meaningful content (at least 1 character for stops)
        guard query.count >= 1 else {
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
        // Pass currentLocation for distance-based sorting (nearest first)
        let searchResults = LocalBusDataManager.shared.searchStops(query: query, location: currentLocation, limit: 50)
        
        DispatchQueue.main.async {
            self.isLoading = false
            print("站點搜尋結果: \(searchResults.count) 個站點")

            // Track station search performed event
            AnalyticsManager.shared.track(.stationSearchPerformed(
                query: query,
                resultCount: searchResults.count
            ))

            self.stopSearchResults = searchResults
            self.isShowingNearby = false

            // Cache distances and route text for better scrolling performance
            self.cacheDistances(for: searchResults)
            self.cacheRouteDisplayText(for: searchResults)

            self.tableView.reloadData()
        }
    }

    // MARK: - Performance Caching Methods

    /// Pre-calculates and caches distance text for all stops to avoid repeated calculations during scrolling
    private func cacheDistances(for stops: [StopSearchResult]) {
        guard let currentLocation = currentLocation else { return }

        distanceCache.removeAll()
        for stop in stops {
            guard let lat = stop.latitude, let lon = stop.longitude else { continue }
            let stopLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = currentLocation.distance(from: stopLocation)

            // Format once and cache
            if distance < 1000 {
                distanceCache[stop.stopId] = "\(Int(distance))米"
            } else {
                distanceCache[stop.stopId] = String(format: "%.1f公里", distance / 1000.0)
            }
        }
        print("📊 已緩存 \(distanceCache.count) 個站點的距離數據")
    }

    /// Pre-formats and caches route display text to avoid repeated string operations during scrolling
    private func cacheRouteDisplayText(for stops: [StopSearchResult]) {
        routeDisplayTextCache.removeAll()

        for stop in stops {
            let routeNumbers = stop.routes.map { $0.routeNumber }.sorted()

            if routeNumbers.isEmpty {
                routeDisplayTextCache[stop.stopId] = "無路線數據"
            } else if routeNumbers.count > 8 {
                let firstRoutes = Array(routeNumbers.prefix(8))
                routeDisplayTextCache[stop.stopId] = "\(firstRoutes.joined(separator: ", ")) 等\(routeNumbers.count)條路線"
            } else {
                routeDisplayTextCache[stop.stopId] = routeNumbers.joined(separator: ", ")
            }
        }
        print("📊 已緩存 \(routeDisplayTextCache.count) 個站點的路線顯示文字")
    }
}

// MARK: - UISearchBarDelegate
extension StopSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Show/hide cancel button based on text content
        let hasText = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
        searchBar.setShowsCancelButton(hasText, animated: true)
        
        // Cancel previous search timer
        searchTimer?.invalidate()
        
        // Debounce search with 0.3 second delay (unified with route search)
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
        // Clear search text and hide cancel button
        searchBar.text = ""
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        
        // Return to showing nearby stops
        isShowingNearby = true
        stopSearchResults = []
        
        // If we don't have nearby stops, reload them
        if nearbyStops.isEmpty {
            requestLocationAndLoadNearbyStops()
        }
        
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
        let cachedRouteText = routeDisplayTextCache[stopResult.stopId]
        cell.configure(with: stopResult, distance: distance, cachedRouteText: cachedRouteText)

        return cell
    }
}

// MARK: - UITableViewDelegate
extension StopSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
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
        
        // Prevent rapid consecutive taps
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastTapTime < tapCooldown {
            print("⚠️ 點擊過快，請稍等...")
            return
        }
        lastTapTime = currentTime
        
        let stopResult = isShowingNearby ? nearbyStops[indexPath.row] : stopSearchResults[indexPath.row]

        // Track station selected event
        let source = isShowingNearby ? "nearby_stops" : "station_search"
        AnalyticsManager.shared.track(.stationSelected(
            stopId: stopResult.stopId,
            stopName: stopResult.displayName,
            source: source
        ))

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
        // Use cache first for better performance (10x improvement during scrolling)
        if let cached = distanceCache[stopResult.stopId] {
            return cached
        }

        // Fallback to calculation if not in cache
        guard let currentLocation = currentLocation,
              let stopLat = stopResult.latitude,
              let stopLon = stopResult.longitude else {
            print("⚠️ 無法計算距離 - 缺少位置或站點座標數據")
            return ""
        }

        let stopLocation = CLLocation(latitude: stopLat, longitude: stopLon)
        let distance = currentLocation.distance(from: stopLocation)

        // Debug: Log the first few distance calculations
        if stopResult.stopId == nearbyStops.first?.stopId {
            print("🔍 距離計算 - 站點 '\(stopResult.nameTC)': 距離 \(Int(distance))米 (coordinates masked for privacy)")
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
        print("📍 用戶位置已獲取 (coordinates masked for privacy)")

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