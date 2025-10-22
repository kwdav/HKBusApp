import UIKit

class RouteStopTableViewCell: UITableViewCell {
    
    static let identifier = "RouteStopTableViewCell"
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let sequenceLabel = UILabel()
    private let stopNameLabel = UILabel()
    private let stopLineView = UIView()
    private let stopDotView = UIView()
    private let starImageView = UIImageView()
    private let starTouchAreaButton = UIButton(type: .custom)
    
    // ETA Components
    private let etaStackView = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // Data
    private var currentStop: BusStop?
    private var routeNumber: String?
    private var company: BusRoute.Company?
    private var direction: String?
    private var isShowingETA = false
    private var lastRefreshTime: Date?
    
    // Callback for favorite button
    var onFavoriteToggle: (() -> Void)?
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()

        // Listen for font size changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(fontSizeDidChange),
            name: FontSizeManager.fontSizeDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func fontSizeDidChange() {
        updateFonts()
    }

    private func updateFonts() {
        sequenceLabel.font = UIFont.appSmallText
        stopNameLabel.font = UIFont.appStopName
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        contentView.backgroundColor = UIColor.systemBackground
        selectionStyle = .none
        
        // Container view
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Sequence number
        sequenceLabel.font = UIFont.appSmallText
        sequenceLabel.textColor = UIColor.tertiaryLabel
        sequenceLabel.textAlignment = .center
        sequenceLabel.translatesAutoresizingMaskIntoConstraints = false

        // Stop name
        stopNameLabel.font = UIFont.appStopName
        stopNameLabel.textColor = UIColor.label
        stopNameLabel.numberOfLines = 2
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Route line visualization
        stopLineView.backgroundColor = UIColor.systemBlue
        stopLineView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop dot
        stopDotView.backgroundColor = UIColor.systemBlue
        stopDotView.layer.cornerRadius = 6
        stopDotView.translatesAutoresizingMaskIntoConstraints = false
        
        // Star (Favorite button)
        starImageView.image = UIImage(systemName: "star")
        starImageView.tintColor = UIColor.tertiaryLabel
        starImageView.translatesAutoresizingMaskIntoConstraints = false
        starImageView.isUserInteractionEnabled = false // Disable direct interaction
        
        // Star touch area button (larger touch zone)
        starTouchAreaButton.backgroundColor = UIColor.clear
        starTouchAreaButton.translatesAutoresizingMaskIntoConstraints = false
        starTouchAreaButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)
        
        // ETA Stack View
        etaStackView.axis = .vertical
        etaStackView.spacing = 2
        etaStackView.alignment = .trailing
        etaStackView.isHidden = true
        etaStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Loading indicator
        loadingIndicator.isHidden = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(sequenceLabel)
        containerView.addSubview(stopNameLabel)
        containerView.addSubview(stopLineView)
        containerView.addSubview(stopDotView)
        containerView.addSubview(starTouchAreaButton)
        starTouchAreaButton.addSubview(starImageView)
        containerView.addSubview(etaStackView)
        containerView.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            
            sequenceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            sequenceLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            sequenceLabel.widthAnchor.constraint(equalToConstant: 24),
            
            stopLineView.leadingAnchor.constraint(equalTo: sequenceLabel.trailingAnchor, constant: 4),
            stopLineView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stopLineView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stopLineView.widthAnchor.constraint(equalToConstant: 3),
            
            stopDotView.centerXAnchor.constraint(equalTo: stopLineView.centerXAnchor),
            stopDotView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stopDotView.widthAnchor.constraint(equalToConstant: 12),
            stopDotView.heightAnchor.constraint(equalToConstant: 12),
            
            stopNameLabel.leadingAnchor.constraint(equalTo: stopLineView.trailingAnchor, constant: 12),
            stopNameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stopNameLabel.trailingAnchor.constraint(equalTo: etaStackView.leadingAnchor, constant: -12),
            
