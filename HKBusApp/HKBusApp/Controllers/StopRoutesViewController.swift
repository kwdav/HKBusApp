import UIKit
import QuartzCore

class StopRoutesViewController: UIViewController {
    
    // MARK: - Properties
    private let stopResult: StopSearchResult
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    
    // Route data with ETA
    private var routesWithETA: [RouteWithETA] = []
    private var isLoading = false
    private var retryCount = 0
    private let maxRetries = 2
    
    // Loading indicator
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let emptyStateLabel = UILabel()
    
    // MARK: - UI Components
    private let headerView = UIView()
    private let stopNameLabel = UILabel()
    private let routeCountLabel = UILabel()
    
    // MARK: - Initialization
    init(stopResult: StopSearchResult) {
        self.stopResult = stopResult
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Slide-in animation from right
        view.transform = CGAffineTransform(translationX: view.bounds.width, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.view.transform = .identity
        }
        
        // Load routes with ETA
        loadRoutesWithETA()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = stopResult.displayName // Use station name as title
        
        // Navigation bar setup
        navigationController?.navigationBar.tintColor = UIColor.label
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        setupHeaderView()
        setupTableViewLayout()
        setupLoadingIndicator()
        setupEmptyStateLabel()
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = UIColor.secondarySystemBackground
        headerView.layer.cornerRadius = 12
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name
        stopNameLabel.text = stopResult.displayName
        stopNameLabel.font = UIFont.boldSystemFont(ofSize: 20)
        stopNameLabel.textColor = UIColor.label
        stopNameLabel.numberOfLines = 0
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Route count
        routeCountLabel.text = "共 \(stopResult.routeCount) 條路線經過此站"
        routeCountLabel.font = UIFont.systemFont(ofSize: 14)
        routeCountLabel.textColor = UIColor.secondaryLabel
        routeCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(stopNameLabel)
        headerView.addSubview(routeCountLabel)
        
        view.addSubview(headerView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            stopNameLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            stopNameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            stopNameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            routeCountLabel.topAnchor.constraint(equalTo: stopNameLabel.bottomAnchor, constant: 8),
            routeCountLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            routeCountLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            routeCountLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupTableViewLayout() {
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BusETATableViewCell.self, forCellReuseIdentifier: BusETATableViewCell.identifier)

        // Setup refresh control
        refreshControl.tintColor = UIColor.label
        refreshControl.attributedTitle = NSAttributedString(
            string: "更新路線",
            attributes: [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14)]
        )
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupEmptyStateLabel() {
        emptyStateLabel.text = "點擊重新載入路線資料"
        emptyStateLabel.textColor = UIColor.secondaryLabel
        emptyStateLabel.font = UIFont.systemFont(ofSize: 16)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.isHidden = true
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)
        
        // Add tap gesture for retry
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(retryLoadingData))
        emptyStateLabel.isUserInteractionEnabled = true
        emptyStateLabel.addGestureRecognizer(tapGesture)
        
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    @objc private func retryLoadingData() {
        retryCount = 0 // Reset retry count
        hideEmptyState()
        loadRoutesWithETA()
    }
    
    // MARK: - Data Loading
    private func loadRoutesWithETA() {
        guard !isLoading else { return }
        isLoading = true
        routesWithETA.removeAll()
        
        // Show loading indicator
        showLoading()
        
        // Update route count label
        routeCountLabel.text = "正在載入路線資料..."
        
        print("🚌 開始載入站點 \(stopResult.displayName) 的路線資料 (共 \(stopResult.routes.count) 條路線)")
        
        // Use cached route data from LocalBusDataManager instead of API call
        let cachedRoutes = stopResult.routes
        
        if cachedRoutes.isEmpty {
            // No routes found - this is normal for many stops
            self.isLoading = false
            self.retryCount = 0
            self.routeCountLabel.text = "此站點無巴士路線數據"
            
            print("ℹ️ 站點 \(self.stopResult.stopId) (\(self.stopResult.displayName)) 沒有路線數據 (正常情況)")
            
            self.hideLoading()
            self.showEmptyState(message: "此站點暫無巴士路線記錄\n\n這可能是：\n• 小巴站點\n• 較新的巴士站\n• 數據庫未收錄的站點")
            return
        }
        
        // Use cached routes directly (they are already StopRoute objects)
        // Now fetch ETA for each route
        self.fetchETAForRoutes(cachedRoutes)
    }
    
