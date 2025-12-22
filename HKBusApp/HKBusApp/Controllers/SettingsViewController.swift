import UIKit

class SettingsViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let tapDetector = DeveloperToolsManager.TapDetector()
    private var hasNewVersionAvailable: Bool = false
    private var lastUpdateStatus: String = "檢查中..."

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
        setupNotifications()
        checkDataVersion()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNotifications() {
        // 監聽新版本可用通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewVersionAvailable),
            name: NSNotification.Name("NewVersionAvailable"),
            object: nil
        )
    }

    @objc private func handleNewVersionAvailable() {
        hasNewVersionAvailable = true
        tableView.reloadData()
    }

    private func checkDataVersion() {
        let localVersion = UserDefaults.standard.double(forKey: "com.hkbusapp.localBusDataVersion")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if localVersion > 0 {
            // Downloaded version
            let date = Date(timeIntervalSince1970: localVersion)
            lastUpdateStatus = "數據版本: \(formatter.string(from: date))"
        } else {
            // Bundle version - get from bus_data.json metadata
            if let bundleVersion = getBundleDataVersion() {
                let date = Date(timeIntervalSince1970: bundleVersion)
                lastUpdateStatus = "數據版本: \(formatter.string(from: date))"
            } else {
                lastUpdateStatus = "數據版本: 未知"
            }
        }
    }

    private func getBundleDataVersion() -> TimeInterval? {
        guard let bundleURL = Bundle.main.url(forResource: "bus_data", withExtension: "json"),
              let data = try? Data(contentsOf: bundleURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metadata = json["metadata"] as? [String: Any],
              let version = metadata["version"] as? TimeInterval else {
            return nil
        }
        return version
    }

    private func setupUI() {
        title = "設定"
        view.backgroundColor = UIColor.systemGroupedBackground

        // Show navigation bar with back button
        navigationController?.setNavigationBarHidden(false, animated: false)

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
        // Use .value1 style to show detail text on the right
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.register(SegmentedControlCell.self, forCellReuseIdentifier: "SegmentedControlCell")
    }

    // MARK: - Actions

    @objc private func updateRouteData() {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "檢查更新", message: "正在檢查是否有新版本...", preferredStyle: .alert)
        present(loadingAlert, animated: true)

        // First check if update is needed (downloads small metadata file only)
        FirebaseDataManager.shared.checkForUpdates(forceCheck: true) { [weak self] result in
            switch result {
            case .success(let hasUpdate):
                if hasUpdate {
                    // Update available, proceed with download
                    DispatchQueue.main.async {
                        loadingAlert.message = "正在下載最新巴士數據..."
                    }
                    self?.performDataDownload(loadingAlert: loadingAlert)
                } else {
                    // Already up to date
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            self?.showToast(message: "已是最新版本")
                        }
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        let alert = UIAlertController(
                            title: "檢查失敗",
                            message: "無法檢查更新，請檢查網路連線並稍後再試",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "確定", style: .default))
                        self?.present(alert, animated: true)
                    }
                }
            }
        }
    }

    private func performDataDownload(loadingAlert: UIAlertController) {
        // Download Firebase bus data (large file)
        FirebaseDataManager.shared.downloadBusData(
            progressHandler: { progress in
                DispatchQueue.main.async {
                    loadingAlert.message = "下載進度: \(Int(progress * 100))%"
                }
            },
            completion: { [weak self] result in
                switch result {
                case .success(let tempURL):
                    // Install downloaded data
                    FirebaseDataManager.shared.installDownloadedData(from: tempURL) { installResult in
                        DispatchQueue.main.async {
                            loadingAlert.dismiss(animated: true) {
                                switch installResult {
                                case .success:
                                    // Hide the update hint
                                    self?.hasNewVersionAvailable = false
                                    self?.checkDataVersion()
                                    self?.tableView.reloadData()

                                    // Show toast message instead of alert
                                    self?.showToast(message: "巴士數據已更新至最新版本")

                                case .failure:
                                    let alert = UIAlertController(
                                        title: "更新失敗",
                                        message: "無法安裝巴士數據，請稍後再試",
                                        preferredStyle: .alert
                                    )
                                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                                    self?.present(alert, animated: true)
                                }
                            }
                        }
                    }

                case .failure:
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            let alert = UIAlertController(
                                title: "更新失敗",
                                message: "無法下載巴士數據，請檢查網路連線並稍後再試",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "確定", style: .default))
                            self?.present(alert, animated: true)
                        }
                    }
                }
            }
        )
    }

    @objc private func appearanceChanged(_ sender: UISegmentedControl) {
        guard let mode = AppearanceManager.AppearanceMode(rawValue: sender.selectedSegmentIndex) else { return }
        AppearanceManager.shared.currentMode = mode

        // Show confirmation
        showToast(message: "已切換至\(mode.displayName)模式")
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

    private func showToast(message: String) {
        // Create toast container
        let toastView = UIView()

        // Determine background color based on AppearanceManager setting
        // This ensures correct color even during appearance transitions
        let isDarkMode: Bool
        let currentMode = AppearanceManager.shared.currentMode

        if currentMode == .automatic {
            // In automatic mode, use system's actual appearance (not overridden traitCollection)
            // UIScreen.main.traitCollection reflects the true system appearance
            isDarkMode = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        } else {
            // Use explicit appearance setting
            isDarkMode = currentMode == .dark
        }

        // Dark mode: solid black, Light mode: solid white
        toastView.backgroundColor = isDarkMode ? UIColor.black : UIColor.white
        toastView.layer.cornerRadius = 12
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.alpha = 0

        // Create message label
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = UIColor.label  // Auto-adapts: white in dark mode, black in light mode
        messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        toastView.addSubview(messageLabel)
        view.addSubview(toastView)

        // Layout constraints
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -12),
            messageLabel.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16),

            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])

        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            toastView.alpha = 1.0
        } completion: { _ in
            // Auto dismiss after 1.5 seconds
            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseIn) {
                toastView.alpha = 0
            } completion: { _ in
                toastView.removeFromSuperview()
            }
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
            // Data version info + Update route data + (optional: update hint)
            return hasNewVersionAvailable ? 3 : 2
        case .displaySettings:
            return 2 // Appearance + Font size
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
            if indexPath.row == 0 {
                // Data version info row
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.textLabel?.text = "巴士數據"
                cell.textLabel?.textColor = UIColor.label
                cell.detailTextLabel?.text = lastUpdateStatus
                cell.detailTextLabel?.textColor = UIColor.secondaryLabel
                cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 15)
                cell.accessoryType = .none
                cell.selectionStyle = .none
                return cell
            } else if indexPath.row == 1 {
                // Update route data button
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
                cell.textLabel?.text = "更新路線資料"
                cell.textLabel?.textColor = UIColor.systemBlue
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                return cell
            } else {
                // New version hint (row 2, only shows when hasNewVersionAvailable)
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = "🆕 有新版本巴士數據可供更新"
                cell.textLabel?.textColor = UIColor.systemOrange
                cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
                cell.textLabel?.numberOfLines = 0
                cell.accessoryType = .none
                cell.selectionStyle = .none
                cell.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
                return cell
            }

        case .displaySettings:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SegmentedControlCell", for: indexPath) as? SegmentedControlCell else {
                return UITableViewCell()
            }

            if indexPath.row == 0 {
                // Appearance setting
                cell.configure(title: "外觀", segments: ["自動", "淺色", "深色"], selectedIndex: AppearanceManager.shared.currentMode.rawValue)
                cell.segmentedControl.addTarget(self, action: #selector(appearanceChanged(_:)), for: .valueChanged)
            } else {
                // Font size setting
                cell.configure(title: "字體大細", segments: ["普通", "加大"], selectedIndex: FontSizeManager.shared.isLargeFontEnabled ? 1 : 0)
                cell.segmentedControl.addTarget(self, action: #selector(fontSizeChanged(_:)), for: .valueChanged)
            }

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
            // Only row 1 is tappable (Update route data)
            if indexPath.row == 1 {
                updateRouteData()
            }
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
