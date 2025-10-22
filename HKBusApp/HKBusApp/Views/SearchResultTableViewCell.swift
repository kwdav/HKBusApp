import UIKit

class SearchResultTableViewCell: UITableViewCell {
    
    static let identifier = "SearchResultTableViewCell"
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let containerView = UIView()
    private let companyIndicator = UIView()
    
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
        titleLabel.font = UIFont.appBusNumber
        subtitleLabel.font = UIFont.appDestination
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground
        contentView.backgroundColor = UIColor.systemBackground
        
        // Container view
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Company indicator (small colored dot)
        companyIndicator.layer.cornerRadius = 2.5 // 5x5 px dot with radius 2.5
        companyIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Title label
        titleLabel.font = UIFont.appBusNumber
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle label
        subtitleLabel.font = UIFont.appDestination
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textAlignment = .right
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(companyIndicator)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Company indicator positioned at top-left corner
            companyIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            companyIndicator.topAnchor.constraint(equalTo: containerView.topAnchor),
            companyIndicator.widthAnchor.constraint(equalToConstant: 5),
            companyIndicator.heightAnchor.constraint(equalToConstant: 5),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            subtitleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            subtitleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }
    
    func configure(with searchResult: SearchResult) {
        titleLabel.text = searchResult.title
        
        // Format directions as two lines instead of one line with " | "
        if let routeResult = searchResult.routeSearchResult {
            let directions = routeResult.directions.map { $0.displayText }
            subtitleLabel.text = directions.joined(separator: "\n")
            
            switch routeResult.company {
            case .KMB:
                companyIndicator.backgroundColor = UIColor.systemRed
            case .CTB, .NWFB:
                companyIndicator.backgroundColor = UIColor.systemYellow
            }
        } else {
            subtitleLabel.text = searchResult.subtitle
        }
    }
}