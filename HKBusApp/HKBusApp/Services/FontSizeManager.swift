import Foundation
import UIKit

/**
 * FontSizeManager - 管理全局字體大小偏好
 *
 * 支援兩種字體大小模式：
 * - normal: 普通字體
 * - large: 加大字體（所有字體 +2~4pt）
 */
class FontSizeManager {
    static let shared = FontSizeManager()

    // Notification name for font size changes
    static let fontSizeDidChangeNotification = Notification.Name("FontSizeDidChange")

    enum FontSize: String {
        case normal = "normal"
        case large = "large"
    }

    private let userDefaultsKey = "fontSizePreference"

    private init() {}

    // MARK: - Public Properties

    var currentFontSize: FontSize {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey),
                  let fontSize = FontSize(rawValue: rawValue) else {
                return .normal // Default to normal
            }
            return fontSize
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)

            // Post notification to update UI
            NotificationCenter.default.post(
                name: FontSizeManager.fontSizeDidChangeNotification,
                object: nil
            )
        }
    }

    var isLargeFontEnabled: Bool {
        return currentFontSize == .large
    }

    // MARK: - Font Size Multipliers

    private var fontSizeAdjustment: CGFloat {
        return isLargeFontEnabled ? 1.0 : 0.0
    }

    // MARK: - Specific Font Adjustments

    /// 巴士號碼字體大小：普通 34pt，加大 38pt (+4pt)
    var busNumberFontSize: CGFloat {
        return isLargeFontEnabled ? 38 : 34
    }

    /// 站名字體大小：普通 16pt，加大 18pt (+2pt)
    var stopNameFontSize: CGFloat {
        return isLargeFontEnabled ? 18 : 16
    }

    /// 目的地字體大小：普通 14pt，加大 16pt (+2pt)
    var destinationFontSize: CGFloat {
        return isLargeFontEnabled ? 16 : 14
    }

    /// ETA 時間字體大小：普通 17pt，加大 19pt (+2pt)
    var etaTimeFontSize: CGFloat {
        return isLargeFontEnabled ? 19 : 17
    }

    /// 站點名稱（搜尋頁面）：普通 24pt，加大 27pt (+3pt)
    var stationNameFontSize: CGFloat {
        return isLargeFontEnabled ? 27 : 24
    }

    /// Section header 字體大小：普通 16pt，加大 18pt (+2pt)
    var sectionHeaderFontSize: CGFloat {
        return isLargeFontEnabled ? 18 : 16
    }

    /// 路線號碼（詳情頁）：普通 32pt，加大 36pt (+4pt)
    var routeDetailNumberFontSize: CGFloat {
        return isLargeFontEnabled ? 36 : 32
    }

    /// 一般文字：普通 17pt，加大 19pt (+2pt)
    var regularTextFontSize: CGFloat {
        return isLargeFontEnabled ? 19 : 17
    }

    /// 小文字：普通 15pt，加大 17pt (+2pt)
    var smallTextFontSize: CGFloat {
        return isLargeFontEnabled ? 17 : 15
    }
}

// MARK: - UIFont Extension

extension UIFont {

    /// 巴士號碼字體（semibold）
    static var appBusNumber: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.busNumberFontSize, weight: .semibold)
    }

    /// 站名字體（semibold）
    static var appStopName: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.stopNameFontSize, weight: .semibold)
    }

    /// 目的地字體（regular）
    static var appDestination: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.destinationFontSize, weight: .regular)
    }

    /// ETA 時間字體（medium）
    static var appETATime: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.etaTimeFontSize, weight: .medium)
    }

    /// 站點名稱字體（semibold，搜尋頁面）
    static var appStationName: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.stationNameFontSize, weight: .semibold)
    }

    /// Section header 字體（medium）
    static var appSectionHeader: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.sectionHeaderFontSize, weight: .medium)
    }

    /// 路線詳情頁號碼字體（bold）
    static var appRouteDetailNumber: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.routeDetailNumberFontSize, weight: .bold)
    }

    /// 一般文字字體（medium）
    static var appRegularText: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.regularTextFontSize, weight: .medium)
    }

    /// 小文字字體（regular）
    static var appSmallText: UIFont {
        return UIFont.systemFont(ofSize: FontSizeManager.shared.smallTextFontSize, weight: .regular)
    }
}
