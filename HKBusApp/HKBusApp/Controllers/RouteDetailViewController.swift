import UIKit
import CoreLocation

class RouteDetailViewController: UIViewController {
    
    // MARK: - Properties
    private let routeNumber: String
    private let company: BusRoute.Company
    private let direction: String
    private let targetStopId: String? // 目標站點 ID（從收藏頁面進入時使用）

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    private var routeDetail: BusRouteDetail?
    private var isLoading = false
    
    // ETA display state
    private var expandedStopIndex: Int? = nil
    private var hasAutoLoadedNearestStop = false // Track if we've already auto-loaded once
    private var etaRefreshTimer: Timer? // Timer for auto-refresh of expanded ETA
    
    // Location management
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var locationTimer: Timer?

    // MARK: - Floating Refresh Button
    private let floatingRefreshButton = UIButton(type: .system)
    private var floatingButtonContainer: UIVisualEffectView!
    private let floatingButtonLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private var lastManualRefreshTime: Date?
    private let refreshCooldown: TimeInterval = 5.0
    private var floatingButtonWidthConstraint: NSLayoutConstraint?
    private var isFloatingButtonAnimating = false

    // MARK: - UI Components
    private let headerButton = UIButton(type: .system)
    private let directionLabel = UILabel()
    private let durationLabel = UILabel()
    private let directionIcon = UIImageView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Initialization
    init(routeNumber: String, company: BusRoute.Company, direction: String, targetStopId: String? = nil) {
        self.routeNumber = routeNumber
        self.company = company
        self.direction = direction
        self.targetStopId = targetStopId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupLocationManager()
        setupFloatingRefreshButton()
        layoutFloatingRefreshButton()
        loadRouteDetail()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Try auto-expand immediately if both route and location are ready
        if routeDetail != nil && currentLocation != nil && !hasAutoLoadedNearestStop {
            print("📍 ViewDidAppear: Attempting immediate auto-expand")
            // Small delay to ensure table view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.tryAutoExpandNearestStop()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Show navigation bar when entering this view (important for coming from "My" page)
        navigationController?.setNavigationBarHidden(false, animated: animated)

        // Add subtle fade-in animation
        view.alpha = 0.0
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseInOut) {
            self.view.alpha = 1.0
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop ETA refresh timer when leaving the view
        stopETARefreshTimer()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = routeNumber
        
        // Navigation bar setup - support both light and dark mode with larger title font
        navigationController?.navigationBar.tintColor = UIColor.label
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        navigationController?.navigationBar.barStyle = .default
        
        // Add company button to navigation bar
        setupCompanyButton()
        setupHeaderButton()
        
        setupHeaderView()
        setupTableViewLayout()
    }
    
    private func setupCompanyButton() {
        // Create a custom button for the company
        let companyButton = UIButton(type: .system)
        companyButton.setTitle(company.rawValue, for: .normal)
        companyButton.setTitleColor(.white, for: .normal)
        companyButton.backgroundColor = companyColor(for: company)
        companyButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        companyButton.layer.cornerRadius = 4
        
        // Use modern button configuration for iOS 15+
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = company.rawValue
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            companyButton.configuration = config
        } else {
            companyButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        }
        
        // Add company button to navigation bar
        let companyBarButton = UIBarButtonItem(customView: companyButton)
        navigationItem.rightBarButtonItem = companyBarButton
    }
    
