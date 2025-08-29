import UIKit
import QuartzCore

class SearchViewController: UIViewController {
    
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    // Remove segmented control for now, only support route search
    
    private var routeSearchResults: [RouteSearchResult] = []
    private var stopSearchResults: [SearchResult] = []
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    private var isLoading = false
    private var searchTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "搜尋"
        setupUI()
        setupSearchBar()
        setupTableView()
        setupTapGesture()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Auto focus search bar when view appears
        searchBar.becomeFirstResponder()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Search bar
        searchBar.placeholder = "搜尋路線或站點"
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor.label
        searchBar.barTintColor = UIColor.systemBackground
        searchBar.showsCancelButton = true
        searchBar.autocapitalizationType = .allCharacters
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Customize search bar appearance for both light and dark mode
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = UIColor.label
            textField.backgroundColor = UIColor.secondarySystemBackground
        }
        
        // No segmented control - only route search for now
        
        // Table view
        tableView.backgroundColor = UIColor.systemBackground
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 44),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.returnKeyType = .search
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SearchResultTableViewCell.self, forCellReuseIdentifier: SearchResultTableViewCell.identifier)
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func performSearch(for query: String) {
        // Only search if query has meaningful content (at least 1 character)
        guard query.count >= 1 else {
            routeSearchResults = []
            tableView.reloadData()
            return
        }
        
        searchRoutes(query: query)
    }
    
    private func searchRoutes(query: String) {
        guard !isLoading && !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        
        // Show loading state
        DispatchQueue.main.async {
            // Could add loading indicator here
        }
        
        apiService.searchRoutes(routeNumber: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let results):
                    print("搜尋結果: \(results.count) 個路線")
                    self?.routeSearchResults = results
                    self?.tableView.reloadData()
                case .failure(let error):
                    print("搜尋錯誤: \(error.localizedDescription)")
                    self?.routeSearchResults = []
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Cancel previous search timer
        searchTimer?.invalidate()
        
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            routeSearchResults = []
            tableView.reloadData()
            return
        }
        
        // Debounce search with 0.3 second delay
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            self.performSearch(for: searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        if let searchText = searchBar.text, !searchText.isEmpty {
            performSearch(for: searchText)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        routeSearchResults = []
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return routeSearchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultTableViewCell.identifier, for: indexPath) as? SearchResultTableViewCell else {
            return UITableViewCell()
        }
        
        let routeResult = routeSearchResults[indexPath.row]
        let searchResult = SearchResult(
            type: .route,
            title: "\(routeResult.company.rawValue) \(routeResult.routeNumber)",
            subtitle: routeResult.directions.map { $0.displayText }.joined(separator: " | "),
            route: nil,
            routeSearchResult: routeResult
        )
        cell.configure(with: searchResult)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let routeResult = routeSearchResults[indexPath.row]
        
        // If only one direction, go straight to route detail
        // If multiple directions, show direction selection
        if routeResult.directions.count == 1 {
            let direction = routeResult.directions[0]
            showRouteDetail(routeNumber: routeResult.routeNumber, 
                          company: routeResult.company, 
                          direction: direction.direction)
        } else {
            let sourceRect = tableView.rectForRow(at: indexPath)
            showDirectionSelection(for: routeResult, sourceRect: sourceRect)
        }
    }
    
    private func showDirectionSelection(for routeResult: RouteSearchResult, sourceRect: CGRect) {
        let actionSheet = UIAlertController(title: "\(routeResult.company.rawValue) \(routeResult.routeNumber)", 
                                          message: "請選擇路線方向", 
                                          preferredStyle: .actionSheet)
        
        for direction in routeResult.directions {
            let action = UIAlertAction(title: direction.displayText, style: .default) { _ in
                self.showRouteDetail(routeNumber: routeResult.routeNumber, 
                                   company: routeResult.company, 
                                   direction: direction.direction)
            }
            actionSheet.addAction(action)
        }
        
        actionSheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // For iPad
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = sourceRect
        }
        
        present(actionSheet, animated: true)
    }
    
    private func showRouteDetail(routeNumber: String, company: BusRoute.Company, direction: String) {
        let routeDetailVC = RouteDetailViewController(
            routeNumber: routeNumber,
            company: company,
            direction: direction
        )
        
        // Custom transition animation
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .moveIn
        transition.subtype = .fromRight
        navigationController?.view.layer.add(transition, forKey: kCATransition)
        
        navigationController?.pushViewController(routeDetailVC, animated: false)
    }
}

// MARK: - Supporting Types
enum SearchType {
    case route
    case stop
}

struct SearchResult {
    let type: SearchType
    let title: String
    let subtitle: String
    let route: BusRoute?
    let routeSearchResult: RouteSearchResult?
    
    init(type: SearchType, title: String, subtitle: String, route: BusRoute?, routeSearchResult: RouteSearchResult? = nil) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.route = route
        self.routeSearchResult = routeSearchResult
    }
}