import UIKit

class StopSearchResultTableViewCell: UITableViewCell {
    
    static let identifier = "StopSearchResultTableViewCell"
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let stopNameLabel = UILabel()
    private let routesLabel = UILabel()
    private let distanceLabel = UILabel()
    private let chevronImageView = UIImageView()
    private let separatorLine = UIView()
    
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
        stopNameLabel.font = UIFont.appStationName
        routesLabel.font = UIFont.appRegularText
        distanceLabel.font = UIFont.appRegularText
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        contentView.backgroundColor = UIColor.systemBackground
        selectionStyle = .none
        
        // Container view with adaptive background like bus time design
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name - large and prominent
        stopNameLabel.font = UIFont.appStationName
        stopNameLabel.textColor = UIColor.label
        stopNameLabel.numberOfLines = 1
        stopNameLabel.adjustsFontSizeToFitWidth = true
        stopNameLabel.minimumScaleFactor = 0.8
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Routes label - shows all route numbers
        routesLabel.font = UIFont.appRegularText
        routesLabel.textColor = UIColor.secondaryLabel
        routesLabel.numberOfLines = 1
        routesLabel.translatesAutoresizingMaskIntoConstraints = false

        // Distance label - only distance
        distanceLabel.font = UIFont.appRegularText
        distanceLabel.textColor = UIColor.secondaryLabel
        distanceLabel.textAlignment = .right
        distanceLabel.numberOfLines = 1
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Separator line
        separatorLine.backgroundColor = UIColor.systemGray6
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        
        // Chevron
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = UIColor.darkGray
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(stopNameLabel)
        containerView.addSubview(routesLabel)
        containerView.addSubview(distanceLabel)
        containerView.addSubview(chevronImageView)
        contentView.addSubview(separatorLine)
        
        NSLayoutConstraint.activate([
            // Container with minimal margins
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -1),
            
            // Stop name - vertically centered above routes
            stopNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stopNameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -12),
            stopNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: distanceLabel.leadingAnchor, constant: -12),
            
            // Routes label - below stop name, vertically centered
            routesLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routesLabel.topAnchor.constraint(equalTo: stopNameLabel.bottomAnchor, constant: 2),
            routesLabel.trailingAnchor.constraint(lessThanOrEqualTo: distanceLabel.leadingAnchor, constant: -12),
            
            // Distance - centered vertically, right aligned
            distanceLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            distanceLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            distanceLabel.widthAnchor.constraint(equalToConstant: 80),
            
            // Chevron
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12),
            
            // Separator line
            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    // MARK: - Configuration
    func configure(with stopResult: StopSearchResult, distance: String? = nil) {
        stopNameLabel.text = stopResult.displayName
        
        // Show route numbers in one line, with smart truncation
        if stopResult.routes.isEmpty {
            routesLabel.text = "無路線數據"
        } else {
            let routeNumbers = stopResult.routes.map { $0.routeNumber }.sorted()
            let routeText = routeNumbers.joined(separator: ", ")
            
            // If too many routes, show first few and add count
            if routeNumbers.count > 8 {
                let firstRoutes = Array(routeNumbers.prefix(8))
                routesLabel.text = "\(firstRoutes.joined(separator: ", ")) 等\(routeNumbers.count)條路線"
            } else {
                routesLabel.text = routeText
            }
        }
        
        // Show only distance
        distanceLabel.text = distance ?? ""
    }
    
    // MARK: - Touch Handling
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.1) {
            self.containerView.backgroundColor = highlighted ? 
                UIColor.systemGray6 : UIColor.systemBackground
        }
    }
}