import UIKit

class RouteDetailViewController: UIViewController {
    
    // MARK: - Properties
    private let routeNumber: String
    private let company: BusRoute.Company
    private let direction: String
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    private var routeDetail: BusRouteDetail?
    private var isLoading = false
    private var isFavorite = false
    
    // MARK: - UI Components
    private let headerView = UIView()
    private let routeLabel = UILabel()
    private let companyLabel = UILabel()
    private let directionLabel = UILabel()
    private let durationLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Initialization
    init(routeNumber: String, company: BusRoute.Company, direction: String) {
        self.routeNumber = routeNumber
        self.company = company
        self.direction = direction
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
        checkFavoriteStatus()
        loadRouteDetail()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Add subtle fade-in animation
        view.alpha = 0.0
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseInOut) {
            self.view.alpha = 1.0
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "\(company.rawValue) \(routeNumber)"
        
        // Navigation bar setup - support both light and dark mode
        navigationController?.navigationBar.tintColor = UIColor.label
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigationController?.navigationBar.barStyle = .default
        
        setupHeaderView()
        setupTableViewLayout()
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = UIColor.secondarySystemBackground
        headerView.layer.cornerRadius = 12
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Route number
        routeLabel.text = routeNumber
        routeLabel.font = UIFont.boldSystemFont(ofSize: 32)
        routeLabel.textColor = UIColor.label
        routeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Company label with color coding
        companyLabel.text = company.rawValue
        companyLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        companyLabel.textColor = .white
        companyLabel.backgroundColor = companyColor(for: company)
        companyLabel.textAlignment = .center
        companyLabel.layer.cornerRadius = 4
        companyLabel.clipsToBounds = true
        companyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Direction label
        directionLabel.text = "載入中..."
        directionLabel.font = UIFont.systemFont(ofSize: 16)
        directionLabel.textColor = UIColor.secondaryLabel
        directionLabel.numberOfLines = 0
        directionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Duration label
        durationLabel.text = ""
        durationLabel.font = UIFont.systemFont(ofSize: 14)
        durationLabel.textColor = UIColor.tertiaryLabel
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Favorite button
        favoriteButton.setImage(UIImage(systemName: "star"), for: .normal)
        favoriteButton.setImage(UIImage(systemName: "star.fill"), for: .selected)
        favoriteButton.tintColor = UIColor.systemYellow
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(routeLabel)
        headerView.addSubview(companyLabel)
        headerView.addSubview(directionLabel)
        headerView.addSubview(durationLabel)
        headerView.addSubview(favoriteButton)
        
        view.addSubview(headerView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            
            routeLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            routeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            companyLabel.centerYAnchor.constraint(equalTo: routeLabel.centerYAnchor),
            companyLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -12),
            companyLabel.widthAnchor.constraint(equalToConstant: 60),
            companyLabel.heightAnchor.constraint(equalToConstant: 24),
            
            favoriteButton.centerYAnchor.constraint(equalTo: routeLabel.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32),
            
            directionLabel.topAnchor.constraint(equalTo: routeLabel.bottomAnchor, constant: 8),
            directionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            directionLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            durationLabel.topAnchor.constraint(equalTo: directionLabel.bottomAnchor, constant: 4),
            durationLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            durationLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
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
        tableView.register(RouteStopTableViewCell.self, forCellReuseIdentifier: RouteStopTableViewCell.identifier)
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
        
        if let duration = detail.estimatedDuration {
            durationLabel.text = "預計行程時間: \(duration)分鐘"
        }
        
        if let hours = detail.operatingHours {
            durationLabel.text = (durationLabel.text ?? "") + " • \(hours)"
        }
        
        // Check if any stop is already in favorites
        checkIfAnyStopIsFavorite()
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
    
    // MARK: - Favorites Management
    private func checkFavoriteStatus() {
        // Since we don't have a stopId yet, we'll handle this when route detail loads
        // For now, assume it's not a favorite
        isFavorite = false
        updateFavoriteButton()
    }
    
    private func updateFavoriteButton() {
        favoriteButton.isSelected = isFavorite
        
        // Add subtle animation
        UIView.animate(withDuration: 0.2) {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.favoriteButton.transform = .identity
            }
        }
    }
    
    @objc private func favoriteButtonTapped() {
        // Show action sheet to let user choose which stop to add to favorites
        showStopSelectionForFavorites()
    }
    
    private func showStopSelectionForFavorites() {
        guard let routeDetail = routeDetail else { return }
        
        let actionSheet = UIAlertController(
            title: "加入我的最愛",
            message: "請選擇要加入我的最愛的巴士站，將會收藏此站點的 \(company.rawValue) \(routeNumber) 路線到站時間",
            preferredStyle: .actionSheet
        )
        
        // Add each stop as an option
        for stop in routeDetail.stops {
            let actionTitle = "\(stop.sequence). \(stop.displayName)"
            let action = UIAlertAction(title: actionTitle, style: .default) { _ in
                self.addStopToFavorites(stop: stop, routeDetail: routeDetail)
            }
            actionSheet.addAction(action)
        }
        
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // For iPad
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = favoriteButton
            popover.sourceRect = favoriteButton.bounds
        }
        
        present(actionSheet, animated: true)
    }
    
    private func addStopToFavorites(stop: BusStop, routeDetail: BusRouteDetail) {
        let busRoute = BusRoute(
            stopId: stop.stopId,
            route: routeDetail.routeNumber,
            companyId: routeDetail.company.rawValue,
            direction: routeDetail.direction,
            subTitle: "在 \(stop.displayName)"
        )
        
        if favoritesManager.isFavorite(busRoute) {
            // Show already exists message
            showMessage("此站點的 \(routeDetail.company.rawValue) \(routeDetail.routeNumber) 路線已在我的最愛中", isError: false)
        } else {
            favoritesManager.addFavorite(busRoute, subTitle: "在 \(stop.displayName)")
            showMessage("已將 \(stop.displayName) 的 \(routeDetail.company.rawValue) \(routeDetail.routeNumber) 路線加入我的最愛", isError: false)
            
            // Update favorite status for any matching stops
            checkIfAnyStopIsFavorite()
        }
    }
    
    private func checkIfAnyStopIsFavorite() {
        guard let routeDetail = routeDetail else { return }
        
        // Check if any stop in this route is already a favorite
        for stop in routeDetail.stops {
            let busRoute = BusRoute(
                stopId: stop.stopId,
                route: routeDetail.routeNumber,
                companyId: routeDetail.company.rawValue,
                direction: routeDetail.direction,
                subTitle: ""
            )
            
            if favoritesManager.isFavorite(busRoute) {
                isFavorite = true
                updateFavoriteButton()
                return
            }
        }
        
        isFavorite = false
        updateFavoriteButton()
    }
    
    private func showMessage(_ message: String, isError: Bool) {
        let alert = UIAlertController(title: isError ? "錯誤" : "成功", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
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
              let stops = routeDetail?.stops else {
            return UITableViewCell()
        }
        
        let stop = stops[indexPath.row]
        let isFirst = indexPath.row == 0
        let isLast = indexPath.row == stops.count - 1
        
        cell.configure(with: stop, isFirst: isFirst, isLast: isLast)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension RouteDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let routeDetail = routeDetail else { return }
        let stop = routeDetail.stops[indexPath.row]
        
        // Navigate to stop ETA view with animation
        showStopETA(stop: stop, routeDetail: routeDetail)
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