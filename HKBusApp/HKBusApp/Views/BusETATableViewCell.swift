import UIKit

class BusETATableViewCell: UITableViewCell {
    
    static let identifier = "BusETATableViewCell"
    
    private let routeNumberLabel = UILabel()
    private let stopNameLabel = UILabel()
    private let destinationLabel = UILabel()
    private let etaStackView = UIStackView()
    private let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = UIColor.systemBackground
        contentView.backgroundColor = UIColor.systemBackground
        
        // Container view with subtle background for better visual separation
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Route number label - optimized for readability and impact
        routeNumberLabel.font = UIFont.monospacedSystemFont(ofSize: 28, weight: .heavy)
        routeNumberLabel.textColor = UIColor.label
        routeNumberLabel.textAlignment = .left
        routeNumberLabel.backgroundColor = UIColor.clear
        routeNumberLabel.adjustsFontSizeToFitWidth = true
        routeNumberLabel.minimumScaleFactor = 0.8
        routeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name label - enhanced for better readability
        stopNameLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        stopNameLabel.textColor = UIColor.label
        stopNameLabel.numberOfLines = 1
        stopNameLabel.adjustsFontSizeToFitWidth = true
        stopNameLabel.minimumScaleFactor = 0.9
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Destination label - improved contrast and readability
        destinationLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        destinationLabel.textColor = UIColor.secondaryLabel
        destinationLabel.numberOfLines = 1
        destinationLabel.adjustsFontSizeToFitWidth = true
        destinationLabel.minimumScaleFactor = 0.85
        destinationLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
        routeInfoStackView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(routeNumberLabel)
        containerView.addSubview(routeInfoStackView)
        containerView.addSubview(etaStackView)
        
        NSLayoutConstraint.activate([
            // Container with subtle margins for better visual separation
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Route number - 110px width like HTML
            routeNumberLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            routeNumberLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            routeNumberLabel.widthAnchor.constraint(equalToConstant: 110),
            
            // Route info - flexible width
            routeInfoStackView.leadingAnchor.constraint(equalTo: routeNumberLabel.trailingAnchor, constant: 8),
            routeInfoStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            routeInfoStackView.trailingAnchor.constraint(lessThanOrEqualTo: etaStackView.leadingAnchor, constant: -8),
            
            // ETA - 140px width like HTML
            etaStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            etaStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            etaStackView.widthAnchor.constraint(equalToConstant: 140)
        ])
    }
    
    func configure(with displayData: BusDisplayData) {
        routeNumberLabel.text = displayData.route.route
        stopNameLabel.text = displayData.stopName.isEmpty ? "載入中..." : displayData.stopName
        destinationLabel.text = displayData.destination.isEmpty ? "" : displayData.destination
        
        // Add colored left border based on company like HTML version
        let borderWidth: CGFloat = 4
        
        // Remove existing border layers
        routeNumberLabel.layer.sublayers?.removeAll(where: { $0.name == "companyBorder" })
        
        let borderLayer = CALayer()
        borderLayer.name = "companyBorder"
        borderLayer.frame = CGRect(x: 0, y: 0, width: borderWidth, height: 90)
        
        switch displayData.route.company {
        case .CTB:
            borderLayer.backgroundColor = UIColor(red: 0.9, green: 0.8, blue: 0.0, alpha: 1.0).cgColor // Brighter yellow for better visibility
        case .KMB:
            borderLayer.backgroundColor = UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0).cgColor // Brighter red for better visibility
        case .NWFB:
            borderLayer.backgroundColor = UIColor.systemOrange.cgColor
        }
        
        routeNumberLabel.layer.addSublayer(borderLayer)
        
        // Clear previous ETAs
        etaStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add ETA labels
        let etasToShow = Array(displayData.etas.prefix(3))
        
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
    
    private func createETALabel(text: String, isFirst: Bool) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .right
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.9
        
        if isFirst {
            // First ETA - larger, with dynamic color support
            label.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
            label.textColor = UIColor.systemTeal
        } else {
            // Other ETAs - refined styling with better contrast
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            label.textColor = UIColor.secondaryLabel
        }
        
        return label
    }
}