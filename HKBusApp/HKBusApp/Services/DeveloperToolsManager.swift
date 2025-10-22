import Foundation
import CoreData
import UIKit

/**
 * DeveloperToolsManager - 開發者工具管理器
 *
 * 提供開發和測試用的工具功能：
 * - 清除「我的」頁面所有收藏數據
 * - 重置參考巴士數據（重新下載最新數據）
 */
class DeveloperToolsManager {
    static let shared = DeveloperToolsManager()

    private init() {}

    // MARK: - Clear My Favorites Data

    /// 清除「我的」頁面所有收藏數據並重置為預設路線
    func clearAllFavorites(completion: @escaping (Result<Int, Error>) -> Void) {
        let context = CoreDataStack.shared.viewContext

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = BusRouteFavorite.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            // Execute batch delete
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let deletedCount = result?.result as? Int ?? 0

            // Save context
            try context.save()

            // Reset initial tab behavior
            UserDefaults.standard.set(false, forKey: "hasSetInitialTab")

            // Clear section order cache
            UserDefaults.standard.removeObject(forKey: "sectionOrder")

            print("✅ DeveloperTools: Cleared \(deletedCount) favorites from Core Data")

            // Restore default routes from BusRouteConfiguration
            print("🔄 DeveloperTools: Restoring default routes from reference...")
            restoreDefaultRoutes()

            completion(.success(deletedCount))

        } catch {
            print("❌ DeveloperTools: Failed to clear favorites - \(error)")
            completion(.failure(error))
        }
    }

    /// 清空「我的」頁面所有收藏數據（不恢復預設路線）
    func clearAllFavoritesOnly(completion: @escaping (Result<Int, Error>) -> Void) {
        let context = CoreDataStack.shared.viewContext

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = BusRouteFavorite.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            // Execute batch delete
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            let deletedCount = result?.result as? Int ?? 0

            // Save context
            try context.save()

            // Reset initial tab behavior
            UserDefaults.standard.set(false, forKey: "hasSetInitialTab")

            // Clear section order cache
            UserDefaults.standard.removeObject(forKey: "sectionOrder")

            print("✅ DeveloperTools: Cleared \(deletedCount) favorites (no default restoration)")

            completion(.success(deletedCount))

        } catch {
            print("❌ DeveloperTools: Failed to clear favorites - \(error)")
            completion(.failure(error))
        }
    }

    /// 恢復參考文件中的預設路線
    private func restoreDefaultRoutes() {
        let context = CoreDataStack.shared.viewContext

        // Add default routes from BusRouteConfiguration
        for (index, route) in BusRouteConfiguration.defaultRoutes.enumerated() {
            let favorite = BusRouteFavorite(context: context)
            favorite.stopId = route.stopId
            favorite.route = route.route
            favorite.companyId = route.companyId
            favorite.direction = route.direction
            favorite.subTitle = route.subTitle
            favorite.dateAdded = Date()
            favorite.displayOrder = Int32(index)
        }

        do {
            try context.save()
            print("✅ DeveloperTools: Restored \(BusRouteConfiguration.defaultRoutes.count) default routes")
        } catch {
            print("❌ DeveloperTools: Failed to restore default routes - \(error)")
        }
    }

    // MARK: - Reset Reference Bus Data

    /// 重置參考巴士數據（重新下載最新數據）
    func resetReferenceBusData(completion: @escaping (Result<String, Error>) -> Void) {
        // Clear stop data cache
        clearStopDataCache()

        // Force update stop data from hk-bus-crawling
        StopDataManager.shared.forceUpdateData { result in
            switch result {
            case .success(let stopData):
                let message = "成功重置巴士數據\n包含 \(stopData.stopList.count) 個站點"
                print("✅ DeveloperTools: \(message)")
                completion(.success(message))

            case .failure(let error):
                print("❌ DeveloperTools: Failed to reset bus data - \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Private Helper Methods

    /// 清除 StopDataManager 的本地緩存
    private func clearStopDataCache() {
        let fileManager = FileManager.default
        let cacheFileName = "HKBusStopData.json"

        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ DeveloperTools: Cannot access documents directory")
            return
        }

        let cacheURL = documentsDirectory.appendingPathComponent(cacheFileName)

        do {
            if fileManager.fileExists(atPath: cacheURL.path) {
                try fileManager.removeItem(at: cacheURL)
                print("🗑️ DeveloperTools: Removed cached stop data file")
            }

            // Clear last update time
            UserDefaults.standard.removeObject(forKey: "StopDataLastUpdate")
            print("🗑️ DeveloperTools: Cleared stop data update timestamp")

        } catch {
            print("❌ DeveloperTools: Failed to clear cache - \(error)")
        }
    }

    // MARK: - Developer Mode Detection

    /// 檢測開發者模式觸發（3秒內點擊10次）
    class TapDetector {
        private var tapCount = 0
        private var tapTimer: Timer?
        private let requiredTaps = 10
        private let timeWindow: TimeInterval = 3.0

        func registerTap(completion: @escaping () -> Void) {
            tapCount += 1

            // Start timer on first tap
            if tapCount == 1 {
                tapTimer = Timer.scheduledTimer(withTimeInterval: timeWindow, repeats: false) { [weak self] _ in
                    self?.reset()
                }
            }

            // Check if reached required taps
            if tapCount >= requiredTaps {
                tapTimer?.invalidate()
                reset()
                completion()
            }
        }

        func reset() {
            tapCount = 0
            tapTimer?.invalidate()
            tapTimer = nil
        }
    }

    // MARK: - Export App Information

    /// 獲取 App 版本資訊
    func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "v\(version) (Build \(build))"
    }

    /// 獲取詳細的 App 和數據統計資訊
    func getDetailedInfo() -> String {
        let appVersion = getAppVersion()
        let favoritesCount = FavoritesManager.shared.getAllFavorites().count

        var info = """
        📱 App 版本: \(appVersion)
        ⭐ 收藏路線數: \(favoritesCount)
        """

        // Get stop data info if available
        if let lastUpdate = StopDataManager.shared.getLastUpdateTime() {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "zh_Hant_HK")
            let updateTimeString = formatter.string(from: lastUpdate)

            info += "\n🕐 站點數據更新: \(updateTimeString)"
        }

        // Get local bus data summary
        if let summary = LocalBusDataManager.shared.getDataSummary() {
            info += """

            📊 本地巴士數據:
            - 路線總數: \(summary.totalRoutes)
            - 站點總數: \(summary.totalStops)
            - 站點路線映射: \(summary.totalStopRouteMappings)
            """
        }

        return info
    }
}
