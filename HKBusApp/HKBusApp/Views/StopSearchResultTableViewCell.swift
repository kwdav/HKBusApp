import UIKit

class StopSearchResultTableViewCell: UITableViewCell {
    
    static let identifier = "StopSearchResultTableViewCell"
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let stopNameLabel = UILabel()
    private let routeCountLabel = UILabel()
    private let routesLabel = UILabel()
    private let chevronImageView = UIImageView()
    
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
        backgroundColor = UIColor.systemBackground
        contentView.backgroundColor = UIColor.systemBackground
        selectionStyle = .none
        
        // Container view
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name
        stopNameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        stopNameLabel.textColor = UIColor.label
        stopNameLabel.numberOfLines = 2
        stopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Route count
        routeCountLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        routeCountLabel.textColor = UIColor.systemBlue
        routeCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Routes list
        routesLabel.font = UIFont.systemFont(ofSize: 14)
        routesLabel.textColor = UIColor.secondaryLabel
        routesLabel.numberOfLines = 2
        routesLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Chevron
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = UIColor.tertiaryLabel
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(stopNameLabel)
        containerView.addSubview(routeCountLabel)
        containerView.addSubview(routesLabel)
        containerView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            stopNameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            stopNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stopNameLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            
            routeCountLabel.topAnchor.constraint(equalTo: stopNameLabel.bottomAnchor, constant: 4),
            routeCountLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            routesLabel.topAnchor.constraint(equalTo: routeCountLabel.bottomAnchor, constant: 2),
            routesLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            routesLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            routesLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    // MARK: - Configuration
    func configure(with stopResult: StopSearchResult) {
        stopNameLabel.text = stopResult.displayName
        routeCountLabel.text = "\(stopResult.routeCount) 條路線"
        routesLabel.text = "途經: \(stopResult.routeNumbers)"
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