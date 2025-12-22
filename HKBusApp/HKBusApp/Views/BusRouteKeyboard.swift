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
    
    // Button references for smart disabling
    private var numberButtons: [String: UIButton] = [:]
    private var letterButtons: [String: UIButton] = [:]
    
    // Local data manager for smart predictions
    private let localDataManager = LocalBusDataManager.shared
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
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
        
        // Create 3x4 grid (7-9, 4-6, 1-3, [空]-0-⌫) - numbers from bottom to top like standard keypad
        let numbers = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "", "0", "⌫"]
        
        for (index, number) in numbers.enumerated() {
            // Skip empty slots
            if number.isEmpty {
                continue
            }
            
            let button = createKeyButton(title: number, isNumber: true)
            button.translatesAutoresizingMaskIntoConstraints = false
            numbersContainer.addSubview(button)
            
            // Store button reference for smart disabling
            if number != "⌫" {
                numberButtons[number] = button
            }
            
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

        // Main vertical stack view to hold all rows
        lettersStackView.axis = .vertical
        lettersStackView.alignment = .leading  // Align to top-left
        lettersStackView.distribution = .equalSpacing
        lettersStackView.spacing = 5  // 5px spacing between rows
        lettersStackView.translatesAutoresizingMaskIntoConstraints = false
        lettersScrollView.addSubview(lettersStackView)

        // Button dimensions
        let buttonHeight: CGFloat = 50

        // Create all letter buttons (but don't add to StackView yet)
        for letter in letters {
            let button = createKeyButton(title: letter, isNumber: false)
            button.addTarget(self, action: #selector(letterButtonTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false

            // Store button reference
            letterButtons[letter] = button

            // Set button height constraint
            button.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        }

        // Set up constraints
        NSLayoutConstraint.activate([
            // Letters container (right side) - positioned after numbers with gap
            lettersContainer.leadingAnchor.constraint(equalTo: numbersContainer.trailingAnchor, constant: 10),  // 10px gap
            lettersContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            lettersContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            lettersContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // Scroll view
            lettersScrollView.topAnchor.constraint(equalTo: lettersContainer.topAnchor),
            lettersScrollView.leadingAnchor.constraint(equalTo: lettersContainer.leadingAnchor),
            lettersScrollView.trailingAnchor.constraint(equalTo: lettersContainer.trailingAnchor),
            lettersScrollView.bottomAnchor.constraint(equalTo: lettersContainer.bottomAnchor),

            // Stack view inside scroll view with padding
            lettersStackView.topAnchor.constraint(equalTo: lettersScrollView.topAnchor, constant: 8),
            lettersStackView.leadingAnchor.constraint(equalTo: lettersScrollView.leadingAnchor),
            lettersStackView.trailingAnchor.constraint(equalTo: lettersScrollView.trailingAnchor),
            lettersStackView.bottomAnchor.constraint(equalTo: lettersScrollView.bottomAnchor, constant: -8),
            lettersStackView.widthAnchor.constraint(equalTo: lettersScrollView.widthAnchor)
        ])

        // Initial organization of buttons (all visible)
        reorganizeLetterButtons()
    }
    
    // MARK: - Letter Button Organization (Float Left Behavior)

    private func reorganizeLetterButtons() {
        // Remove all existing row StackViews from the main stack
        lettersStackView.arrangedSubviews.forEach { view in
            lettersStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        // Collect all visible buttons in order
        var visibleButtons: [UIButton] = []
        for letter in letters {
            if let button = letterButtons[letter], !button.isHidden {
                visibleButtons.append(button)
            }
        }

        // Create rows with 2 buttons each (float left behavior)
        let spacing: CGFloat = 5
        for i in stride(from: 0, to: visibleButtons.count, by: 2) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = .fillEqually
            rowStack.spacing = spacing
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            // Add first button
            rowStack.addArrangedSubview(visibleButtons[i])

            // Add second button if exists, otherwise add spacer
            if i + 1 < visibleButtons.count {
                rowStack.addArrangedSubview(visibleButtons[i + 1])
            } else {
                // Last row with single button - add spacer to maintain layout
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                rowStack.addArrangedSubview(spacer)
            }

            // Add row to main stack FIRST
            lettersStackView.addArrangedSubview(rowStack)

            // THEN set row width to match container (after it's in the hierarchy)
            rowStack.widthAnchor.constraint(equalTo: lettersStackView.widthAnchor).isActive = true
        }
    }

    private func createKeyButton(title: String, isNumber: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = isNumber ? UIFont.systemFont(ofSize: 20, weight: .medium) : UIFont.systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = UIColor.systemGray5
        button.setTitleColor(UIColor.label, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.shadowColor = UIColor.label.withAlphaComponent(0.3).cgColor
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
    
    // MARK: - Smart Button Control
    
    func updateButtonStates(for currentInput: String) {
        let possibleChars = localDataManager.getPossibleNextCharacters(for: currentInput)

        // Update number buttons (disable instead of hide to maintain grid layout)
        for (number, button) in numberButtons {
            let isEnabled = possibleChars.contains(Character(number))
            updateButtonEnabled(button, enabled: isEnabled, isLetter: false)
        }

        // Update letter buttons (hide instead of disable)
        for (letter, button) in letterButtons {
            let isAvailable = possibleChars.contains(Character(letter))
            updateButtonEnabled(button, enabled: isAvailable, isLetter: true)
        }
    }

    private func updateButtonEnabled(_ button: UIButton, enabled: Bool, isLetter: Bool) {
        if isLetter {
            // For letter buttons: hide when not available, then reorganize
            let wasHidden = button.isHidden
            button.isHidden = !enabled
            button.alpha = enabled ? 1.0 : 0.0
            button.isEnabled = enabled

            // Only reorganize if visibility actually changed
            if wasHidden != button.isHidden {
                // Instant reorganization without animation
                self.reorganizeLetterButtons()
                self.lettersStackView.layoutIfNeeded()
            }
        } else {
            // For number buttons: disable but keep visible to maintain grid layout
            button.isEnabled = enabled

            // Instant state change without animation
            if enabled {
                button.alpha = 1.0
                button.backgroundColor = UIColor.systemGray5
                button.setTitleColor(UIColor.label, for: .normal)
            } else {
                button.alpha = 0.7
                button.backgroundColor = UIColor.systemGray5
                button.setTitleColor(UIColor.systemGray3, for: .normal)
            }
        }
    }
    
    func resetAllButtons() {
        // Reset all buttons to enabled and visible state
        for (_, button) in numberButtons {
            updateButtonEnabled(button, enabled: true, isLetter: false)
        }

        // For letter buttons, show all first, then reorganize once
        for (_, button) in letterButtons {
            button.isHidden = false
            button.alpha = 1.0
            button.isEnabled = true
        }

        // Instant reorganization after all buttons are visible
        self.reorganizeLetterButtons()
        self.lettersStackView.layoutIfNeeded()
    }
    
    // MARK: - Show/Hide Methods

    func show(animated: Bool = true, completion: (() -> Void)? = nil) {
        // Remove guard clause - allow forced re-showing to fix stuck states

        // Set state immediately for consistency
        self.isHidden = false

        if animated {
            // If already visible, no animation needed
            if self.alpha == 1 && self.transform == .identity {
                completion?()
                return
            }

            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 50)

            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                self.alpha = 1
                self.transform = CGAffineTransform.identity
            }) { _ in
                completion?()
            }
        } else {
            self.alpha = 1
            self.transform = CGAffineTransform.identity
            completion?()
        }
    }

    func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        // Remove guard clause - allow forced hiding

        if animated {
            // If already hidden, no animation needed
            if self.isHidden && self.alpha == 0 {
                completion?()
                return
            }

            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(translationX: 0, y: 50)
            }) { _ in
                self.isHidden = true
                completion?()
            }
        } else {
            self.isHidden = true
            self.alpha = 0
            completion?()
        }
    }
}