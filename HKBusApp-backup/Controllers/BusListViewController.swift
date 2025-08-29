import UIKit

class BusListViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private var busDisplayData: [BusDisplayData] = []
    private var groupedData: [(subtitle: String, routes: [BusDisplayData])] = []
    private var refreshTimer: Timer?
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupRefreshControl()
        setupEditButton()
        loadData()
        startAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func setupUI() {
        // Remove title for more compact design
        view.backgroundColor = UIColor.black
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.black
        tableView.separatorStyle = .none
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.register(BusETATableViewCell.self, forCellReuseIdentifier: BusETATableViewCell.identifier)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        refreshControl.tintColor = UIColor.systemBlue
        tableView.refreshControl = refreshControl
    }
    
    private func setupEditButton() {
        // Add edit button in top-right corner
        let editButton = UIButton(type: .system)
        editButton.setTitle("編輯", for: .normal)
        editButton.setTitle("完成", for: .selected)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        editButton.setTitleColor(.white, for: .normal)
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(editButton)
        NSLayoutConstraint.activate([
            editButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            editButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func editButtonTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        tableView.setEditing(sender.isSelected, animated: true)
        
        if sender.isSelected {
            refreshTimer?.invalidate()
        } else {
            startAutoRefresh()
        }
    }
    
    @objc private func handleRefresh() {
        loadData()
    }
    
    private func loadData() {
        let routes = favoritesManager.getAllFavorites()
        let group = DispatchGroup()
        var newDisplayData: [BusDisplayData] = []
        
        for route in routes {
            group.enter()
            apiService.fetchBusDisplayData(for: route) { result in
                switch result {
                case .success(let displayData):
                    newDisplayData.append(displayData)
                case .failure(let error):
                    print("Error loading data for route \(route.route): \(error)")
                    // Add empty data to maintain order
                    newDisplayData.append(BusDisplayData(route: route))
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.busDisplayData = newDisplayData.sorted { first, second in
                // Sort by original order in BusRouteConfiguration.defaultRoutes
                guard let firstIndex = routes.firstIndex(of: first.route),
                      let secondIndex = routes.firstIndex(of: second.route) else {
                    return false
                }
                return firstIndex < secondIndex
            }
            
            self.groupDataBySubtitle()
            self.tableView.reloadData()
            self.refreshControl.endRefreshing()
        }
    }
    
    private func groupDataBySubtitle() {
        let grouped = Dictionary(grouping: busDisplayData) { $0.route.subTitle }
        groupedData = grouped.map { (subtitle: $0.key, routes: $0.value) }
            .sorted { first, second in
                let subtitleOrder = ["由雍明苑出發", "到達調景嶺站", "由調景嶺回家方向", "其他"]
                let firstIndex = subtitleOrder.firstIndex(of: first.subtitle) ?? subtitleOrder.count
                let secondIndex = subtitleOrder.firstIndex(of: second.subtitle) ?? subtitleOrder.count
                return firstIndex < secondIndex
            }
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 50.0, repeats: true) { [weak self] _ in
            self?.loadData()
        }
    }
}

// MARK: - UITableViewDataSource
extension BusListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return groupedData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupedData[section].routes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BusETATableViewCell.identifier, for: indexPath) as? BusETATableViewCell else {
            return UITableViewCell()
        }
        
        let displayData = groupedData[indexPath.section].routes[indexPath.row]
        cell.configure(with: displayData)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension BusListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        
        let label = UILabel()
        label.text = groupedData[section].subtitle
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        return headerView
    }
    
    // MARK: - Editing Support
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let displayData = groupedData[indexPath.section].routes[indexPath.row]
            favoritesManager.removeFavorite(displayData.route)
            loadData()
        }
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Handle reordering within the same section
        if sourceIndexPath.section == destinationIndexPath.section {
            var sectionData = groupedData[sourceIndexPath.section].routes
            let movedItem = sectionData.remove(at: sourceIndexPath.row)
            sectionData.insert(movedItem, at: destinationIndexPath.row)
            
            // Update the grouped data
            groupedData[sourceIndexPath.section] = (
                subtitle: groupedData[sourceIndexPath.section].subtitle,
                routes: sectionData
            )
            
            // Save the new order
            let allRoutes = groupedData.flatMap { $0.routes.map { $0.route } }
            favoritesManager.updateFavoriteOrder(allRoutes)
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
}