            etaStackView.trailingAnchor.constraint(equalTo: starTouchAreaButton.leadingAnchor, constant: -8),
            etaStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            etaStackView.widthAnchor.constraint(equalToConstant: 140),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: etaStackView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: etaStackView.centerYAnchor),
            
            // Star touch area button (larger touch zone)
            starTouchAreaButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            starTouchAreaButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            starTouchAreaButton.widthAnchor.constraint(equalToConstant: 44),
            starTouchAreaButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Star image centered within touch area
            starImageView.centerXAnchor.constraint(equalTo: starTouchAreaButton.centerXAnchor),
            starImageView.centerYAnchor.constraint(equalTo: starTouchAreaButton.centerYAnchor),
            starImageView.widthAnchor.constraint(equalToConstant: 16),
            starImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with stop: BusStop, isFirst: Bool, isLast: Bool) {
        sequenceLabel.text = String(stop.sequence)
        stopNameLabel.text = stop.displayName
        currentStop = stop
        
        // Adjust line visualization for first and last stops
        if isFirst {
            stopLineView.backgroundColor = UIColor.systemGreen
            stopDotView.backgroundColor = UIColor.systemGreen
            stopLineView.layer.cornerRadius = 1.5
            stopLineView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        } else if isLast {
            stopLineView.backgroundColor = UIColor.systemRed
            stopDotView.backgroundColor = UIColor.systemRed
            stopLineView.layer.cornerRadius = 1.5
            stopLineView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        } else {
            stopLineView.backgroundColor = UIColor.systemBlue
            stopDotView.backgroundColor = UIColor.systemBlue
            stopLineView.layer.cornerRadius = 0
            stopLineView.layer.maskedCorners = []
        }
        
        // Reset ETA state
        hideETA()
        
        // Reset refresh time for cell reuse
        lastRefreshTime = nil
    }
    
    func setRouteInfo(routeNumber: String, company: BusRoute.Company, direction: String) {
        self.routeNumber = routeNumber
        self.company = company
        self.direction = direction
    }
    
    // MARK: - ETA Management
    func loadAndShowETA() {
        loadAndShowETA(forceRefresh: false)
    }
    
    func loadAndShowETA(forceRefresh: Bool = false) {
        guard let stop = currentStop,
              let routeNumber = routeNumber,
              let company = company,
              let direction = direction else { return }
        
        // Check cooldown period (5 seconds) unless it's force refresh or auto-refresh
        if !forceRefresh, let lastRefresh = lastRefreshTime {
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefresh)
            if timeSinceLastRefresh < 5.0 {
                let remainingTime = ceil(5.0 - timeSinceLastRefresh)
                print("🔄 ETA refresh on cooldown, \(remainingTime) seconds remaining - ignoring tap")
                return // Silently ignore the tap
            }
        }
        
        isShowingETA = true
        showLoadingETA()
        
        // Update last refresh time
        lastRefreshTime = Date()
        
        // Load ETA using API service
        BusAPIService.shared.fetchStopETA(
            stopId: stop.stopId,
            routeNumber: routeNumber,
            company: company,
            direction: direction
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingETA()
                
                switch result {
                case .success(let etas):
                    self?.displayETA(etas)
                case .failure(_):
                    self?.displayETAError()
                }
            }
        }
    }
    
    func hideETA() {
        isShowingETA = false
        etaStackView.isHidden = true
        loadingIndicator.isHidden = true
        clearETALabels()
    }
    
    private func showLoadingETA() {
        etaStackView.isHidden = true
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimating()
    }
    
    private func hideLoadingETA() {
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
    }
    
    
    private func displayETA(_ etas: [BusETA]) {
        etaStackView.isHidden = false
        clearETALabels()
        
        let etasToShow = Array(etas.prefix(3))
        
        if etasToShow.isEmpty {
            let noDataLabel = createETALabel(text: "未有資料", isFirst: true)
            etaStackView.addArrangedSubview(noDataLabel)
        } else {
            for (index, eta) in etasToShow.enumerated() {
                let etaLabel = createETALabel(text: eta.formattedETA, isFirst: index == 0)
                etaStackView.addArrangedSubview(etaLabel)
            }
        }
    }
    
    private func displayETAError() {
        etaStackView.isHidden = false
        clearETALabels()
        
        let errorLabel = createETALabel(text: "載入失敗", isFirst: true)
        etaStackView.addArrangedSubview(errorLabel)
    }
    
    private func createETALabel(text: String, isFirst: Bool) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .right
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.9

        if text == "未有資料" || text == "載入失敗" {
            label.font = UIFont.appETATime
            label.textColor = UIColor.gray
        } else if isFirst {
            label.font = UIFont.appETATime
            label.textColor = UIColor.systemTeal
        } else {
            label.font = UIFont.appSmallText
            label.textColor = UIColor.gray
        }

        return label
    }
    
    private func clearETALabels() {
        etaStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
    
    @objc private func favoriteButtonTapped() {
        onFavoriteToggle?()
    }
    
    func setFavoriteState(_ isFavorite: Bool) {
        if isFavorite {
            starImageView.image = UIImage(systemName: "star.fill")
            starImageView.tintColor = UIColor.systemYellow
        } else {
            starImageView.image = UIImage(systemName: "star")
            starImageView.tintColor = UIColor.tertiaryLabel
        }
    }
    
    // MARK: - Touch Handling
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.1) {
            self.containerView.backgroundColor = highlighted ? 
                UIColor.tertiarySystemBackground : UIColor.secondarySystemBackground
        }
    }
}