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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = UIColor.black
        contentView.backgroundColor = UIColor.black
        selectionStyle = .none
        
        // Container view with black background like bus time design
        containerView.backgroundColor = UIColor.black
        containerView.layer.cornerRadius = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name - large and prominent
        stopNameLabel.font = UIFont.systemFont(ofSize: 21, weight: .semibold)
        stopNameLabel.textColor = UIColor.white
        stopNameLabel.numberOfLines = 1
        stopNameLabel.adjustsFontSizeToFitWidth = true
        stopNameLabel.minimumScaleFactor = 0.8
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Routes label - shows all route numbers
        routesLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        routesLabel.textColor = UIColor.lightGray
        routesLabel.numberOfLines = 1
        routesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Distance label - only distance
        distanceLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        distanceLabel.textColor = UIColor.lightGray
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
            
            // Stop name - top aligned
            stopNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stopNameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            stopNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: distanceLabel.leadingAnchor, constant: -12),
            
            // Routes label - below stop name
            routesLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routesLabel.topAnchor.constraint(equalTo: stopNameLabel.bottomAnchor, constant: 4),
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
                UIColor.systemGray6 : UIColor.black
        }
    }
}