import UIKit

class AppearanceManager {

    static let shared = AppearanceManager()

    enum AppearanceMode: Int {
        case automatic = 0
        case light = 1
        case dark = 2

        var userInterfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .automatic:
                return .unspecified
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }

        var displayName: String {
            switch self {
            case .automatic:
                return "自動"
            case .light:
                return "淺色"
            case .dark:
                return "深色"
            }
        }
    }

    private let userDefaultsKey = "AppearanceMode"

    var currentMode: AppearanceMode {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: userDefaultsKey)
            return AppearanceMode(rawValue: rawValue) ?? .automatic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
            applyAppearance(newValue)
        }
    }

    private init() {}

    func applyAppearance(_ mode: AppearanceMode) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.overrideUserInterfaceStyle = mode.userInterfaceStyle
        }
    }

    func applySavedAppearance() {
        applyAppearance(currentMode)
    }
}
