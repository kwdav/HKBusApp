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
        
        // Dark theme support
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
            title: "搜尋",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        
        let busListNavController = UINavigationController(rootViewController: busListVC)
        let searchNavController = UINavigationController(rootViewController: searchVC)
        
        // Setup navigation bar appearance
        setupNavigationBarAppearance(for: busListNavController)
        setupNavigationBarAppearance(for: searchNavController)
        
        viewControllers = [busListNavController, searchNavController]
    }
    
    private func setupNavigationBarAppearance(for navigationController: UINavigationController) {
        // Hide navigation bar for more compact design
        navigationController.navigationBar.isHidden = true
        navigationController.navigationBar.prefersLargeTitles = false
    }
}