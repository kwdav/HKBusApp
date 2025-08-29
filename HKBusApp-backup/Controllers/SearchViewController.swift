import UIKit

class SearchViewController: UIViewController {
    
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let segmentedControl = UISegmentedControl(items: ["路線", "站點"])
    
    private var searchResults: [SearchResult] = []
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSearchController()
        setupTableView()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black
        
        // Segmented control
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        segmentedControl.selectedSegmentTintColor = UIColor.systemBlue
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Table view
        tableView.backgroundColor = UIColor.black
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "搜尋路線或站點"
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.tintColor = UIColor.white
        searchController.searchBar.barTintColor = UIColor.black
        
        // Customize search bar appearance
        if let textField = searchController.searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = UIColor.white
            textField.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        }
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SearchResultTableViewCell.self, forCellReuseIdentifier: SearchResultTableViewCell.identifier)
    }
    
    @objc private func segmentChanged() {
        // Trigger search again with new type
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            performSearch(for: searchText)
        }
    }
    
    private func performSearch(for query: String) {
        let searchType: SearchType = segmentedControl.selectedSegmentIndex == 0 ? .route : .stop
        
        switch searchType {
        case .route:
            searchRoutes(query: query)
        case .stop:
            searchStops(query: query)
        }
    }
    
    private func searchRoutes(query: String) {
        // For now, search through known routes from both companies
        let allCompanies: [BusRoute.Company] = [.CTB, .KMB, .NWFB]
        var results: [SearchResult] = []
        
        for company in allCompanies {
            if query.lowercased().contains(company.rawValue.lowercased()) || 
               company.rawValue.lowercased().contains(query.lowercased()) {
                // Add company-specific results
                let result = SearchResult(
                    type: .route,
                    title: "\(company.rawValue) 路線",
                    subtitle: "搜尋 \(company.rawValue) 的路線",
                    route: nil
                )
                results.append(result)
            }
        }
        
        // Add route number search
        if !query.isEmpty {
            let result = SearchResult(
                type: .route,
                title: "路線 \(query)",
                subtitle: "搜尋路線號碼：\(query)",
                route: nil
            )
            results.append(result)
        }
        
        DispatchQueue.main.async {
            self.searchResults = results
            self.tableView.reloadData()
        }
    }
    
    private func searchStops(query: String) {
        // Placeholder for stop search
        let result = SearchResult(
            type: .stop,
            title: "搜尋站點：\(query)",
            subtitle: "站點搜尋功能開發中",
            route: nil
        )
        
        DispatchQueue.main.async {
            self.searchResults = [result]
            self.tableView.reloadData()
        }
    }
}

// MARK: - UISearchResultsUpdating
extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text, 
              !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            tableView.reloadData()
            return
        }
        
        performSearch(for: searchText)
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultTableViewCell.identifier, for: indexPath) as? SearchResultTableViewCell else {
            return UITableViewCell()
        }
        
        let searchResult = searchResults[indexPath.row]
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
        
        let searchResult = searchResults[indexPath.row]
        
        if let route = searchResult.route {
            // Add to favorites
            favoritesManager.addFavorite(route)
            
            // Show confirmation
            let alert = UIAlertController(title: "已加入收藏", message: "路線 \(route.route) 已加入收藏列表", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            present(alert, animated: true)
        }
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
}