import UIKit

class StopETAViewController: UIViewController {
    
    // MARK: - Properties
    private let stop: BusStop
    private let routeNumber: String
    private let company: BusRoute.Company
    private let direction: String
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let apiService = BusAPIService.shared
    private var etaData: [BusETA] = []
    private var isLoading = false
    private var refreshTimer: Timer?
    
    // MARK: - UI Components
    private let headerView = UIView()
    private let stopNameLabel = UILabel()
    private let routeInfoLabel = UILabel()
    private let refreshControl = UIRefreshControl()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let emptyStateView = UIView()
    private let emptyLabel = UILabel()
    
    // MARK: - Initialization
    init(stop: BusStop, routeNumber: String, company: BusRoute.Company, direction: String) {
        self.stop = stop
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
        setupRefreshTimer()
        loadETAData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Slide-in animation from right
        view.transform = CGAffineTransform(translationX: view.bounds.width, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.view.transform = .identity
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        refreshTimer?.invalidate()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "巴士到站時間"
        
        // Navigation bar setup - support both light and dark mode
        navigationController?.navigationBar.tintColor = UIColor.label
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        setupHeaderView()
        setupEmptyStateView()
        setupTableViewLayout()
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = UIColor.secondarySystemBackground
        headerView.layer.cornerRadius = 12
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name
        stopNameLabel.text = stop.displayName
        stopNameLabel.font = UIFont.boldSystemFont(ofSize: 20)
        stopNameLabel.textColor = UIColor.label
        stopNameLabel.numberOfLines = 0
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Route info
        routeInfoLabel.text = "\(company.rawValue) \(routeNumber) - \(direction == "outbound" ? "去程" : "回程")"
        routeInfoLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        routeInfoLabel.textColor = companyColor(for: company)
        routeInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(stopNameLabel)
        headerView.addSubview(routeInfoLabel)
        
        view.addSubview(headerView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            stopNameLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            stopNameLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            stopNameLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            routeInfoLabel.topAnchor.constraint(equalTo: stopNameLabel.bottomAnchor, constant: 8),
            routeInfoLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            routeInfoLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            routeInfoLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupEmptyStateView() {
        emptyStateView.backgroundColor = UIColor.clear
        emptyStateView.isHidden = true
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        emptyLabel.text = "暫時沒有班次資料\n請稍後再試"
        emptyLabel.font = UIFont.systemFont(ofSize: 16)
        emptyLabel.textColor = UIColor.secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        emptyStateView.addSubview(emptyLabel)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            emptyLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor)
        ])
    }
    
    private func setupTableViewLayout() {
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false

        // Refresh control
        refreshControl.tintColor = UIColor.label
        refreshControl.attributedTitle = NSAttributedString(
            string: "更新到站時間",
            attributes: [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14)]
        )
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

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
        tableView.register(ETATableViewCell.self, forCellReuseIdentifier: ETATableViewCell.identifier)
    }
    
    // MARK: - Data Loading
    private func loadETAData() {
        guard !isLoading else { return }
        
        isLoading = true
        
        apiService.fetchStopETA(
            stopId: stop.stopId,
            routeNumber: routeNumber,
            company: company,
            direction: direction
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.refreshControl.endRefreshing()
                
                switch result {
                case .success(let etas):
                    self?.etaData = etas.prefix(5).map { $0 } // Show max 5 upcoming buses
                    self?.updateEmptyState()
                    self?.tableView.reloadData()
                case .failure(let error):
                    print("ETA載入錯誤: \(error.localizedDescription)")
                    self?.etaData = []
                    self?.updateEmptyState()
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !etaData.isEmpty
        tableView.isHidden = etaData.isEmpty
    }
    
    private func setupRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.loadETAData()
        }
    }
    
    @objc private func handleRefresh() {
        loadETAData()
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
extension StopETAViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return etaData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ETATableViewCell.identifier, for: indexPath) as? ETATableViewCell else {
            return UITableViewCell()
        }
        
        let eta = etaData[indexPath.row]
        let isFirst = indexPath.row == 0
        
        cell.configure(with: eta, routeNumber: routeNumber, isNext: isFirst)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension StopETAViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.row == 0 ? 80 : 60 // First bus gets more space
    }
}

// MARK: - ETA Table View Cell
class ETATableViewCell: UITableViewCell {
    
    static let identifier = "ETATableViewCell"
    
    private let containerView = UIView()
    private let routeLabel = UILabel()
    private let etaLabel = UILabel()
    private let timeLabel = UILabel()
    private let nextLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        contentView.backgroundColor = UIColor.systemBackground
        selectionStyle = .none
        
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        routeLabel.font = UIFont.boldSystemFont(ofSize: 20)
        routeLabel.textColor = UIColor.label
        routeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        etaLabel.font = UIFont.boldSystemFont(ofSize: 24)
        etaLabel.textColor = UIColor.systemGreen
        etaLabel.translatesAutoresizingMaskIntoConstraints = false
        
        timeLabel.font = UIFont.systemFont(ofSize: 14)
        timeLabel.textColor = UIColor.secondaryLabel
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        nextLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        nextLabel.textColor = UIColor.systemOrange
        nextLabel.text = "下一班"
        nextLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(routeLabel)
        containerView.addSubview(etaLabel)
        containerView.addSubview(timeLabel)
        containerView.addSubview(nextLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            routeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routeLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            nextLabel.leadingAnchor.constraint(equalTo: routeLabel.trailingAnchor, constant: 8),
            nextLabel.centerYAnchor.constraint(equalTo: routeLabel.centerYAnchor),
            
            etaLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            etaLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -8),
            
            timeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: etaLabel.bottomAnchor, constant: 2)
        ])
    }
    
    func configure(with eta: BusETA, routeNumber: String, isNext: Bool) {
        routeLabel.text = routeNumber
        
        let etaFormat = eta.formattedETAWithSeparateTime
        etaLabel.text = etaFormat.minutes
        timeLabel.text = etaFormat.time
        
        nextLabel.isHidden = !isNext
        
        // Color coding based on ETA
        let minutes = eta.minutesUntilArrival
        if minutes <= 0 {
            etaLabel.textColor = UIColor.systemRed
        } else if minutes <= 2 {
            etaLabel.textColor = UIColor.systemOrange
        } else {
            etaLabel.textColor = UIColor.systemGreen
        }
    }
}