    private func setupHeaderButton() {
        // Setup entire header as clickable button
        headerButton.backgroundColor = UIColor.secondarySystemBackground
        headerButton.layer.cornerRadius = 12
        headerButton.addTarget(self, action: #selector(directionButtonTapped), for: .touchUpInside)
        headerButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup direction icon
        directionIcon.image = UIImage(systemName: "arrow.up.arrow.down")
        directionIcon.tintColor = UIColor.label
        directionIcon.contentMode = .scaleAspectFit
        directionIcon.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupHeaderView() {
        // Direction label
        directionLabel.text = "載入中..."
        directionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        directionLabel.textColor = UIColor.label
        directionLabel.numberOfLines = 0
        directionLabel.isUserInteractionEnabled = false
        directionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Duration label
        durationLabel.text = ""
        durationLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = UIColor.secondaryLabel
        durationLabel.isUserInteractionEnabled = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerButton.addSubview(directionLabel)
        headerButton.addSubview(durationLabel)
        headerButton.addSubview(directionIcon)
        
        view.addSubview(headerButton)
        
        NSLayoutConstraint.activate([
            headerButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            directionLabel.centerYAnchor.constraint(equalTo: headerButton.centerYAnchor),
            directionLabel.leadingAnchor.constraint(equalTo: headerButton.leadingAnchor, constant: 20),
            directionLabel.trailingAnchor.constraint(lessThanOrEqualTo: directionIcon.leadingAnchor, constant: -20),
            
            directionIcon.centerYAnchor.constraint(equalTo: headerButton.centerYAnchor),
            directionIcon.trailingAnchor.constraint(equalTo: headerButton.trailingAnchor, constant: -20),
            directionIcon.widthAnchor.constraint(equalToConstant: 24),
            directionIcon.heightAnchor.constraint(equalToConstant: 24),
            
            durationLabel.centerYAnchor.constraint(equalTo: headerButton.centerYAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: headerButton.leadingAnchor, constant: 20),
            durationLabel.trailingAnchor.constraint(lessThanOrEqualTo: directionIcon.leadingAnchor, constant: -20)
        ])
    }
    
    private func setupTableViewLayout() {
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerButton.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Use lower accuracy for faster response
        
        print("📍 Setting up location manager, current status: \(locationManager.authorizationStatus.rawValue)")
        
        // Request authorization and start getting location
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location authorized, requesting location")
            if CLLocationManager.locationServicesEnabled() {
                locationManager.requestLocation()
                
                // Set up a backup timer with shorter timeout for faster response
                locationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                    self?.handleLocationTimeout()
                }
            }
        case .notDetermined:
            print("📍 Location not determined, requesting authorization")
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("📍 Location access denied or restricted")
        @unknown default:
            print("📍 Unknown location authorization status")
            break
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RouteStopTableViewCell.self, forCellReuseIdentifier: RouteStopTableViewCell.identifier)

        // Add bottom padding for floating button
        let floatingButtonPadding: CGFloat = 80
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: floatingButtonPadding, right: 0)
        tableView.verticalScrollIndicatorInsets = tableView.contentInset
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

