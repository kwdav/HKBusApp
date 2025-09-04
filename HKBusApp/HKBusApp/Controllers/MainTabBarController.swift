import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupViewControllers()
    }
    
    private func setupTabBar() {
        tabBar.backgroundColor = UIColor.systemBackground
        tabBar.tintColor = UIColor.systemBlue
        tabBar.unselectedItemTintColor = UIColor.systemGray
        
        // Support both light and dark mode
        tabBar.barTintColor = UIColor.systemBackground
        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appearance
            }
        }
    }
    
    private func setupViewControllers() {
        let busListVC = BusListViewController()
        busListVC.tabBarItem = UITabBarItem(
            title: "巴士時間",
            image: UIImage(systemName: "bus"),
            selectedImage: UIImage(systemName: "bus.fill")
        )
        
        let searchVC = SearchViewController()
        searchVC.tabBarItem = UITabBarItem(
            title: "路線搜尋",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        
        let stopSearchVC = StopSearchViewController()
        stopSearchVC.tabBarItem = UITabBarItem(
            title: "站點",
            image: UIImage(systemName: "location"),
            selectedImage: UIImage(systemName: "location.fill")
        )
        
        let busListNavController = UINavigationController(rootViewController: busListVC)
        let searchNavController = UINavigationController(rootViewController: searchVC)
        let stopSearchNavController = UINavigationController(rootViewController: stopSearchVC)
        
        // Setup navigation bar appearance
        setupNavigationBarAppearance(for: busListNavController)
        setupNavigationBarAppearance(for: searchNavController)
        setupNavigationBarAppearance(for: stopSearchNavController)
        
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
        
        // Support both light and dark mode
        navigationController.navigationBar.barStyle = .default
        navigationController.navigationBar.tintColor = UIColor.label
        navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            navigationController.navigationBar.standardAppearance = appearance
            navigationController.navigationBar.scrollEdgeAppearance = appearance
            navigationController.navigationBar.compactAppearance = appearance
        }
    }
}