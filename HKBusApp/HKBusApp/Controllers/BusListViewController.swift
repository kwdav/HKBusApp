import UIKit
import QuartzCore

class BusListViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private var busDisplayData: [BusDisplayData] = []
    private var groupedData: [(subtitle: String, routes: [BusDisplayData])] = []
    private var refreshTimer: Timer?
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    private let editButton = UIButton(type: .system)
    private let updateButton = UIButton(type: .system)
    private var headerView: UIView?
    private let emptyStateView = UIView()

    // MARK: - Floating Refresh Button
    private let floatingRefreshButton = UIButton(type: .system)
    private var floatingButtonContainer: UIVisualEffectView!
    private let floatingButtonLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private var lastManualRefreshTime: Date?
    private let refreshCooldown: TimeInterval = 5.0
    private var floatingButtonWidthConstraint: NSLayoutConstraint?
    private var isFloatingButtonAnimating = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        // Ensure content extends under translucent bars
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        setupUI()
        setupTableView()
        setupRefreshControl()
        setupEmptyStateView()
        setupEditButton()
        setupFloatingRefreshButton()
        layoutFloatingRefreshButton()
        loadData()
        startAutoRefresh()

        // Listen for font size changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fontSizeDidChange),
            name: FontSizeManager.fontSizeDidChangeNotification,
            object: nil
        )

        // Listen for favorites changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(favoritesDidChange),
            name: FavoritesManager.favoritesDidChangeNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Always hide navigation bar when returning to this view
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    @objc private func fontSizeDidChange() {
        // Reload table view to apply new font sizes
        tableView.reloadData()

        // Update floating button font size
        updateFloatingButtonFont()
    }

    private func updateFloatingButtonFont() {
        var config = floatingRefreshButton.configuration
        config?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            // Use FontSizeManager to get adjusted font size (16pt normal, 18pt large)
            let fontSize: CGFloat = FontSizeManager.shared.isLargeFontEnabled ? 18 : 16
            outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            return outgoing
        }
        floatingRefreshButton.configuration = config
    }

    @objc private func favoritesDidChange() {
        // Reload data when favorites are added or removed from other pages
        loadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Don't set scroll indicator insets - let it follow content insets
        // The scroll indicator will automatically align with the scrollable content area
    }

    deinit {
        refreshTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        // Adaptive background for light/dark mode
        view.backgroundColor = UIColor.systemBackground
        
        // Setup table view to go under status bar and tab bar
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Table view should fill entire screen to go under translucent bars
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Get status bar height first
        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 44

        // Create fixed header view with blur background for buttons
        let buttonTopPadding: CGFloat = 8
        let buttonHeight: CGFloat = 28
        let buttonBottomPadding: CGFloat = 8
        let buttonAreaHeight = buttonTopPadding + buttonHeight + buttonBottomPadding
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        self.headerView = header  // Store reference for later use

        // Add blur effect to header view
        let headerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        headerBlurView.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerBlurView)

        // Setup settings button in header (left side)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let gearImage = UIImage(systemName: "gearshape.fill", withConfiguration: config)
        updateButton.setImage(gearImage, for: .normal)
        updateButton.tintColor = UIColor.label
        updateButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        updateButton.translatesAutoresizingMaskIntoConstraints = false
        headerBlurView.contentView.addSubview(updateButton)

        // Setup edit button in header (right side)
        editButton.setTitle("編輯", for: .normal)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        editButton.setTitleColor(UIColor.label, for: .normal)
        editButton.addTarget(self, action: #selector(toggleEditMode), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        headerBlurView.contentView.addSubview(editButton)

        NSLayoutConstraint.activate([
            // Fix header view to top of screen
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: statusBarHeight + buttonAreaHeight),

            // Blur view extends beyond header view to cover section headers
            headerBlurView.topAnchor.constraint(equalTo: header.topAnchor),
            headerBlurView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            headerBlurView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            headerBlurView.bottomAnchor.constraint(equalTo: header.bottomAnchor),

            // Position buttons below status bar with top padding
            updateButton.topAnchor.constraint(equalTo: header.topAnchor, constant: statusBarHeight + buttonTopPadding),
            updateButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),

            editButton.topAnchor.constraint(equalTo: header.topAnchor, constant: statusBarHeight + buttonTopPadding),
            editButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        // Disable automatic content inset adjustment to have full control
        tableView.contentInsetAdjustmentBehavior = .never

        // Remove default spacing above section headers (iOS 15+)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        // Add top and bottom content inset to avoid header and tab bar covering content
        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 44
        let buttonTopPadding: CGFloat = 8
        let buttonHeight: CGFloat = 28
        let buttonBottomPadding: CGFloat = 8
        let buttonAreaHeight = buttonTopPadding + buttonHeight + buttonBottomPadding
        let totalHeaderHeight = statusBarHeight + buttonAreaHeight

        // Get tab bar height to add bottom inset
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 49

        // Add extra 80px padding to avoid floating button covering last item
        let floatingButtonPadding: CGFloat = 80

        tableView.contentInset = UIEdgeInsets(top: totalHeaderHeight, left: 0, bottom: tabBarHeight + floatingButtonPadding, right: 0)
        // Scroll indicator should have NO insets because content is already offset
        // The scrollable range is defined by contentInset, not scrollIndicatorInsets
        tableView.scrollIndicatorInsets = .zero
        tableView.verticalScrollIndicatorInsets = .zero
        tableView.showsVerticalScrollIndicator = true
        tableView.register(BusETATableViewCell.self, forCellReuseIdentifier: BusETATableViewCell.identifier)
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        refreshControl.tintColor = UIColor.label
        refreshControl.attributedTitle = NSAttributedString(
            string: "更新路線",
            attributes: [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14)]
        )
        tableView.refreshControl = refreshControl

        // Ensure refresh control appears above table view content
        tableView.bringSubviewToFront(refreshControl)
    }

    private func setupEmptyStateView() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.backgroundColor = UIColor.systemBackground
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        // Add scroll view for small screens
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true // Enable pull-to-refresh even when content fits
        emptyStateView.addSubview(scrollView)

        // Container view to hold image and labels
        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentContainer)

        // Empty state image
        let imageView = UIImageView()
        if let emptyImage = UIImage(named: "empty") {
            imageView.image = emptyImage
        }
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(imageView)

        // Main title label - darker color for better readability
        let titleLabel = UILabel()
        titleLabel.text = "未有收藏路線"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = UIColor.label // Changed from secondaryLabel to label for darker color
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(titleLabel)

        // Subtitle label - darker color for better readability
        let subtitleLabel = UILabel()
        subtitleLabel.text = "前往路線或站點頁面，點擊星號按鈕即可加入收藏"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor.secondaryLabel // Changed from tertiaryLabel to secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(subtitleLabel)

        // Get header and tab bar heights
        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 44
        let buttonAreaHeight: CGFloat = 44
        let headerHeight = statusBarHeight + buttonAreaHeight
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 49

        NSLayoutConstraint.activate([
            // Empty state view fills the screen
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Scroll view fills empty state view with proper insets
            scrollView.topAnchor.constraint(equalTo: emptyStateView.topAnchor, constant: headerHeight),
            scrollView.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor, constant: -tabBarHeight),

            // Content container inside scroll view
            contentContainer.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 40),
            contentContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 32),
            contentContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -32),
            contentContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            contentContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -64),

            // Image at top of container
            imageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 325),
            imageView.heightAnchor.constraint(equalToConstant: 225),

            // Title below image
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),

            // Subtitle below title and bottom of container
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])

        // Ensure empty state view is above table view but below header
        view.bringSubviewToFront(emptyStateView)
        if let header = headerView {
            view.bringSubviewToFront(header)
        }
    }

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
        view.addSubview(shadowView)

        // 2. Create blur effect container
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        floatingButtonContainer = UIVisualEffectView(effect: blurEffect)
        floatingButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        floatingButtonContainer.layer.cornerRadius = 24
        floatingButtonContainer.clipsToBounds = true
        shadowView.addSubview(floatingButtonContainer)

        // 3. Create vibrancy effect for enhanced glass effect
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        floatingButtonContainer.contentView.addSubview(vibrancyView)

        // 4. Configure button (iOS 15+ UIButton.Configuration)
        var config = UIButton.Configuration.plain()
        config.title = "重新整理"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        config.baseForegroundColor = UIColor.label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            // Use FontSizeManager for dynamic font sizing (16pt normal, 18pt large)
            let fontSize: CGFloat = FontSizeManager.shared.isLargeFontEnabled ? 18 : 16
            outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            return outgoing
        }

        floatingRefreshButton.configuration = config
        floatingRefreshButton.translatesAutoresizingMaskIntoConstraints = false
        floatingRefreshButton.addTarget(self, action: #selector(floatingRefreshButtonTapped), for: .touchUpInside)

        // 5. Configure loading indicator
        floatingButtonLoadingIndicator.hidesWhenStopped = true
        floatingButtonLoadingIndicator.color = UIColor.label
        floatingButtonLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false

        // 6. Add button and indicator to vibrancy view
        vibrancyView.contentView.addSubview(floatingRefreshButton)
        vibrancyView.contentView.addSubview(floatingButtonLoadingIndicator)

        // 7. Set up constraints for vibrancy view to fill container
        NSLayoutConstraint.activate([
            vibrancyView.topAnchor.constraint(equalTo: floatingButtonContainer.contentView.topAnchor),
            vibrancyView.leadingAnchor.constraint(equalTo: floatingButtonContainer.contentView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: floatingButtonContainer.contentView.trailingAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: floatingButtonContainer.contentView.bottomAnchor)
        ])

        // 8. Initially hide the button
        shadowView.isHidden = true
        shadowView.alpha = 0.95

        // Store shadowView reference for show/hide methods
        floatingButtonContainer.tag = 999  // Use tag to identify shadow view later
        shadowView.tag = 998
    }

    private func layoutFloatingRefreshButton() {
        guard let shadowView = view.viewWithTag(998),
              let container = view.viewWithTag(999) as? UIVisualEffectView else {
            return
        }

        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 49

        // Create width constraint and save reference for animation
        let widthConstraint = shadowView.widthAnchor.constraint(equalToConstant: 160)
        floatingButtonWidthConstraint = widthConstraint

        NSLayoutConstraint.activate([
            // Shadow view (parent container) constraints
            shadowView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadowView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -(tabBarHeight + 16)
            ),
            widthConstraint,
            shadowView.heightAnchor.constraint(equalToConstant: 48),

            // Floating button container fills shadow view
            container.topAnchor.constraint(equalTo: shadowView.topAnchor),
            container.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),

            // Button fills its parent (vibrancy view)
            floatingRefreshButton.topAnchor.constraint(equalTo: floatingRefreshButton.superview!.topAnchor),
            floatingRefreshButton.leadingAnchor.constraint(equalTo: floatingRefreshButton.superview!.leadingAnchor),
            floatingRefreshButton.trailingAnchor.constraint(equalTo: floatingRefreshButton.superview!.trailingAnchor),
            floatingRefreshButton.bottomAnchor.constraint(equalTo: floatingRefreshButton.superview!.bottomAnchor),

            // Loading indicator centered in container
            floatingButtonLoadingIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            floatingButtonLoadingIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        // Ensure correct z-index (below header, above empty state and table view)
        if let shadowView = view.viewWithTag(998) {
            view.bringSubviewToFront(shadowView)
        }
        if let header = headerView {
            view.bringSubviewToFront(header)
        }
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
            hideFloatingButton(animated: true)  // Hide floating button in edit mode
        } else {
            hideAddSectionButton()
            startAutoRefresh()
            // Show floating button only if not empty
            if !groupedData.isEmpty {
                showFloatingButton(animated: true)
            }
        }

        // Reload sections to show/hide edit buttons
        tableView.reloadData()
    }
    
    private func showAddSectionButton() {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))
        footerView.backgroundColor = UIColor.clear
        
        let addButton = UIButton(type: .system)
        addButton.setTitle("+ 新增分類", for: .normal)
        addButton.setTitleColor(UIColor.label, for: .normal)
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

    // MARK: - Floating Refresh Button Actions

    @objc private func floatingRefreshButtonTapped() {
        // Check if already animating
        guard !isFloatingButtonAnimating else {
            print("⏱️ 正在更新中，請稍後")
            return
        }

        // Check cooldown
        guard canPerformManualRefresh() else {
            print("⏱️ 更新太頻繁，請稍後再試")
            return
        }

        // Mark as animating
        isFloatingButtonAnimating = true

        // Animate to circle and show loading
        animateButtonToCircle {
            // Trigger refresh after animation
            self.loadData()
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

        // 1. Shrink to circle (48x48)
        widthConstraint.constant = 48

        // 2. Hide text and icon
        var config = floatingRefreshButton.configuration
        config?.title = ""
        config?.image = nil
        floatingRefreshButton.configuration = config

        // 3. Start loading indicator
        floatingButtonLoadingIndicator.startAnimating()

        // 4. Animate the shrink
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
                // Trigger data loading
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

        // 2. Restore text and icon with dynamic font size
        var config = floatingRefreshButton.configuration
        config?.title = "重新整理"
        config?.image = UIImage(systemName: "arrow.clockwise")
        config?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            // Use FontSizeManager for dynamic font sizing (16pt normal, 18pt large)
            let fontSize: CGFloat = FontSizeManager.shared.isLargeFontEnabled ? 18 : 16
            outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            return outgoing
        }
        floatingRefreshButton.configuration = config

        // 3. Expand to normal width (160px)
        widthConstraint.constant = 160

        // 4. Animate the expand
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut],
            animations: {
                self.view.layoutIfNeeded()
            },
            completion: nil
        )
    }

    private func canPerformManualRefresh() -> Bool {
        guard let lastRefresh = lastManualRefreshTime else {
            return true // First time
        }

        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceLastRefresh >= refreshCooldown
    }


    private func showFloatingButton(animated: Bool) {
        guard let shadowView = view.viewWithTag(998) else { return }
        guard shadowView.isHidden else { return }

        if animated {
            shadowView.isHidden = false
            shadowView.alpha = 0
            shadowView.transform = CGAffineTransform(translationX: 0, y: 20)

            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut],
                animations: {
                    shadowView.alpha = 0.95
                    shadowView.transform = .identity
                },
                completion: nil
            )
        } else {
            shadowView.isHidden = false
            shadowView.alpha = 0.95
        }
    }

    private func hideFloatingButton(animated: Bool) {
        guard let shadowView = view.viewWithTag(998) else { return }
        guard !shadowView.isHidden else { return }

        if animated {
            UIView.animate(
                withDuration: 0.2,
                delay: 0,
                options: [.curveEaseIn],
                animations: {
                    shadowView.alpha = 0
                    shadowView.transform = CGAffineTransform(translationX: 0, y: 20)
                },
                completion: { _ in
                    shadowView.isHidden = true
                    shadowView.transform = .identity
                }
            )
        } else {
            shadowView.isHidden = true
        }
    }

    @objc private func openSettings() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
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
            self.updateEmptyState()
            self.tableView.reloadData()
            self.refreshControl.endRefreshing()
            // Note: Button state is managed by animateButtonToNormal() after 2 seconds
        }
    }

    private func updateEmptyState() {
        let isEmpty = groupedData.isEmpty
        emptyStateView.isHidden = !isEmpty
        // Don't hide tableView - keep it visible for pull-to-refresh to work
        // tableView.isHidden = isEmpty
        editButton.isHidden = isEmpty

        // Handle floating button visibility
        // Hide when empty, show when has data (unless in edit mode)
        if isEmpty {
            hideFloatingButton(animated: false)
        } else if !tableView.isEditing {
            showFloatingButton(animated: false)
        }

        // Bring views to front in correct order
        if !isEmpty {
            view.bringSubviewToFront(emptyStateView)
            // Bring floating button above empty state
            if let shadowView = view.viewWithTag(998) {
                view.bringSubviewToFront(shadowView)
            }
            // Header always on top
            if let header = headerView {
                view.bringSubviewToFront(header)
            }
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

        // Hide star button in "My" page (all routes are already favorites)
        cell.setStarButtonVisible(false)

        return cell
    }
}