        // Initially visible (always show in route detail)
        shadowView.isHidden = false
        shadowView.alpha = 0.95
    }

    private func layoutFloatingRefreshButton() {
        guard let shadowView = view.viewWithTag(998),
              let container = view.viewWithTag(999) as? UIVisualEffectView else {
            return
        }

        shadowView.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false

        // Use safeAreaLayoutGuide because this page has navigation bar
        let widthConstraint = shadowView.widthAnchor.constraint(equalToConstant: 160)
        floatingButtonWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            shadowView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadowView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
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

        isFloatingButtonAnimating = true

        // Animate button to circle with loading
        animateButtonToCircle {
            // Trigger refresh by reloading the route detail
            self.loadRouteDetail()

            // If there's an expanded stop, refresh its ETA too
            if let expandedIndex = self.expandedStopIndex {
                self.refreshExpandedStopETA()
            }
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

    // MARK: - Data Loading
    private func loadRouteDetail() {
        guard !isLoading else { return }
        
        isLoading = true
        showLoadingState()
        
        apiService.fetchRouteDetail(
            routeNumber: routeNumber, 
            company: company, 
            direction: direction,
            stopNamesUpdateCallback: { [weak self] updatedDetail in
                DispatchQueue.main.async {
                    self?.routeDetail = updatedDetail
                    self?.tableView.reloadData()
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.hideLoadingState()
                
                switch result {
                case .success(let detail):
                    self?.routeDetail = detail
                    self?.updateUI(with: detail)
                    self?.tableView.reloadData()
                case .failure(let error):
                    self?.showError(error)
                }
            }
        }
    }
    
    private func updateUI(with detail: BusRouteDetail) {
        directionLabel.text = detail.displayDirection
        
        // Only show operating hours if it's real data from API, not dummy data
        var hasRealInfo = false
        
        if let hours = detail.operatingHours, !hours.isEmpty && hours != "N/A" {
            durationLabel.text = hours
            hasRealInfo = true
        }
        
        // Hide duration label if no real info available
        if !hasRealInfo {
            durationLabel.text = ""
            durationLabel.isHidden = true
        } else {
            durationLabel.isHidden = false
        }
        
        // Update direction button state based on available directions
        updateDirectionButtonState()
        
        // Check for nearest stop and auto-load ETA
        print("📍 Route detail loaded, trying auto-expand. Location: \(currentLocation?.description ?? "nil"), hasAutoLoaded: \(hasAutoLoadedNearestStop)")
        tryAutoExpandNearestStop()
    }
    
    private func updateDirectionButtonState() {
        fetchAvailableDirections { [weak self] directions in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if directions.count <= 1 {
                    // Hide swap icon for single direction routes or routes with no direction data
                    self.directionIcon.isHidden = true
                    self.headerButton.isUserInteractionEnabled = false
                    
                    // Check if it's a circular route (origin == destination)
                    if let routeDetail = self.routeDetail,
                       let firstStop = routeDetail.stops.first,
                       let lastStop = routeDetail.stops.last,
                       firstStop.displayName == lastStop.displayName {
                        // Keep icon hidden for circular routes, just add text
                        // Add "循環線" text to direction label
                        let currentText = self.directionLabel.text ?? ""
                        if !currentText.contains("循環線") {
                            self.directionLabel.text = currentText + " (循環線)"
                        }
                    }
                } else {
                    // Show swap icon for multi-direction routes
                    self.directionIcon.isHidden = false
                    self.directionIcon.image = UIImage(systemName: "arrow.up.arrow.down")
                    self.directionIcon.tintColor = UIColor.label
                    self.headerButton.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    private func showLoadingState() {
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
    }
    
    private func hideLoadingState() {
        loadingIndicator.stopAnimating()
        loadingIndicator.removeFromSuperview()
    }
    
    private func showError(_ error: Error) {
        directionLabel.text = "載入失敗: \(error.localizedDescription)"
    }
    
    // MARK: - Location Timeout Handling
    private func handleLocationTimeout() {
        print("📍 Location request timed out, attempting fallback")
        locationTimer?.invalidate()
        locationTimer = nil
        
        // Try one more location request
        if CLLocationManager.locationServicesEnabled() && 
           (locationManager.authorizationStatus == .authorizedWhenInUse || 
            locationManager.authorizationStatus == .authorizedAlways) {
            print("📍 Making fallback location request")
            locationManager.requestLocation()
        }
    }
    
    // MARK: - Auto-Expand Coordination
    private func tryAutoExpandNearestStop() {
        // Only try if we have route detail
        guard let detail = routeDetail else {
            print("📍 No route detail available for auto-expand")
            return
        }

        // 如果有指定目標站點 ID，優先展開該站點
        if let targetStopId = targetStopId, !hasAutoLoadedNearestStop {
            expandTargetStop(targetStopId: targetStopId, in: detail)
            return
        }

        // 原有邏輯：如果沒有指定站點，則使用位置尋找最近站點
        if currentLocation != nil {
            checkAndLoadNearestStopETA(for: detail)
        } else {
            // If no location yet, request it again
            print("📍 No location available, requesting location for auto-expand")
            if CLLocationManager.locationServicesEnabled() &&
               (locationManager.authorizationStatus == .authorizedWhenInUse ||
                locationManager.authorizationStatus == .authorizedAlways) {
                locationManager.requestLocation()
            }
        }
    }
    
    // MARK: - Target Stop Auto-Loading
    private func expandTargetStop(targetStopId: String, in detail: BusRouteDetail) {
        // Only auto-load once
        guard !hasAutoLoadedNearestStop else {
            print("📍 Already auto-loaded a stop, skipping")
            return
        }

        print("📍 Looking for target stop: \(targetStopId)")

        // Find the stop index by stopId
        guard let targetIndex = detail.stops.firstIndex(where: { $0.stopId == targetStopId }) else {
            print("⚠️ Target stop \(targetStopId) not found in route, falling back to nearest stop")
            // Fallback to nearest stop if target not found
            if currentLocation != nil {
                checkAndLoadNearestStopETA(for: detail)
            }
            return
        }

        let stop = detail.stops[targetIndex]
        print("✅ Found target stop: \(stop.displayName) at index \(targetIndex)")

        // Mark that we've auto-loaded
        hasAutoLoadedNearestStop = true

        // Auto-load ETA for the target stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📍 Auto-loading ETA for target stop at index \(targetIndex)")
            self.expandedStopIndex = targetIndex

            // Reload data and animate height changes
            self.tableView.beginUpdates()
            self.tableView.reloadData()
            self.tableView.endUpdates()

            // Scroll to that stop
            let indexPath = IndexPath(row: targetIndex, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)

            // Load ETA
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let cell = self.tableView.cellForRow(at: indexPath) as? RouteStopTableViewCell {
                    print("📍 Triggering ETA load for target stop")
                    cell.loadAndShowETA(forceRefresh: true)
                    self.startETARefreshTimer()
                } else {
                    print("📍 Cell not found for ETA loading")
                }
            }
        }
    }

    // MARK: - Nearest Stop Auto-Loading
    private func checkAndLoadNearestStopETA(for detail: BusRouteDetail) {
        guard let currentLocation = currentLocation else {
            print("📍 No current location available for nearest stop check")
            return
        }
        
        // Only auto-load once per route detail view
        guard !hasAutoLoadedNearestStop else {
            print("📍 Already auto-loaded nearest stop, skipping")
            return
        }
        
        print("📍 Checking nearest stop from \(detail.stops.count) stops")
        
        var nearestStop: BusStop?
        var nearestDistance: Double = Double.infinity
        var nearestIndex: Int = 0
        
        for (index, stop) in detail.stops.enumerated() {
            // Skip stops without valid coordinates
            guard let latitude = stop.latitude, 
                  let longitude = stop.longitude,
                  latitude.isFinite && longitude.isFinite,
                  latitude >= -90 && latitude <= 90,
                  longitude >= -180 && longitude <= 180 else {
                print("📍 Skipping stop \(stop.displayName) - invalid coordinates: lat=\(stop.latitude?.description ?? "nil"), lng=\(stop.longitude?.description ?? "nil")")
                continue
            }
            
            let stopLocation = CLLocation(latitude: latitude, longitude: longitude)
            let distance = currentLocation.distance(from: stopLocation)
            
            // Validate distance calculation
            guard distance.isFinite && distance >= 0 else {
                print("📍 Skipping stop \(stop.displayName) - invalid distance calculation: \(distance)")
                continue
            }
            
            if distance < nearestDistance {
                nearestDistance = distance
                nearestStop = stop
                nearestIndex = index
            }
        }
        
        // Check if nearest stop is within 1000m
        if let stop = nearestStop, nearestDistance.isFinite && nearestDistance <= 1000 {
            let distanceInt = Int(nearestDistance.rounded())
            print("📍 Found nearest stop: \(stop.displayName) at \(distanceInt)m")
            
            // Mark that we've auto-loaded
            hasAutoLoadedNearestStop = true
            
            // Auto-load ETA for the nearest stop in-cell with minimal delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("📍 Auto-loading ETA for nearest stop at index \(nearestIndex)")
                self.expandedStopIndex = nearestIndex
                
                // Reload data and animate height changes
                self.tableView.beginUpdates()
                self.tableView.reloadData()
                self.tableView.endUpdates()
                
                // Scroll to that stop immediately after table update
                let indexPath = IndexPath(row: nearestIndex, section: 0)
                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                
                // Load ETA immediately after scroll starts
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let cell = self.tableView.cellForRow(at: indexPath) as? RouteStopTableViewCell {
                        print("📍 Triggering ETA load for cell")
                        cell.loadAndShowETA(forceRefresh: true) // Auto-expand bypasses cooldown
                        // Start auto-refresh timer for auto-expanded stop
                        self.startETARefreshTimer()
                    } else {
                        print("📍 Cell not found for ETA loading")
                    }
                }
            }
        } else {
            if nearestDistance.isFinite {
                let distanceInt = Int(nearestDistance.rounded())
                print("📍 Nearest stop is \(distanceInt)m away (beyond 1000m limit)")
            } else {
                print("📍 No valid stops found with finite distance calculations")
            }
        }
    }
    
    
    // MARK: - Favorites Management
    private func toggleFavorite(for stop: BusStop, routeNumber: String, company: BusRoute.Company, direction: String) {
        let busRoute = BusRoute(
            stopId: stop.stopId,
            route: routeNumber,
            companyId: company.rawValue,
            direction: direction,
            subTitle: stop.displayName
        )

        let isFavorite = favoritesManager.isFavorite(busRoute)

        if isFavorite {
            favoritesManager.removeFavorite(busRoute)
        } else {
            favoritesManager.addFavorite(busRoute, subTitle: "我的")
        }

        // Reload the cell to update favorite state
        if let routeDetail = routeDetail,
           let stopIndex = routeDetail.stops.firstIndex(where: { $0.stopId == stop.stopId }) {
            let indexPath = IndexPath(row: stopIndex, section: 0)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    // MARK: - Direction Switching
    @objc private func directionButtonTapped() {
        // First, fetch available directions to determine if button should be interactive
        fetchAvailableDirections { [weak self] directions in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if directions.isEmpty {
                    print("⚠️ 無法獲取路線方向資訊")
                    return
                }
                
                // Check if this is a single direction route
                if directions.count == 1 {
                    // Do nothing for single direction routes
                    return
                }
                
                // If only 2 directions, automatically switch to the other one
                if directions.count == 2 {
                    if let otherDirection = directions.first(where: { $0.direction != self.direction }) {
                        self.switchToDirection(otherDirection.direction)
                        return
                    }
                }
                
                // If more than 2 directions, show selection alert
                self.showDirectionSelectionAlert(directions: directions)
            }
        }
    }
    
    private func showDirectionSelectionAlert(directions: [DirectionInfo]) {
        let alert = UIAlertController(title: "選擇方向", message: "請選擇要查看的路線方向", preferredStyle: .actionSheet)
        
        // Add direction options
        for direction in directions {
            let action = UIAlertAction(title: direction.displayText, style: .default) { _ in
                self.switchToDirection(direction.direction)
            }
            
            // Mark current direction
            if direction.direction == self.direction {
                action.setValue(UIImage(systemName: "checkmark"), forKey: "image")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.headerButton
            popover.sourceRect = self.headerButton.bounds
            popover.permittedArrowDirections = [.up]
        }
        
        self.present(alert, animated: true)
    }
    
    private func fetchAvailableDirections(completion: @escaping ([DirectionInfo]) -> Void) {
        apiService.searchRoutes(routeNumber: routeNumber) { result in
            switch result {
            case .success(let searchResults):
                // Find matching route
                if let matchingRoute = searchResults.first(where: { 
                    $0.routeNumber == self.routeNumber && $0.company == self.company 
                }) {
                    completion(matchingRoute.directions)
                } else {
                    completion([])
                }
            case .failure(_):
                completion([])
            }
        }
    }
    
    private func switchToDirection(_ newDirection: String) {
        // Fade out current content
        UIView.animate(withDuration: 0.2, animations: {
            self.view.alpha = 0.5
        }) { _ in
            // Create new RouteDetailViewController with different direction
            let newRouteDetailVC = RouteDetailViewController(
                routeNumber: self.routeNumber,
                company: self.company,
                direction: newDirection
            )
            
            // Set initial alpha for fade in effect
            newRouteDetailVC.view.alpha = 0.0
            
            // Replace current view controller without animation
            if let navigationController = self.navigationController {
                var viewControllers = navigationController.viewControllers
                viewControllers[viewControllers.count - 1] = newRouteDetailVC
                navigationController.setViewControllers(viewControllers, animated: false)
                
                // Fade in new content
                UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseInOut) {
                    newRouteDetailVC.view.alpha = 1.0
                }
            }
        }
    }
    
    // MARK: - ETA Auto-Refresh
    private func startETARefreshTimer() {
        stopETARefreshTimer() // Clear any existing timer

        etaRefreshTimer = Timer.scheduledTimer(withTimeInterval: 50.0, repeats: true) { [weak self] _ in
            self?.refreshExpandedStopETA()
        }
    }
    
    private func stopETARefreshTimer() {
        etaRefreshTimer?.invalidate()
        etaRefreshTimer = nil
    }
    
    private func refreshExpandedStopETA() {
        guard let expandedIndex = expandedStopIndex,
              let indexPath = IndexPath(row: expandedIndex, section: 0) as IndexPath?,
              let cell = tableView.cellForRow(at: indexPath) as? RouteStopTableViewCell else {
            return
        }
        
        print("🔄 Auto-refreshing ETA for expanded stop at index \(expandedIndex)")
        cell.loadAndShowETA(forceRefresh: true) // Auto-refresh bypasses cooldown
    }
    
    // MARK: - Helper Methods
    private func companyColor(for company: BusRoute.Company) -> UIColor {
        switch company {
        case .CTB, .NWFB:
            return UIColor.systemYellow
        case .KMB:
            return UIColor.systemRed
        }
    }
}

// MARK: - UITableViewDataSource
extension RouteDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return routeDetail?.stops.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: RouteStopTableViewCell.identifier, for: indexPath) as? RouteStopTableViewCell,
              let stops = routeDetail?.stops,
              let routeDetail = routeDetail else {
            return UITableViewCell()
        }
        
        let stop = stops[indexPath.row]
        let isFirst = indexPath.row == 0
        let isLast = indexPath.row == stops.count - 1
        
        cell.configure(with: stop, isFirst: isFirst, isLast: isLast)
        cell.setRouteInfo(routeNumber: routeDetail.routeNumber, company: routeDetail.company, direction: routeDetail.direction)
        
        // Set favorite state 
        let busRoute = BusRoute(
            stopId: stop.stopId,
            route: routeDetail.routeNumber,
            companyId: routeDetail.company.rawValue,
            direction: routeDetail.direction,
            subTitle: stop.displayName
        )
        let isFavorite = favoritesManager.isFavorite(busRoute)
        cell.setFavoriteState(isFavorite)
        
        // Set favorite toggle callback
        cell.onFavoriteToggle = { [weak self] in
            self?.toggleFavorite(for: stop, routeNumber: routeDetail.routeNumber, company: routeDetail.company, direction: routeDetail.direction)
        }
        
        // Check if this stop should show ETA
        if expandedStopIndex == indexPath.row {
            cell.loadAndShowETA()
        } else {
            cell.hideETA()
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension RouteDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Expand height when ETA is showing
        if expandedStopIndex == indexPath.row {
            return 100
        } else {
            return 70
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let previousExpandedIndex = expandedStopIndex
        
        // Handle tap behavior for expanded/collapsed stops
        if expandedStopIndex == indexPath.row {
            // If already expanded, refresh ETA data instead of collapsing
            if let cell = tableView.cellForRow(at: indexPath) as? RouteStopTableViewCell {
                cell.loadAndShowETA()
                // Restart the refresh timer for continued auto-refresh
                startETARefreshTimer()
            }
            return // Don't collapse, just refresh
        } else {
            // Stop previous timer if any
            stopETARefreshTimer()
            // Show ETA for this stop, hide others
            expandedStopIndex = indexPath.row
            // Start auto-refresh timer for new expanded stop
            startETARefreshTimer()
        }
        
        // Collect all cells that need to be reloaded
        var indexPathsToReload: [IndexPath] = []
        
        // Always reload the tapped cell
        indexPathsToReload.append(indexPath)
        
        // If there was a previously expanded stop and it's different, reload that too
        if let previousIndex = previousExpandedIndex, previousIndex != indexPath.row {
            indexPathsToReload.append(IndexPath(row: previousIndex, section: 0))
        }
        
        // Use begin/end updates for smooth height animation
        tableView.beginUpdates()
        tableView.reloadRows(at: indexPathsToReload, with: .fade)
        tableView.endUpdates()
    }
    
    private func showStopETA(stop: BusStop, routeDetail: BusRouteDetail) {
        let stopETAVC = StopETAViewController(
            stop: stop,
            routeNumber: routeDetail.routeNumber,
            company: routeDetail.company,
            direction: routeDetail.direction
        )
        
        // Custom push transition
        navigationController?.pushViewController(stopETAVC, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate
extension RouteDetailViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Cancel the timeout timer since we got location
        locationTimer?.invalidate()
        locationTimer = nil
        
        // If we already have route detail, try auto-expand
        if routeDetail != nil {
            tryAutoExpandNearestStop()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Authorization status changed to: \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location authorized, requesting location")
            if CLLocationManager.locationServicesEnabled() {
                locationManager.requestLocation()
                
                // Set up a backup timer with shorter timeout for faster response
                locationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                    self?.handleLocationTimeout()
                }
            }
        case .denied, .restricted:
            print("📍 Location access denied")
        case .notDetermined:
            print("📍 Location status not determined, requesting authorization")
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}
