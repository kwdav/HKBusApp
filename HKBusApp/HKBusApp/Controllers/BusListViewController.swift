import UIKit

class BusListViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private var busDisplayData: [BusDisplayData] = []
    private var groupedData: [(subtitle: String, routes: [BusDisplayData])] = []
    private var refreshTimer: Timer?
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    private let statusBarView = UIView()
    private let editButton = UIButton(type: .system)
    private let updateButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
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
        // Black background for consistency
        view.backgroundColor = UIColor.black
        
        // Setup table view to go under status bar
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Setup status bar overlay
        statusBarView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBarView)
        
        // Create header view for edit button
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 44))
        headerView.backgroundColor = UIColor.clear
        
        // Setup update button in header (left side) with long press for attribution
        updateButton.setTitle("🔄", for: .normal)
        updateButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        updateButton.setTitleColor(.white, for: .normal)
        updateButton.addTarget(self, action: #selector(updateStopData), for: .touchUpInside)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(updateButton)
        
        // Add long press gesture for showing attribution
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(showAttribution))
        longPressGesture.minimumPressDuration = 1.0
        updateButton.addGestureRecognizer(longPressGesture)
        
        // Setup edit button in header (right side)
        editButton.setTitle("編輯", for: .normal)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        editButton.setTitleColor(.white, for: .normal)
        editButton.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(editButton)
        
        NSLayoutConstraint.activate([
            updateButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            updateButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            
            editButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16)
        ])
        
        tableView.tableHeaderView = headerView
        
        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 44
        
        NSLayoutConstraint.activate([
            // Table view goes full screen
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Status bar overlay
            statusBarView.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBarView.heightAnchor.constraint(equalToConstant: statusBarHeight)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.black
        tableView.separatorStyle = .none
        tableView.contentInsetAdjustmentBehavior = .never
        // Add bottom inset for tab bar
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 49
        tableView.contentInset = UIEdgeInsets(top: 44, left: 0, bottom: tabBarHeight, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        tableView.register(BusETATableViewCell.self, forCellReuseIdentifier: BusETATableViewCell.identifier)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        refreshControl.tintColor = UIColor.systemBlue
        tableView.refreshControl = refreshControl
    }
    
    private func setupEditButton() {
        // Edit button is already set up in setupUI()
    }
    
    @objc private func toggleEditMode() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        editButton.setTitle(tableView.isEditing ? "完成" : "編輯", for: .normal)
        
        if tableView.isEditing {
            refreshTimer?.invalidate()
            showAddSectionButton()
        } else {
            hideAddSectionButton()
            startAutoRefresh()
        }
        
        // Reload sections to show/hide edit buttons
        tableView.reloadData()
    }
    
    private func showAddSectionButton() {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))
        footerView.backgroundColor = UIColor.clear
        
        let addButton = UIButton(type: .system)
        addButton.setTitle("+ 新增分類", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        addButton.addTarget(self, action: #selector(addNewSection), for: .touchUpInside)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        footerView.addSubview(addButton)
        NSLayoutConstraint.activate([
            addButton.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            addButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
        
        tableView.tableFooterView = footerView
    }
    
    private func hideAddSectionButton() {
        tableView.tableFooterView = nil
    }
    
    @objc private func addNewSection() {
        let alert = UIAlertController(title: "新增分類", message: "請輸入分類名稱", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "分類名稱"
        }
        
        let addAction = UIAlertAction(title: "新增", style: .default) { [weak self] _ in
            guard let self = self,
                  let subtitle = alert.textFields?.first?.text,
                  !subtitle.isEmpty else { return }
            
            self.groupedData.append((subtitle: subtitle, routes: []))
            self.tableView.reloadData()
        }
        
        alert.addAction(addAction)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func editSectionTitle(_ sender: UIButton) {
        let section = sender.tag
        let currentTitle = groupedData[section].subtitle
        
        let alert = UIAlertController(title: "編輯分類", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = currentTitle
        }
        
        let saveAction = UIAlertAction(title: "儲存", style: .default) { [weak self] _ in
            guard let self = self,
                  let newTitle = alert.textFields?.first?.text,
                  !newTitle.isEmpty else { return }
            
            self.groupedData[section].subtitle = newTitle
            self.tableView.reloadSections(IndexSet(integer: section), with: .none)
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func handleSectionLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let headerView = gesture.view else { return }
        
        // Find the current section index by comparing headerView with all visible headers
        var section = 0
        for i in 0..<tableView.numberOfSections {
            if let visibleHeader = tableView.headerView(forSection: i),
               visibleHeader == headerView {
                section = i
                break
            }
        }
        
        switch gesture.state {
        case .began:
            // Show visual feedback
            UIView.animate(withDuration: 0.2) {
                headerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                headerView.alpha = 0.8
            }
            
            // Show reorder options
            showSectionReorderMenu(for: section, from: headerView)
            
        case .ended, .cancelled:
            // Reset visual feedback
            UIView.animate(withDuration: 0.2) {
                headerView.transform = .identity
                headerView.alpha = 1.0
            }
            
        default:
            break
        }
    }
    
    private func showSectionReorderMenu(for section: Int, from view: UIView) {
        let alert = UIAlertController(title: "移動分類", message: "選擇移動方向", preferredStyle: .actionSheet)
        
        // Move up option
        if section > 0 {
            alert.addAction(UIAlertAction(title: "向上移動", style: .default) { [weak self] _ in
                self?.moveSection(from: section, to: section - 1)
            })
        }
        
        // Move down option
        if section < groupedData.count - 1 {
            alert.addAction(UIAlertAction(title: "向下移動", style: .default) { [weak self] _ in
                self?.moveSection(from: section, to: section + 1)
            })
        }
        
        // Move to top
        if section > 0 {
            alert.addAction(UIAlertAction(title: "移至最頂", style: .default) { [weak self] _ in
                self?.moveSection(from: section, to: 0)
            })
        }
        
        // Move to bottom
        if section < groupedData.count - 1 {
            alert.addAction(UIAlertAction(title: "移至最底", style: .default) { [weak self] _ in
                self?.moveSection(from: section, to: self?.groupedData.count ?? 0 - 1)
            })
        }
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func moveSection(from: Int, to: Int) {
        guard from != to else { return }
        
        let movedSection = groupedData.remove(at: from)
        let targetIndex = from < to ? to : to
        groupedData.insert(movedSection, at: targetIndex)
        
        // Save the new order
        saveSectionOrder()
        
        // Animate the move
        tableView.beginUpdates()
        tableView.moveSection(from, toSection: targetIndex)
        tableView.endUpdates()
    }
    
    @objc private func deleteSection(_ sender: UIButton) {
        let section = sender.tag
        let title = groupedData[section].subtitle
        let routeCount = groupedData[section].routes.count
        
        var message = "確定要刪除「\(title)」分類嗎？"
        if routeCount > 0 {
            message += "\n\n⚠️ 注意：此分類包含 \(routeCount) 條巴士路線，刪除分類將同時刪除這些路線。"
        }
        
        let alert = UIAlertController(title: "刪除分類", message: message, preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "刪除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            // Remove routes from favorites if they exist
            for route in self.groupedData[section].routes {
                self.favoritesManager.removeFavorite(route.route)
            }
            
            self.groupedData.remove(at: section)
            self.tableView.deleteSections(IndexSet(integer: section), with: .fade)
        }
        
        alert.addAction(deleteAction)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func handleRefresh() {
        loadData()
    }
    
    @objc private func updateStopData() {
        // Prevent multiple simultaneous updates
        updateButton.isEnabled = false
        updateButton.setTitle("⏳", for: .normal)
        
        print("🔄 用戶手動觸發站點數據更新...")
        
        StopDataManager.shared.forceUpdateData { [weak self] result in
            DispatchQueue.main.async {
                self?.updateButton.isEnabled = true
                self?.updateButton.setTitle("🔄", for: .normal)
                
                switch result {
                case .success(let stopData):
                    print("✅ 站點數據更新成功，共 \(stopData.stopList.count) 個站點")
                    
                    // Show success feedback to user
                    let alert = UIAlertController(
                        title: "更新成功",
                        message: "站點資料已更新至最新版本\n包含 \(stopData.stopList.count) 個巴士站",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                    self?.present(alert, animated: true)
                    
                case .failure(let error):
                    print("❌ 站點數據更新失敗: \(error.localizedDescription)")
                    
                    // Show error feedback to user
                    let alert = UIAlertController(
                        title: "更新失敗",
                        message: "無法更新站點資料，請檢查網路連線並稍後再試",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    @objc private func showAttribution() {
        guard let lastUpdate = StopDataManager.shared.getLastUpdateTime() else {
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_Hant_HK")
        
        let updateTimeString = formatter.string(from: lastUpdate)
        
        let alert = UIAlertController(
            title: "關於站點數據",
            message: """
            📊 數據來源：HK Bus Crawling@2021
            🔗 GitHub: github.com/hkbus/hk-bus-crawling
            📜 授權：GPL-2.0 License
            
            🕐 最後更新：\(updateTimeString)
            
            感謝 hk-bus-crawling 項目提供完整的香港巴士站點資料。
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "訪問 GitHub", style: .default) { _ in
            if let url = URL(string: "https://github.com/hkbus/hk-bus-crawling") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "確定", style: .cancel))
        present(alert, animated: true)
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
        let grouped = Dictionary(grouping: busDisplayData) { 
            $0.route.subTitle.isEmpty ? "未分類" : $0.route.subTitle 
        }
        
        // Check if we have a saved order
        let savedOrder = UserDefaults.standard.array(forKey: "sectionOrder") as? [String] ?? []
        
        if !savedOrder.isEmpty {
            // Use saved order
            var orderedGroups: [(subtitle: String, routes: [BusDisplayData])] = []
            
            // Add sections in saved order
            for subtitle in savedOrder {
                if let routes = grouped[subtitle] {
                    orderedGroups.append((subtitle: subtitle, routes: routes))
                }
            }
            
            // Add any new sections not in saved order
            for (subtitle, routes) in grouped {
                if !savedOrder.contains(subtitle) {
                    orderedGroups.append((subtitle: subtitle, routes: routes))
                }
            }
            
            groupedData = orderedGroups
        } else {
            // Use default order
            groupedData = grouped.map { (subtitle: $0.key, routes: $0.value) }
                .sorted { first, second in
                    // "未分類" always goes to the end
                    if first.subtitle == "未分類" { return false }
                    if second.subtitle == "未分類" { return true }
                    
                    let subtitleOrder = ["由雍明苑出發", "到達調景嶺站", "由調景嶺回家方向", "其他"]
                    let firstIndex = subtitleOrder.firstIndex(of: first.subtitle) ?? subtitleOrder.count
                    let secondIndex = subtitleOrder.firstIndex(of: second.subtitle) ?? subtitleOrder.count
                    return firstIndex < secondIndex
                }
        }
    }
    
    private func saveSectionOrder() {
        let order = groupedData.map { $0.subtitle }
        UserDefaults.standard.set(order, forKey: "sectionOrder")
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
        return 82
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 25
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0) // Softer than 0.2
        
        // Add long press gesture for reordering sections
        if tableView.isEditing {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleSectionLongPress(_:)))
            headerView.addGestureRecognizer(longPress)
            headerView.tag = section
        }
        
        // Add subtle gradient effect
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(white: 0.18, alpha: 1.0).cgColor,
            UIColor(white: 0.12, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 32)
        headerView.layer.addSublayer(gradientLayer)
        
        let label = UILabel()
        label.text = groupedData[section].subtitle
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(white: 0.9, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle shadow for depth
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowOpacity = 0.3
        label.layer.shadowRadius = 1
        
        headerView.addSubview(label)
        
        if tableView.isEditing {
            // Add edit and delete buttons in edit mode
            let editButton = UIButton(type: .system)
            editButton.setTitle("編輯", for: .normal)
            editButton.setTitleColor(.white, for: .normal)
            editButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            editButton.tag = section
            editButton.addTarget(self, action: #selector(editSectionTitle(_:)), for: .touchUpInside)
            editButton.translatesAutoresizingMaskIntoConstraints = false
            
            let deleteButton = UIButton(type: .system)
            deleteButton.setTitle("刪除", for: .normal)
            deleteButton.setTitleColor(.systemRed, for: .normal)
            deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            deleteButton.tag = section
            deleteButton.addTarget(self, action: #selector(deleteSection(_:)), for: .touchUpInside)
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            
            headerView.addSubview(editButton)
            headerView.addSubview(deleteButton)
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 6),
                label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -10),
                
                editButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                editButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -10),
                
                deleteButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                deleteButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10)
            ])
        } else {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -6),
                label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
            ])
        }
        
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
            
            // Check if no favorites left, reset initial tab behavior for next launch
            let remainingFavorites = favoritesManager.getAllFavorites().count
            if remainingFavorites == 0 {
                // Reset the initial tab behavior so next launch will go to route search
                if let tabBarController = self.tabBarController as? MainTabBarController {
                    tabBarController.resetInitialTabBehavior()
                    print("📱 所有收藏已刪除，下次啟動將自動切換到路線搜尋頁面")
                }
            }
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