// MARK: - UITableViewDelegate
extension BusListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 82
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.secondarySystemBackground // Adaptive for light/dark mode

        // Add long press gesture for reordering sections
        if tableView.isEditing {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleSectionLongPress(_:)))
            headerView.addGestureRecognizer(longPress)
            headerView.tag = section
        }

        let label = UILabel()
        label.text = groupedData[section].subtitle
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle shadow for depth
        label.layer.shadowColor = UIColor.label.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowOpacity = 0.3
        label.layer.shadowRadius = 1
        
        headerView.addSubview(label)
        
        if tableView.isEditing {
            // Add edit and delete buttons in edit mode
            let editButton = UIButton(type: .system)
            editButton.setTitle("編輯", for: .normal)
            editButton.setTitleColor(UIColor.label, for: .normal)
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
        return tableView.isEditing
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
        // Get the item being moved
        let movedItem = groupedData[sourceIndexPath.section].routes[sourceIndexPath.row]

        // Remove from source section
        var sourceSectionData = groupedData[sourceIndexPath.section].routes
        sourceSectionData.remove(at: sourceIndexPath.row)
        groupedData[sourceIndexPath.section] = (
            subtitle: groupedData[sourceIndexPath.section].subtitle,
            routes: sourceSectionData
        )

        // If moved to different section, update the subtitle in Core Data and create new route object
        var itemToInsert = movedItem
        if sourceIndexPath.section != destinationIndexPath.section {
            let newSubTitle = groupedData[destinationIndexPath.section].subtitle
            favoritesManager.updateFavoriteSubTitle(movedItem.route, newSubTitle: newSubTitle)

            // Create a new BusRoute with updated subtitle (struct is immutable)
            let updatedRoute = BusRoute(
                stopId: movedItem.route.stopId,
                route: movedItem.route.route,
                companyId: movedItem.route.companyId,
                direction: movedItem.route.direction,
                subTitle: newSubTitle
            )

            // Create updated BusDisplayData with new route
            itemToInsert = BusDisplayData(
                route: updatedRoute,
                stopName: movedItem.stopName,
                destination: movedItem.destination,
                etas: movedItem.etas
            )
        }

        // Insert into destination section
        var destinationSectionData = groupedData[destinationIndexPath.section].routes
        destinationSectionData.insert(itemToInsert, at: destinationIndexPath.row)
        groupedData[destinationIndexPath.section] = (
            subtitle: groupedData[destinationIndexPath.section].subtitle,
            routes: destinationSectionData
        )

        // Save the new order for all routes
        let allRoutes = groupedData.flatMap { $0.routes.map { $0.route } }
        favoritesManager.updateFavoriteOrder(allRoutes)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // 編輯模式時不觸發導航
        guard !tableView.isEditing else { return }

        // 取得被點擊的路線資料
        let displayData = groupedData[indexPath.section].routes[indexPath.row]

        // 建立並導航到路線詳細頁面，傳入目標站點 ID
        let routeDetailVC = RouteDetailViewController(
            routeNumber: displayData.route.route,
            company: displayData.route.company,
            direction: displayData.route.direction,
            targetStopId: displayData.route.stopId
        )

        // Custom transition animation (same as SearchViewController and StopRoutesViewController)
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .moveIn
        transition.subtype = .fromRight
        navigationController?.view.layer.add(transition, forKey: kCATransition)

        navigationController?.pushViewController(routeDetailVC, animated: false)
    }
}