    private func fetchETAForRoutes(_ routes: [StopRoute]) {
        let dispatchGroup = DispatchGroup()
        var tempRoutesWithETA: [RouteWithETA] = []
        
        for route in routes {
            dispatchGroup.enter()
            
            // Fetch ETA for this route at this stop
            apiService.fetchStopETA(
                stopId: stopResult.stopId,
                routeNumber: route.routeNumber,
                company: route.company,
                direction: route.direction
            ) { [weak self] result in
                defer { dispatchGroup.leave() }
                
                guard let self = self else { return }
                
                switch result {
                case .success(let etas):
                    let isFavorite = self.checkIfRouteIsFavorite(route: route)
                    let routeWithETA = RouteWithETA(
                        route: route,
                        etas: etas,
                        isFavorite: isFavorite
                    )
                    tempRoutesWithETA.append(routeWithETA)
                    
                case .failure:
                    // Still add the route but with empty ETA
                    let isFavorite = self.checkIfRouteIsFavorite(route: route)
                    let routeWithETA = RouteWithETA(
                        route: route,
                        etas: [],
                        isFavorite: isFavorite
                    )
                    tempRoutesWithETA.append(routeWithETA)
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Sort routes by route number
            self.routesWithETA = tempRoutesWithETA.sorted { first, second in
                // Try to sort numerically first, then alphabetically
                if let firstNumber = Int(first.route.routeNumber.prefix(while: { $0.isNumber })),
                   let secondNumber = Int(second.route.routeNumber.prefix(while: { $0.isNumber })) {
                    return firstNumber < secondNumber
                } else {
                    return first.route.routeNumber < second.route.routeNumber
                }
            }
            
            self.isLoading = false
            self.retryCount = 0 // Reset retry count on success
            
            // Update route count label
            self.routeCountLabel.text = "共 \(self.routesWithETA.count) 條路線經過此站"
            
            // Hide loading and show results
            self.hideLoading()
            self.tableView.reloadData()
            
            print("✅ 成功載入 \(self.routesWithETA.count) 條路線")
        }
    }

    @objc private func handleRefresh() {
        print("🔄 用戶下拉刷新路線")

        // Reload routes with ETA
        loadRoutesWithETA()

        // End refresh after loading completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshControl.endRefreshing()
        }
    }
}

// MARK: - UITableViewDataSource
extension StopRoutesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return routesWithETA.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BusETATableViewCell.identifier, for: indexPath) as? BusETATableViewCell else {
            return UITableViewCell()
        }

        let routeWithETA = routesWithETA[indexPath.row]

        // Convert RouteWithETA to BusDisplayData format
        let busRoute = BusRoute(
            stopId: stopResult.stopId,
            route: routeWithETA.route.routeNumber,
            companyId: routeWithETA.route.company.rawValue,
            direction: routeWithETA.route.direction,
            subTitle: ""
        )

        let displayData = BusDisplayData(
            route: busRoute,
            stopName: stopResult.displayName,
            destination: routeWithETA.route.destination,
            etas: routeWithETA.etas,
            isLoadingETAs: false
        )

        cell.configure(with: displayData)

        // Show star button and set favorite state
        cell.setStarButtonVisible(true)
        cell.setFavoriteState(routeWithETA.isFavorite)

        // Handle favorite toggle
        cell.onFavoriteToggle = { [weak self] in
            self?.toggleFavorite(for: routeWithETA.route, at: indexPath)
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension StopRoutesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 82
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let routeWithETA = routesWithETA[indexPath.row]

        // Navigate to route detail page
        showRouteDetail(for: routeWithETA.route)
    }
    
    private func showRouteDetail(for route: StopRoute) {
        let routeDetailVC = RouteDetailViewController(
            routeNumber: route.routeNumber,
            company: route.company,
            direction: route.direction
        )

        // Custom transition animation (same as SearchViewController)
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .moveIn
        transition.subtype = .fromRight
        navigationController?.view.layer.add(transition, forKey: kCATransition)

        navigationController?.pushViewController(routeDetailVC, animated: false)
    }

    private func checkIfRouteIsFavorite(route: StopRoute) -> Bool {
        let busRoute = BusRoute(
            stopId: stopResult.stopId,
            route: route.routeNumber,
            companyId: route.company.rawValue,
            direction: route.direction,
            subTitle: ""
        )
        
        return favoritesManager.isFavorite(busRoute)
    }
    
    private func toggleFavorite(for route: StopRoute, at indexPath: IndexPath) {
        let busRoute = BusRoute(
            stopId: stopResult.stopId,
            route: route.routeNumber,
            companyId: route.company.rawValue,
            direction: route.direction,
            subTitle: "從站點搜尋加入"
        )
        
        if favoritesManager.isFavorite(busRoute) {
            favoritesManager.removeFavorite(busRoute)
            showMessage("已從我的最愛移除", isError: false)
        } else {
            favoritesManager.addFavorite(busRoute, subTitle: "從站點搜尋加入")
            showMessage("已加入我的最愛", isError: false)
        }
        
        // Reload the specific cell
        if let cell = tableView.cellForRow(at: indexPath) as? BusETATableViewCell {
            let isFavorite = checkIfRouteIsFavorite(route: route)
            cell.setFavoriteState(isFavorite)
        }
    }
    
    private func showMessage(_ message: String, isError: Bool) {
        let alert = UIAlertController(title: isError ? "錯誤" : "成功", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Loading States
    private func showLoading() {
        loadingIndicator.startAnimating()
        tableView.isHidden = true
        hideEmptyState()
    }
    
    private func hideLoading() {
        loadingIndicator.stopAnimating()
        tableView.isHidden = false
    }
    
    private func showEmptyState(message: String = "點擊重新載入路線資料") {
        emptyStateLabel.text = message
        emptyStateLabel.isHidden = false
        hideLoading()
    }
    
    private func hideEmptyState() {
        emptyStateLabel.isHidden = true
    }
}

// MARK: - RouteWithETA Data Structure
struct RouteWithETA {
    let route: StopRoute
    let etas: [BusETA]
    let isFavorite: Bool
    
    init(route: StopRoute, etas: [BusETA] = [], isFavorite: Bool = false) {
        self.route = route
        self.etas = etas
        self.isFavorite = isFavorite
    }
}