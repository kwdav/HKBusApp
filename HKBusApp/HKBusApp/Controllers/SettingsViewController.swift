import UIKit

class SettingsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let tapDetector = DeveloperToolsManager.TapDetector()

    // Section identifiers
    private enum Section: Int, CaseIterable {
        case dataManagement = 0
        case displaySettings = 1
        case about = 2

        var title: String {
            switch self {
            case .dataManagement: return "數據管理"
            case .displaySettings: return "顯示設定"
            case .about: return "關於"
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
    }

    private func setupUI() {
        title = "設定"
        view.backgroundColor = UIColor.systemGroupedBackground

        // Setup table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.register(SegmentedControlCell.self, forCellReuseIdentifier: "SegmentedControlCell")
    }

    // MARK: - Actions

    @objc private func updateRouteData() {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "更新中", message: "正在下載最新巴士數據...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        StopDataManager.shared.forceUpdateData { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let stopData):
                        let alert = UIAlertController(
                            title: "更新成功",
                            message: "站點資料已更新至最新版本\n包含 \(stopData.stopList.count) 個巴士站",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "確定", style: .default))
                        self?.present(alert, animated: true)

                    case .failure(let error):
                        let alert = UIAlertController(
                            title: "更新失敗",
                            message: "無法更新站點資料，請檢查網路連線並稍後再試\n\n錯誤：\(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "確定", style: .default))
                        self?.present(alert, animated: true)
                    }
                }
            }
        }
    }

    @objc private func fontSizeChanged(_ sender: UISegmentedControl) {
        let newFontSize: FontSizeManager.FontSize = sender.selectedSegmentIndex == 0 ? .normal : .large
        FontSizeManager.shared.currentFontSize = newFontSize

        // Show confirmation
        let message = newFontSize == .normal ? "已切換至普通字體" : "已切換至加大字體"
        showToast(message: message)
    }

    @objc private func versionAreaTapped() {
        tapDetector.registerTap { [weak self] in
            self?.showDeveloperMenu()
        }
    }

    private func showDeveloperMenu() {
        let alert = UIAlertController(
            title: "🛠️ 開發者工具",
            message: DeveloperToolsManager.shared.getDetailedInfo(),
            preferredStyle: .actionSheet
        )

        // Reset to default favorites action
        alert.addAction(UIAlertAction(title: "🔄 重置「我的」為預設路線", style: .destructive) { [weak self] _ in
            self?.confirmClearFavorites()
        })

        // Clear all favorites without restoring defaults
        alert.addAction(UIAlertAction(title: "🗑️ 清空所有「我的」收藏", style: .destructive) { [weak self] _ in
            self?.confirmClearAllFavoritesOnly()
        })

        // Reset reference data action
        alert.addAction(UIAlertAction(title: "📥 重新下載參考巴士數據", style: .default) { [weak self] _ in
            self?.confirmResetReferenceData()
        })

        // Cancel action
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    private func confirmClearFavorites() {
        let alert = UIAlertController(
            title: "⚠️ 確認重置",
            message: "確定要重置「我的」收藏數據嗎？\n\n所有自訂路線將被刪除，並恢復為參考文件中的預設路線（14條路線）。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { [weak self] _ in
            self?.executeClearFavorites()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func executeClearFavorites() {
        DeveloperToolsManager.shared.clearAllFavorites { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    let defaultCount = BusRouteConfiguration.defaultRoutes.count
                    let alert = UIAlertController(
                        title: "✅ 重置成功",
                        message: "已刪除 \(count) 個自訂路線\n已恢復 \(defaultCount) 個預設路線",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                    self?.present(alert, animated: true)

                case .failure(let error):
                    let alert = UIAlertController(
                        title: "❌ 重置失敗",
                        message: "錯誤：\(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    private func confirmClearAllFavoritesOnly() {
        let alert = UIAlertController(
            title: "⚠️ 確認清空",
            message: "確定要清空所有「我的」收藏嗎？\n\n所有收藏路線將被完全刪除，不會恢復預設路線。\n\n此操作用於測試空白頁面。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            self?.executeClearAllFavoritesOnly()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func executeClearAllFavoritesOnly() {
        DeveloperToolsManager.shared.clearAllFavoritesOnly { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    let alert = UIAlertController(
                        title: "✅ 清空成功",
                        message: "已刪除 \(count) 個收藏路線\n「我的」頁面現在是空白的",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                    self?.present(alert, animated: true)

                case .failure(let error):
                    let alert = UIAlertController(
                        title: "❌ 清空失敗",
                        message: "錯誤：\(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }

    private func confirmResetReferenceData() {
        let alert = UIAlertController(
            title: "🔄 重置參考數據",
            message: "將重新下載 hk-bus-crawling 的最新數據。\n此操作可能需要一些時間。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "開始重置", style: .default) { [weak self] _ in
            self?.executeResetReferenceData()
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func executeResetReferenceData() {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "重置中", message: "正在下載最新參考數據...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        DeveloperToolsManager.shared.resetReferenceBusData { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let message):
                        let alert = UIAlertController(
                            title: "✅ 重置成功",
                            message: message,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "確定", style: .default))
                        self?.present(alert, animated: true)

                    case .failure(let error):
                        let alert = UIAlertController(
                            title: "❌ 重置失敗",
                            message: "錯誤：\(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "確定", style: .default))
                        self?.present(alert, animated: true)
                    }
                }
            }
        }
    }

    private func showToast(message: String) {
        let toast = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(toast, animated: true)

        // Auto dismiss after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            toast.dismiss(animated: true)
        }
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }

        switch sectionType {
        case .dataManagement:
            return 1 // Update route data
        case .displaySettings:
            return 1 // Font size
        case .about:
            return 1 // App version
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch sectionType {
        case .dataManagement:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
            cell.textLabel?.text = "更新路線資料"
            cell.textLabel?.textColor = UIColor.systemBlue
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell

        case .displaySettings:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentedControlCell", for: indexPath) as? SegmentedControlCell else {
                return UITableViewCell()
            }
            cell.configure(title: "字體大細", segments: ["普通", "加大"], selectedIndex: FontSizeManager.shared.isLargeFontEnabled ? 1 : 0)
            cell.segmentedControl.addTarget(self, action: #selector(fontSizeChanged(_:)), for: .valueChanged)
            cell.selectionStyle = .none
            return cell

        case .about:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
            cell.textLabel?.text = "App 版本"
            cell.detailTextLabel?.text = DeveloperToolsManager.shared.getAppVersion()
            cell.selectionStyle = .none

            // Add tap gesture for developer mode (left 50px area)
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(versionAreaTapped))
            let tapArea = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
            tapArea.backgroundColor = .clear
            tapArea.addGestureRecognizer(tapGesture)
            cell.contentView.addSubview(tapArea)

            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let sectionType = Section(rawValue: indexPath.section) else { return }

        switch sectionType {
        case .dataManagement:
            updateRouteData()
        case .displaySettings:
            break // Handled by segmented control
        case .about:
            break // Version info, no action
        }
    }
}

// MARK: - Custom Cell for Segmented Control

class SegmentedControlCell: UITableViewCell {

    let titleLabel = UILabel()
    let segmentedControl = UISegmentedControl()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            segmentedControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            segmentedControl.widthAnchor.constraint(equalToConstant: 150)
        ])
    }

    func configure(title: String, segments: [String], selectedIndex: Int) {
        titleLabel.text = title

        segmentedControl.removeAllSegments()
        for (index, segment) in segments.enumerated() {
            segmentedControl.insertSegment(withTitle: segment, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = selectedIndex
    }
}
