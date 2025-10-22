import UIKit

class BusETATableViewCell: UITableViewCell {
    
    static let identifier = "BusETATableViewCell"
    
    private let routeNumberLabel = UILabel()
    private let stopNameLabel = UILabel()
    private let destinationLabel = UILabel()
    private let distanceLabel = UILabel()
    private let etaStackView = UIStackView()
    private let containerView = UIView()
    private let separatorLine = UIView()
    private let starImageView = UIImageView()
    private let touchAreaButton = UIButton(type: .custom)

    // Constraints that need to be updated when star visibility changes
    private var etaTrailingToStarConstraint: NSLayoutConstraint?
    private var etaTrailingToContainerConstraint: NSLayoutConstraint?

    // Callback for favorite button
    var onFavoriteToggle: (() -> Void)?

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
        routeNumberLabel.font = UIFont.appBusNumber
        stopNameLabel.font = UIFont.appStopName
        destinationLabel.font = UIFont.appDestination
        distanceLabel.font = UIFont.appSmallText

        // Update ETA labels
        for view in etaStackView.arrangedSubviews {
            if let label = view as? UILabel {
                // Recreate labels with new fonts
                label.font = UIFont.appETATime
            }
        }
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = UIColor.systemBackground
        contentView.backgroundColor = UIColor.systemBackground
        
        // Container view with adaptive background
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Route number label - optimized for readability and impact
        routeNumberLabel.font = UIFont.appBusNumber
        routeNumberLabel.textColor = UIColor.label
        routeNumberLabel.textAlignment = .left
        routeNumberLabel.backgroundColor = UIColor.clear
        routeNumberLabel.adjustsFontSizeToFitWidth = true
        routeNumberLabel.minimumScaleFactor = 0.8
        routeNumberLabel.translatesAutoresizingMaskIntoConstraints = false

        // Stop name label - enhanced for better readability
        stopNameLabel.font = UIFont.appStopName
        stopNameLabel.textColor = UIColor.label
        stopNameLabel.numberOfLines = 1
        stopNameLabel.adjustsFontSizeToFitWidth = true
        stopNameLabel.minimumScaleFactor = 0.9
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Destination label - improved contrast and readability
        destinationLabel.font = UIFont.appDestination
        destinationLabel.textColor = UIColor.secondaryLabel
        destinationLabel.numberOfLines = 1
        destinationLabel.adjustsFontSizeToFitWidth = true
        destinationLabel.minimumScaleFactor = 0.85
        destinationLabel.translatesAutoresizingMaskIntoConstraints = false

        // Distance label - small gray text for distance info
        distanceLabel.font = UIFont.appSmallText
        distanceLabel.textColor = UIColor.tertiaryLabel
        distanceLabel.numberOfLines = 1
        distanceLabel.adjustsFontSizeToFitWidth = true
        distanceLabel.minimumScaleFactor = 0.85
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // ETA stack view
        etaStackView.axis = .vertical
        etaStackView.spacing = 2
        etaStackView.alignment = .trailing
        etaStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Route info stack view
        let routeInfoStackView = UIStackView()
        routeInfoStackView.axis = .vertical
        routeInfoStackView.spacing = 2
        routeInfoStackView.alignment = .leading
        routeInfoStackView.addArrangedSubview(stopNameLabel)
        routeInfoStackView.addArrangedSubview(destinationLabel)
        routeInfoStackView.addArrangedSubview(distanceLabel)
        routeInfoStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Separator line
        separatorLine.backgroundColor = UIColor.systemGray6
        separatorLine.translatesAutoresizingMaskIntoConstraints = false

        // Star (Favorite button) - wrapped in a larger touch area
        starImageView.image = UIImage(systemName: "star")
        starImageView.tintColor = UIColor.tertiaryLabel
        starImageView.translatesAutoresizingMaskIntoConstraints = false
        starImageView.isUserInteractionEnabled = true
        starImageView.contentMode = .center

