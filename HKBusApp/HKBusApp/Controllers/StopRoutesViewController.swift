import UIKit

class StopRoutesViewController: UIViewController {
    
    // MARK: - Properties
    private let stopResult: StopSearchResult
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    
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
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black
        title = "站點路線"
        
        // Navigation bar setup
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        setupHeaderView()
        setupTableViewLayout()
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        headerView.layer.cornerRadius = 12
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name
        stopNameLabel.text = stopResult.displayName
        stopNameLabel.font = UIFont.boldSystemFont(ofSize: 20)
        stopNameLabel.textColor = .white
        stopNameLabel.numberOfLines = 0
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Route count
        routeCountLabel.text = "共 \(stopResult.routeCount) 條路線經過此站"
        routeCountLabel.font = UIFont.systemFont(ofSize: 14)
        routeCountLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
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
        tableView.backgroundColor = UIColor.black
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
        tableView.register(StopRouteTableViewCell.self, forCellReuseIdentifier: StopRouteTableViewCell.identifier)
    }
}

// MARK: - UITableViewDataSource
extension StopRoutesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stopResult.routes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: StopRouteTableViewCell.identifier, for: indexPath) as? StopRouteTableViewCell else {
            return UITableViewCell()
        }
        
        let route = stopResult.routes[indexPath.row]
        let isFavorite = checkIfRouteIsFavorite(route: route)
        
        cell.configure(with: route, isFavorite: isFavorite)
        cell.onFavoriteButtonTapped = { [weak self] in
            self?.toggleFavorite(for: route, at: indexPath)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension StopRoutesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let route = stopResult.routes[indexPath.row]
        
        // Navigate to stop ETA for this specific route
        showStopETA(for: route)
    }
    
    private func showStopETA(for route: StopRoute) {
        let busStop = BusStop(
            stopId: stopResult.stopId,
            sequence: 1,
            nameTC: stopResult.displayName,
            nameEN: stopResult.nameEN,
            latitude: stopResult.latitude,
            longitude: stopResult.longitude
        )
        
        let stopETAVC = StopETAViewController(
            stop: busStop,
            routeNumber: route.routeNumber,
            company: route.company,
            direction: route.direction
        )
        
        navigationController?.pushViewController(stopETAVC, animated: true)
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
        if let cell = tableView.cellForRow(at: indexPath) as? StopRouteTableViewCell {
            let isFavorite = checkIfRouteIsFavorite(route: route)
            cell.updateFavoriteButton(isFavorite: isFavorite)
        }
    }
    
    private func showMessage(_ message: String, isError: Bool) {
        let alert = UIAlertController(title: isError ? "錯誤" : "成功", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Stop Route Table View Cell
class StopRouteTableViewCell: UITableViewCell {
    
    static let identifier = "StopRouteTableViewCell"
    
    private let containerView = UIView()
    private let routeLabel = UILabel()
    private let companyLabel = UILabel()
    private let destinationLabel = UILabel()
    private let favoriteButton = UIButton(type: .system)
    private let chevronImageView = UIImageView()
    
    var onFavoriteButtonTapped: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black
        contentView.backgroundColor = UIColor.black
        selectionStyle = .none
        
        containerView.backgroundColor = UIColor(white: 0.05, alpha: 1.0)
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        routeLabel.font = UIFont.boldSystemFont(ofSize: 24)
        routeLabel.textColor = .white
        routeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        companyLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        companyLabel.textColor = .white
        companyLabel.textAlignment = .center
        companyLabel.layer.cornerRadius = 4
        companyLabel.clipsToBounds = true
        companyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        destinationLabel.font = UIFont.systemFont(ofSize: 16)
        destinationLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        destinationLabel.numberOfLines = 2
        destinationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        favoriteButton.setImage(UIImage(systemName: "star"), for: .normal)
        favoriteButton.setImage(UIImage(systemName: "star.fill"), for: .selected)
        favoriteButton.tintColor = UIColor.systemYellow
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = UIColor(white: 0.4, alpha: 1.0)
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(routeLabel)
        containerView.addSubview(companyLabel)
        containerView.addSubview(destinationLabel)
        containerView.addSubview(favoriteButton)
        containerView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            routeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routeLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -8),
            
            companyLabel.leadingAnchor.constraint(equalTo: routeLabel.trailingAnchor, constant: 8),
            companyLabel.centerYAnchor.constraint(equalTo: routeLabel.centerYAnchor),
            companyLabel.widthAnchor.constraint(equalToConstant: 50),
            companyLabel.heightAnchor.constraint(equalToConstant: 20),
            
            destinationLabel.topAnchor.constraint(equalTo: routeLabel.bottomAnchor, constant: 4),
            destinationLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            destinationLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -12),
            
            favoriteButton.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            favoriteButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32),
            
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    func configure(with route: StopRoute, isFavorite: Bool) {
        routeLabel.text = route.routeNumber
        companyLabel.text = route.company.rawValue
        companyLabel.backgroundColor = companyColor(for: route.company)
        destinationLabel.text = "往 \(route.destination)"
        favoriteButton.isSelected = isFavorite
    }
    
    func updateFavoriteButton(isFavorite: Bool) {
        favoriteButton.isSelected = isFavorite
    }
    
    @objc private func favoriteButtonTapped() {
        onFavoriteButtonTapped?()
    }
    
    private func companyColor(for company: BusRoute.Company) -> UIColor {
        switch company {
        case .CTB, .NWFB:
            return UIColor.systemYellow
        case .KMB:
            return UIColor.systemRed
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.1) {
            self.containerView.backgroundColor = highlighted ? 
                UIColor(white: 0.1, alpha: 1.0) : UIColor(white: 0.05, alpha: 1.0)
        }
    }
}