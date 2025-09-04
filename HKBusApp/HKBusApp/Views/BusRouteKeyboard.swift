import UIKit

protocol BusRouteKeyboardDelegate: AnyObject {
    func keyboardDidTapNumber(_ number: String)
    func keyboardDidTapLetter(_ letter: String)
    func keyboardDidTapBackspace()
    func keyboardDidTapSearch()
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
        backgroundColor = UIColor.systemGray6
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
        let numbers = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "⌫", "0", "搜尋"]
        
        for (index, number) in numbers.enumerated() {
            let button = createKeyButton(title: number, isNumber: true)
            button.translatesAutoresizingMaskIntoConstraints = false
            numbersContainer.addSubview(button)
            
            let row = index / 3
            let col = index % 3
            let buttonWidth: CGFloat = 80
            let buttonHeight: CGFloat = 45
            let spacing: CGFloat = 6
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: buttonWidth),
                button.heightAnchor.constraint(equalToConstant: buttonHeight),
                button.leadingAnchor.constraint(equalTo: numbersContainer.leadingAnchor, constant: 12 + CGFloat(col) * (buttonWidth + spacing)),
                button.topAnchor.constraint(equalTo: numbersContainer.topAnchor, constant: 8 + CGFloat(row) * (buttonHeight + spacing))
            ])
            
            // Add target based on button type
            if number == "⌫" {
                button.addTarget(self, action: #selector(backspaceButtonTapped), for: .touchUpInside)
            } else if number == "搜尋" {
                button.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
                button.backgroundColor = UIColor.systemBlue
                button.setTitleColor(.white, for: .normal)
            } else {
                button.addTarget(self, action: #selector(numberButtonTapped(_:)), for: .touchUpInside)
            }
        }
        
        // Set numbers container constraints (5/3 of width)
        NSLayoutConstraint.activate([
            numbersContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            numbersContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            numbersContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            numbersContainer.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 5.0/8.0),
            numbersContainer.heightAnchor.constraint(equalToConstant: 212) // 4 rows * 45 + 3 * 6 spacing + 16 margins
        ])
    }
    
    private func setupLettersSection() {
        lettersContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(lettersContainer)
        
        // Scrollable letters view
        lettersScrollView.translatesAutoresizingMaskIntoConstraints = false
        lettersScrollView.showsVerticalScrollIndicator = false
        lettersContainer.addSubview(lettersScrollView)
        
        // Stack view for letters
        lettersStackView.axis = .vertical
        lettersStackView.spacing = 6
        lettersStackView.translatesAutoresizingMaskIntoConstraints = false
        lettersScrollView.addSubview(lettersStackView)
        
        // Add letter buttons
        for letter in letters {
            let button = createKeyButton(title: letter, isNumber: false)
            button.addTarget(self, action: #selector(letterButtonTapped(_:)), for: .touchUpInside)
            lettersStackView.addArrangedSubview(button)
            
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: 35),
                button.widthAnchor.constraint(equalTo: lettersStackView.widthAnchor, constant: -16)
            ])
        }
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Letters container (right side)
            lettersContainer.leadingAnchor.constraint(equalTo: numbersContainer.trailingAnchor, constant: 12),
            lettersContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            lettersContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
            lettersContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Scroll view
            lettersScrollView.topAnchor.constraint(equalTo: lettersContainer.topAnchor),
            lettersScrollView.leadingAnchor.constraint(equalTo: lettersContainer.leadingAnchor),
            lettersScrollView.trailingAnchor.constraint(equalTo: lettersContainer.trailingAnchor),
            lettersScrollView.bottomAnchor.constraint(equalTo: lettersContainer.bottomAnchor),
            
            // Stack view
            lettersStackView.topAnchor.constraint(equalTo: lettersScrollView.topAnchor),
            lettersStackView.leadingAnchor.constraint(equalTo: lettersScrollView.leadingAnchor, constant: 8),
            lettersStackView.trailingAnchor.constraint(equalTo: lettersScrollView.trailingAnchor, constant: -8),
            lettersStackView.bottomAnchor.constraint(equalTo: lettersScrollView.bottomAnchor),
            lettersStackView.widthAnchor.constraint(equalTo: lettersScrollView.widthAnchor, constant: -16)
        ])
    }
    
    private func createKeyButton(title: String, isNumber: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = isNumber ? UIFont.systemFont(ofSize: 20, weight: .medium) : UIFont.systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = UIColor.white
        button.setTitleColor(UIColor.label, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.1
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
    
    @objc private func searchButtonTapped() {
        delegate?.keyboardDidTapSearch()
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
                sender.backgroundColor = UIColor.white
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