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
        backgroundColor = UIColor.black
        contentView.backgroundColor = UIColor.black
        
        // Container view - similar to HTML eta-item
        containerView.backgroundColor = UIColor.black
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Add border styling like HTML version
        let topBorder = UIView()
        topBorder.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        
        let bottomBorder = UIView()
        bottomBorder.backgroundColor = UIColor(white: 1.0, alpha: 0.1)
        bottomBorder.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(topBorder)
        containerView.addSubview(bottomBorder)
        
        // Route number label - larger and more prominent like HTML
        routeNumberLabel.font = UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        routeNumberLabel.textColor = UIColor.white
        routeNumberLabel.textAlignment = .left
        routeNumberLabel.backgroundColor = UIColor.clear
        routeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name label - smaller like HTML
        stopNameLabel.font = UIFont.systemFont(ofSize: 11.2, weight: .medium)
        stopNameLabel.textColor = UIColor.white
        stopNameLabel.numberOfLines = 1
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Destination label - smaller and gray like HTML
        destinationLabel.font = UIFont.systemFont(ofSize: 9.6, weight: .regular)
        destinationLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
        destinationLabel.numberOfLines = 1
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
            // Container fills the cell
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Borders
            topBorder.topAnchor.constraint(equalTo: containerView.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),
            
            bottomBorder.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bottomBorder.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1),
            
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
            borderLayer.backgroundColor = UIColor(red: 0.67, green: 0.67, blue: 0.0, alpha: 1.0).cgColor // #AA0
        case .KMB:
            borderLayer.backgroundColor = UIColor(red: 0.67, green: 0.0, blue: 0.0, alpha: 1.0).cgColor // #A00
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
        
        if isFirst {
            // First ETA - larger, cyan color like HTML
            label.font = UIFont.systemFont(ofSize: 19.5, weight: .bold) // 1.22em of 16px
            label.textColor = UIColor.cyan
        } else {
            // Other ETAs - smaller, white with opacity
            label.font = UIFont.systemFont(ofSize: 14.4, weight: .bold) // 0.9em of 16px
            label.textColor = UIColor.white.withAlphaComponent(0.8)
        }
        
        return label
    }
}