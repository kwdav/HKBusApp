import UIKit

class MainTabBarController: UITabBarController {
    
    private var previousSelectedIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupViewControllers()
    }
    
    private func setupTabBar() {
        // Set delegate for tab switching detection
        delegate = self
        
        // Remove backgroundColor to enable translucency
        tabBar.backgroundColor = nil
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.systemGray
        
        // Enable translucent blur effect like App Store
        tabBar.isTranslucent = true
        tabBar.barTintColor = nil // Let system handle the color
        
        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            // Use transparent background for blur effect
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appearance
            }
        }
    }
    
    private func setupViewControllers() {
        let busListVC = BusListViewController()
        busListVC.tabBarItem = UITabBarItem(
            title: "我的",
            image: UIImage(systemName: "star"),
            selectedImage: UIImage(systemName: "star.fill")
        )

        let searchVC = SearchViewController()
        searchVC.tabBarItem = UITabBarItem(
            title: "路線",
            image: UIImage(systemName: "bus"),
            selectedImage: UIImage(systemName: "bus.fill")
        )

        let stopSearchVC = StopSearchViewController()
        stopSearchVC.tabBarItem = UITabBarItem(
            title: "站點",
            image: UIImage(systemName: "mappin.and.ellipse"),
            selectedImage: UIImage(systemName: "mappin.and.ellipse")
        )
        
        let busListNavController = UINavigationController(rootViewController: busListVC)
        let searchNavController = SearchNavigationController(rootViewController: searchVC)  // Use custom nav controller
        let stopSearchNavController = SearchNavigationController(rootViewController: stopSearchVC)  // Use custom nav controller
        
        // Setup navigation bar appearance (only for bus list, search controllers handle themselves)
        setupNavigationBarAppearance(for: busListNavController)
        
        viewControllers = [busListNavController, searchNavController, stopSearchNavController]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if BusListViewController has any favorites/data
        checkAndSetInitialTab()
    }
    
    private func checkAndSetInitialTab() {
        // Check if there are any favorites
        let favoritesCount = FavoritesManager.shared.getAllFavorites().count
        let hasSetInitialTab = UserDefaults.standard.bool(forKey: "hasSetInitialTab")
        
        if favoritesCount == 0 && !hasSetInitialTab {
            // No favorites on first launch, switch to route search tab (index 1)
            print("📱 沒有收藏路線，自動切換到路線搜尋頁面")
            selectedIndex = 1
            UserDefaults.standard.set(true, forKey: "hasSetInitialTab")
        } else if favoritesCount > 0 && !hasSetInitialTab {
            print("📱 有 \(favoritesCount) 個收藏路線，保持在巴士時間頁面")
            UserDefaults.standard.set(true, forKey: "hasSetInitialTab")
        }
        // If hasSetInitialTab is true, do nothing (user has already seen the initial behavior)
    }
    
    // Public method to reset initial tab behavior when all favorites are deleted
    func resetInitialTabBehavior() {
        UserDefaults.standard.set(false, forKey: "hasSetInitialTab")
    }
    
    private func setupNavigationBarAppearance(for navigationController: UINavigationController) {
        // Show navigation bar but keep it minimal
        navigationController.navigationBar.isHidden = false
        navigationController.navigationBar.prefersLargeTitles = false
        
        // Enable translucent blur effect like App Store
        navigationController.navigationBar.isTranslucent = true
        navigationController.navigationBar.barStyle = .default
        navigationController.navigationBar.tintColor = UIColor.label
        navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            // Use transparent background for blur effect
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
        }
    }
}

// MARK: - UITabBarControllerDelegate
extension MainTabBarController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let newIndex = viewControllers?.firstIndex(of: viewController) ?? 0
        
        // Check if user tapped the route search tab (index 1)
        if newIndex == 1 {
            if let navController = viewController as? UINavigationController {
                // Check if we're already on route search tab (repeat tap)
                if newIndex == selectedIndex {
                    // Check navigation stack depth to determine action
                    if navController.viewControllers.count > 1 {
                        // Deep in navigation stack (e.g., in RouteDetailViewController)
                        print("🔄 在路線詳情頁面點擊tab，返回搜尋根頁面")
                        navController.popToRootViewController(animated: true)
                        return false // Don't switch tabs, just pop navigation
                    } else {
                        // Already at root, show keyboard
                        print("🔄 重複點擊路線tab，顯示鍵盤")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.triggerRouteSearchKeyboard()
                        }
                        return false // Don't actually switch, just trigger keyboard
                    }
                }
                // Coming from another tab - preserve navigation stack
            }
        }

        // Check if user tapped the stop search tab (index 2)
        if newIndex == 2 {
            if let navController = viewController as? UINavigationController {
                // Check if we're already on stop search tab (repeat tap)
                if newIndex == selectedIndex {
                    // Check navigation stack depth to determine action
                    if navController.viewControllers.count > 1 {
                        // In navigation stack, pop back one level
                        print("🔄 重複點擊站點tab，返回上一頁")
                        navController.popViewController(animated: true)
                        return false // Don't switch tabs, just pop navigation
                    } else {
                        // Already at root, do nothing
                        print("🔄 重複點擊站點tab，已在根頁面")
                        return false
                    }
                }
                // Coming from another tab - preserve navigation stack
            }
        }
        
        // Update previous selected index for next comparison
        previousSelectedIndex = selectedIndex
        return true
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let newIndex = viewControllers?.firstIndex(of: viewController) ?? 0
        
        // 首次切換到路線搜尋頁面時不自動 focus
        // 只有重複點擊（在 shouldSelect 中處理）才會觸發鍵盤
        
        // Update previous selected index
        previousSelectedIndex = newIndex
    }
    
    private func triggerRouteSearchKeyboard() {
        // Access the SearchViewController and trigger keyboard
        if let navController = viewControllers?[1] as? UINavigationController,
           let searchVC = navController.topViewController as? SearchViewController {
            searchVC.showKeyboardOnTabSwitch()
        }
    }
}