        // Setup the larger touch area
        touchAreaButton.backgroundColor = UIColor.clear
        touchAreaButton.translatesAutoresizingMaskIntoConstraints = false
        touchAreaButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)

        // Add the button as the touch area, with star image on top
        containerView.addSubview(touchAreaButton)
        touchAreaButton.addSubview(starImageView)

        containerView.addSubview(routeNumberLabel)
        containerView.addSubview(routeInfoStackView)
        containerView.addSubview(etaStackView)
        contentView.addSubview(separatorLine)

        // Create two alternative constraints for ETA trailing anchor
        etaTrailingToStarConstraint = etaStackView.trailingAnchor.constraint(equalTo: touchAreaButton.leadingAnchor, constant: -8)
        etaTrailingToContainerConstraint = etaStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)

        NSLayoutConstraint.activate([
            // Container with minimal margins
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 1),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),

            // Route number - 110px width like HTML
            routeNumberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            routeNumberLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            routeNumberLabel.widthAnchor.constraint(equalToConstant: 110),

            // Route info - flexible width
            routeInfoStackView.leadingAnchor.constraint(equalTo: routeNumberLabel.trailingAnchor, constant: 8),
            routeInfoStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            routeInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: etaStackView.leadingAnchor, constant: -8),

            // ETA - center and width (trailing will be set dynamically)
            etaStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            etaStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Touch area button (larger touch zone)
            touchAreaButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            touchAreaButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            touchAreaButton.widthAnchor.constraint(equalToConstant: 44),
            touchAreaButton.heightAnchor.constraint(equalToConstant: 44),

            // Star image centered within touch area
            starImageView.centerXAnchor.constraint(equalTo: touchAreaButton.centerXAnchor),
            starImageView.centerYAnchor.constraint(equalTo: touchAreaButton.centerYAnchor),
            starImageView.widthAnchor.constraint(equalToConstant: 20),
            starImageView.heightAnchor.constraint(equalToConstant: 20),

            // Separator line
            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1)
        ])

        // By default, activate the constraint that leaves space for star
        etaTrailingToStarConstraint?.isActive = true
    }
    
    func configure(with displayData: BusDisplayData) {
        routeNumberLabel.text = displayData.route.route
        
        // Extract distance from stop name and clean the stop name
        let cleanStopInfo = extractStopNameAndDistance(from: displayData.stopName)
        stopNameLabel.text = cleanStopInfo.stopName.isEmpty ? "載入中..." : cleanStopInfo.stopName
        distanceLabel.text = cleanStopInfo.distance
        
        destinationLabel.text = displayData.destination.isEmpty ? "" : displayData.destination
        
        // Add colored left border based on company like HTML version
        
        // Remove existing border layers from contentView
        contentView.layer.sublayers?.removeAll(where: { $0.name == "companyBorder" })
        
        let borderLayer = CALayer()
        borderLayer.name = "companyBorder"
        // Center vertically in the 82px cell height
        let cellHeight: CGFloat = 82
        let dotSize: CGFloat = 5
        let yPosition = (cellHeight - dotSize) / 2
        borderLayer.frame = CGRect(x: 0, y: yPosition, width: dotSize, height: dotSize)
        borderLayer.cornerRadius = 1 // Slightly rounded corners
        
        switch displayData.route.company {
        case .CTB:
            borderLayer.backgroundColor = UIColor(red: 0.9, green: 0.8, blue: 0.0, alpha: 1.0).cgColor // Yellow for CTB
        case .KMB:
            borderLayer.backgroundColor = UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0).cgColor // Red for KMB
        case .NWFB:
            borderLayer.backgroundColor = UIColor.systemOrange.cgColor // Orange for NWFB
        }
        
        contentView.layer.addSublayer(borderLayer)
        
        // Clear previous ETAs
        etaStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add ETA labels
        let etasToShow = Array(displayData.etas.prefix(3))
        
        if etasToShow.isEmpty {
            let noDataLabel = createNoDataLabel(isLoading: displayData.isLoadingETAs)
            etaStackView.addArrangedSubview(noDataLabel)
        } else {
            for (index, eta) in etasToShow.enumerated() {
                let etaLabel = createETALabel(text: eta.formattedETA, isFirst: index == 0)
                etaStackView.addArrangedSubview(etaLabel)
            }
        }
    }
    
    private func createETALabel(text: String, isFirst: Bool) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .right
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.9

        // Check if it's "未有資料" and use gray color
        if text == "未有資料" {
            label.font = UIFont.appETATime
            label.textColor = UIColor.gray
        } else if isFirst {
            // First ETA - larger, with dynamic color support
            label.font = UIFont.appETATime
            label.textColor = UIColor.systemTeal
        } else {
            // Other ETAs - refined styling with better contrast
            label.font = UIFont.appSmallText
            label.textColor = UIColor.gray
        }

        return label
    }

    private func createNoDataLabel(isLoading: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = isLoading ? "..." : "未有資料"
        label.textAlignment = .right
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.9
        label.font = UIFont.appETATime
        label.textColor = UIColor.gray // Use gray instead of teal/blue

        return label
    }
    
    private func extractStopNameAndDistance(from stopNameWithDistance: String) -> (stopName: String, distance: String) {
        // Pattern to match distance info like "(100米)" or "(1.2公里)"
        let pattern = #"\s*\((\d+(?:\.\d+)?)(米|公里)\)$"#
        
        if let range = stopNameWithDistance.range(of: pattern, options: .regularExpression) {
            let stopName = String(stopNameWithDistance[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let distanceText = String(stopNameWithDistance[range])
            
            // Clean up the distance text (remove parentheses)
            let cleanDistance = distanceText.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            
            return (stopName: stopName, distance: cleanDistance)
        }
        
        // If no distance pattern found, return original text with empty distance
        return (stopName: stopNameWithDistance, distance: "")
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

    func setStarButtonVisible(_ visible: Bool) {
        starImageView.isHidden = !visible
        touchAreaButton.isHidden = !visible

        // Switch constraints based on star visibility
        if visible {
            // Star is visible - ETA should end before star button
            etaTrailingToContainerConstraint?.isActive = false
            etaTrailingToStarConstraint?.isActive = true
        } else {
            // Star is hidden - ETA can extend to container edge
            etaTrailingToStarConstraint?.isActive = false
            etaTrailingToContainerConstraint?.isActive = true
        }
    }
}