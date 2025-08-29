import UIKit

class RouteStopTableViewCell: UITableViewCell {
    
    static let identifier = "RouteStopTableViewCell"
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let sequenceLabel = UILabel()
    private let stopNameLabel = UILabel()
    private let stopLineView = UIView()
    private let stopDotView = UIView()
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
        
        // Sequence number
        sequenceLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        sequenceLabel.textColor = UIColor.tertiaryLabel
        sequenceLabel.textAlignment = .center
        sequenceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Stop name
        stopNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
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
        
        // Chevron
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = UIColor.tertiaryLabel
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(sequenceLabel)
        containerView.addSubview(stopNameLabel)
        containerView.addSubview(stopLineView)
        containerView.addSubview(stopDotView)
        containerView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            sequenceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            sequenceLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            sequenceLabel.widthAnchor.constraint(equalToConstant: 30),
            
            stopLineView.leadingAnchor.constraint(equalTo: sequenceLabel.trailingAnchor, constant: 8),
            stopLineView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stopLineView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            stopLineView.widthAnchor.constraint(equalToConstant: 3),
            
            stopDotView.centerXAnchor.constraint(equalTo: stopLineView.centerXAnchor),
            stopDotView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stopDotView.widthAnchor.constraint(equalToConstant: 12),
            stopDotView.heightAnchor.constraint(equalToConstant: 12),
            
            stopNameLabel.leadingAnchor.constraint(equalTo: stopLineView.trailingAnchor, constant: 12),
            stopNameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stopNameLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    // MARK: - Configuration
    func configure(with stop: BusStop, isFirst: Bool, isLast: Bool) {
        sequenceLabel.text = String(stop.sequence)
        stopNameLabel.text = stop.displayName
        
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