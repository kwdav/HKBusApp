import UIKit

class BusETATableViewCell: UITableViewCell {
    
    static let identifier = "BusETATableViewCell"
    
    private let routeNumberLabel = UILabel()
    private let stopNameLabel = UILabel()
    private let destinationLabel = UILabel()
    private let etaStackView = UIStackView()
    private let containerView = UIView()
    private let separatorLine = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = UIColor.black
        contentView.backgroundColor = UIColor.black
        
        // Container view with black background
        containerView.backgroundColor = UIColor.black
        containerView.layer.cornerRadius = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Route number label - optimized for readability and impact
        routeNumberLabel.font = UIFont.monospacedSystemFont(ofSize: 34, weight: .semibold)
        routeNumberLabel.textColor = UIColor.white
        routeNumberLabel.textAlignment = .left
        routeNumberLabel.backgroundColor = UIColor.clear
        routeNumberLabel.adjustsFontSizeToFitWidth = true
        routeNumberLabel.minimumScaleFactor = 0.8
        routeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name label - enhanced for better readability
        stopNameLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        stopNameLabel.textColor = UIColor.white
        stopNameLabel.numberOfLines = 1
        stopNameLabel.adjustsFontSizeToFitWidth = true
        stopNameLabel.minimumScaleFactor = 0.9
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Destination label - improved contrast and readability
        destinationLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        destinationLabel.textColor = UIColor.lightGray
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
        
        // Separator line
        separatorLine.backgroundColor = UIColor.systemGray6
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(routeNumberLabel)
        containerView.addSubview(routeInfoStackView)
        containerView.addSubview(etaStackView)
        contentView.addSubview(separatorLine)
        
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
            
            // ETA - 140px width like HTML
            etaStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            etaStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            etaStackView.widthAnchor.constraint(equalToConstant: 140),
            
            // Separator line
            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    func configure(with displayData: BusDisplayData) {
        routeNumberLabel.text = displayData.route.route
        stopNameLabel.text = displayData.stopName.isEmpty ? "載入中..." : displayData.stopName
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
            let noDataLabel = createNoDataLabel()
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
            label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            label.textColor = UIColor.systemTeal
        } else {
            // Other ETAs - refined styling with better contrast
            label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            label.textColor = UIColor.gray
        }
        
        return label
    }
    
    private func createNoDataLabel() -> UILabel {
        let label = UILabel()
        label.text = "未有資料"
        label.textAlignment = .right
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.9
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.gray // Use gray instead of teal/blue
        
        return label
    }
}