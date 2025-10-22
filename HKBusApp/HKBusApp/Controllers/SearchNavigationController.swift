import UIKit

class SearchNavigationController: UINavigationController {
    
    // Always show status bar to display clock and battery
    override var prefersStatusBarHidden: Bool {
        return false  // Always show status bar
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBarAppearance()
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        // Show navigation bar when pushing to detail pages
        if viewControllers.count >= 1 {
            setNavigationBarHidden(false, animated: animated)
        }
        super.pushViewController(viewController, animated: animated)
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        let poppedVC = super.popViewController(animated: animated)
        
        // Hide navigation bar when returning to root search controller
        if viewControllers.count == 1 {
            setNavigationBarHidden(true, animated: animated)
        }
        setNeedsStatusBarAppearanceUpdate()
        return poppedVC
    }
    
    private func setupNavigationBarAppearance() {
        // Initially hide navigation bar for search pages
        setNavigationBarHidden(true, animated: false)
        
        // Setup navigation bar appearance for detail pages
        navigationBar.prefersLargeTitles = false
        navigationBar.isTranslucent = true
        navigationBar.tintColor = UIColor.label
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.compactAppearance = appearance
        }
    }
}