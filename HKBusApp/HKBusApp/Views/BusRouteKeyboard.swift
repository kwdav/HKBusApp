import UIKit

protocol BusRouteKeyboardDelegate: AnyObject {
    func keyboardDidTapNumber(_ number: String)
    func keyboardDidTapLetter(_ letter: String)
    func keyboardDidTapBackspace()
}

class BusRouteKeyboard: UIView {
    
    weak var delegate: BusRouteKeyboardDelegate?
    
    // UI Components
    private let containerView = UIView()
    private let numbersContainer = UIView()
    private let lettersContainer = UIView()
    private let lettersScrollView = UIScrollView()
    private let lettersStackView = UIStackView()
    
    // Letters array for bus routes
    private let letters = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "R", "S", "T", "X"]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.9)
        layer.cornerRadius = 12
        translatesAutoresizingMaskIntoConstraints = false
        
        setupContainer()
        setupNumbersKeypad()
        setupLettersSection()
    }
    
    private func setupContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupNumbersKeypad() {
        numbersContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(numbersContainer)
        
        // Create 3x4 grid (7-9, 4-6, 1-3, 0) - numbers from bottom to top like standard keypad
        let numbers = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "⌫", "0", ""]
        
        for (index, number) in numbers.enumerated() {
            // Skip empty slots
            if number.isEmpty {
                continue
            }
            
            let button = createKeyButton(title: number, isNumber: true)
            button.translatesAutoresizingMaskIntoConstraints = false
            numbersContainer.addSubview(button)
            
            let row = index / 3
            let col = index % 3
            let buttonHeight: CGFloat = 55  // Increased from 50px to 55px
            let spacing: CGFloat = 5  // 5px spacing
            
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: buttonHeight),
                button.topAnchor.constraint(equalTo: numbersContainer.topAnchor, constant: 8 + CGFloat(row) * (buttonHeight + spacing))
            ])
            
            // Handle horizontal positioning and width with equal distribution
            if col == 0 {
                // First column: leading edge of container
                button.leadingAnchor.constraint(equalTo: numbersContainer.leadingAnchor).isActive = true
            } else if col == 1 {
                // Middle column: positioned between first and last
                button.centerXAnchor.constraint(equalTo: numbersContainer.centerXAnchor).isActive = true
            } else {
                // Last column: trailing edge of container with spacing
                button.trailingAnchor.constraint(equalTo: numbersContainer.trailingAnchor).isActive = true
            }
            
            // All buttons have equal width using the numbers container width divided by 3, minus spacing
            button.widthAnchor.constraint(equalTo: numbersContainer.widthAnchor, multiplier: 1.0/3.0, constant: -4).isActive = true // -4 to account for spacing distribution
            
            // Add target based on button type
            if number == "⌫" {
                button.addTarget(self, action: #selector(backspaceButtonTapped), for: .touchUpInside)
            } else {
                button.addTarget(self, action: #selector(numberButtonTapped(_:)), for: .touchUpInside)
            }
        }
        
        // Set numbers container constraints - now takes 3/5 of total width (3 columns out of 5)
        NSLayoutConstraint.activate([
            numbersContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            numbersContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            numbersContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            numbersContainer.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 3.0/5.0),  // 3/5 for 3 columns
            numbersContainer.heightAnchor.constraint(equalToConstant: 251) // 4 rows * 55 + 3 * 5 spacing + 16 margins
        ])
    }
    
    private func setupLettersSection() {
        lettersContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(lettersContainer)
        
        // Scrollable letters view
        lettersScrollView.translatesAutoresizingMaskIntoConstraints = false
        lettersScrollView.showsVerticalScrollIndicator = false
        lettersContainer.addSubview(lettersScrollView)
        
        // Create letter buttons - 2 per row, each 1/5 of screen width
        let buttonHeight: CGFloat = 50
        let spacing: CGFloat = 5  // 5px spacing like numbers
        let margin: CGFloat = 8
        
        for (index, letter) in letters.enumerated() {
            let button = createKeyButton(title: letter, isNumber: false)
            button.addTarget(self, action: #selector(letterButtonTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            lettersScrollView.addSubview(button)
            
            let row = index / 2
            let col = index % 2
            
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: buttonHeight),
                button.topAnchor.constraint(equalTo: lettersScrollView.topAnchor, 
                                          constant: margin + CGFloat(row) * (buttonHeight + spacing))
            ])
            
            // Handle horizontal positioning for 2-column layout in letters container
            if col == 0 {
                // First column: left side with explicit width
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: lettersScrollView.leadingAnchor),
                    button.widthAnchor.constraint(equalTo: lettersScrollView.widthAnchor, multiplier: 0.5, constant: -2.5)
                ])
            } else {
                // Second column: positioned relative to first column button in same row
                let firstInRowIndex = row * 2  // Index of first button in this row
                if firstInRowIndex < index {
                    let firstButton = lettersScrollView.subviews[firstInRowIndex] as! UIButton
                    NSLayoutConstraint.activate([
                        button.leadingAnchor.constraint(equalTo: firstButton.trailingAnchor, constant: spacing),
                        button.widthAnchor.constraint(equalTo: lettersScrollView.widthAnchor, multiplier: 0.5, constant: -2.5)
                    ])
                }
            }
        }
        
        // Calculate content height for scroll view (2-column layout)
        let rows = (letters.count + 1) / 2 // Round up division
        let contentHeight = margin * 2 + CGFloat(rows) * buttonHeight + CGFloat(max(0, rows - 1)) * spacing
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Letters container (right side) - positioned after numbers with gap
            lettersContainer.leadingAnchor.constraint(equalTo: numbersContainer.trailingAnchor, constant: 10),  // 10px gap between numbers and letters
            lettersContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            lettersContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            lettersContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            // Remove conflicting width constraint - let it use remaining space
            
            // Scroll view
            lettersScrollView.topAnchor.constraint(equalTo: lettersContainer.topAnchor),
            lettersScrollView.leadingAnchor.constraint(equalTo: lettersContainer.leadingAnchor),
            lettersScrollView.trailingAnchor.constraint(equalTo: lettersContainer.trailingAnchor),
            lettersScrollView.bottomAnchor.constraint(equalTo: lettersContainer.bottomAnchor),
            lettersScrollView.contentLayoutGuide.heightAnchor.constraint(equalToConstant: contentHeight)
        ])
    }
    
    private func createKeyButton(title: String, isNumber: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = isNumber ? UIFont.systemFont(ofSize: 20, weight: .medium) : UIFont.systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = UIColor.systemGray5
        button.setTitleColor(UIColor.white, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 2
        
        // Add touch feedback
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        return button
    }
    
    // MARK: - Button Actions
    
    @objc private func numberButtonTapped(_ sender: UIButton) {
        guard let number = sender.title(for: .normal) else { return }
        delegate?.keyboardDidTapNumber(number)
    }
    
    @objc private func letterButtonTapped(_ sender: UIButton) {
        guard let letter = sender.title(for: .normal) else { return }
        delegate?.keyboardDidTapLetter(letter)
    }
    
    @objc private func backspaceButtonTapped() {
        delegate?.keyboardDidTapBackspace()
    }
    
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.backgroundColor = UIColor.systemGray4
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform.identity
            if sender.backgroundColor != UIColor.systemBlue {
                sender.backgroundColor = UIColor.systemGray5
            }
        }
    }
    
    // MARK: - Show/Hide Methods
    
    func show(animated: Bool = true) {
        guard isHidden else { return }
        
        if animated {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 50)
            self.isHidden = false
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.alpha = 1
                self.transform = CGAffineTransform.identity
            }
        } else {
            self.isHidden = false
            self.alpha = 1
            self.transform = CGAffineTransform.identity
        }
    }
    
    func hide(animated: Bool = true) {
        guard !isHidden else { return }
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(translationX: 0, y: 50)
            }) { _ in
                self.isHidden = true
            }
        } else {
            self.isHidden = true
            self.alpha = 0
        }
    }
}