import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        let mainTabBarController = MainTabBarController()
        window?.rootViewController = mainTabBarController
        window?.makeKeyAndVisible()

        // Apply saved appearance setting
        AppearanceManager.shared.applySavedAppearance()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // 檢查 Firebase 數據更新（24小時節流）
        // 只檢查版本，不自動下載
        FirebaseDataManager.shared.checkForUpdates { result in
            switch result {
            case .success(let hasUpdate):
                if hasUpdate {
                    print("🆕 發現新版本（設置頁面將顯示提示）")
                    // 發送通知給設置頁面顯示提示
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewVersionAvailable"),
                        object: nil
                    )
                }
            case .failure(let error):
                print("⚠️ 版本檢查失敗: \(error.localizedDescription)")
                // 靜默失敗，不打擾用戶
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

}

