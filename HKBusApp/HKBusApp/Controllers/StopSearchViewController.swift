import UIKit
import QuartzCore


class StopSearchViewController: UIViewController {
    
    // MARK: - Properties
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let apiService = BusAPIService.shared
    private let favoritesManager = FavoritesManager.shared
    
    private var stopSearchResults: [StopSearchResult] = []
    private var isLoading = false
    private var searchTimer: Timer?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "站點搜尋"
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
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Search bar
        searchBar.placeholder = "搜尋巴士站名稱"
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = UIColor.label
        searchBar.barTintColor = UIColor.systemBackground
        searchBar.showsCancelButton = true
        searchBar.autocapitalizationType = .none
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Customize search bar appearance for both light and dark mode
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = UIColor.label
            textField.backgroundColor = UIColor.secondarySystemBackground
        }
        
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
        tableView.register(StopSearchResultTableViewCell.self, forCellReuseIdentifier: StopSearchResultTableViewCell.identifier)
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Search Methods
    private func performSearch(for query: String) {
        // Only search if query has meaningful content (at least 2 characters for stops)
        guard query.count >= 2 else {
            stopSearchResults = []
            tableView.reloadData()
            return
        }
        
        searchStops(query: query)
    }
    
    private func searchStops(query: String) {
        guard !isLoading && !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isLoading = true
        
        apiService.searchStops(stopName: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let results):
                    print("站點搜尋結果: \(results.count) 個站點")
                    self?.stopSearchResults = results
                    self?.tableView.reloadData()
                case .failure(let error):
                    print("站點搜尋錯誤: \(error.localizedDescription)")
                    self?.stopSearchResults = []
                    self?.tableView.reloadData()
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension StopSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Cancel previous search timer
        searchTimer?.invalidate()
        
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            stopSearchResults = []
            tableView.reloadData()
            return
        }
        
        // Debounce search with 0.5 second delay (longer for stop names)
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
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
        stopSearchResults = []
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension StopSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stopSearchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: StopSearchResultTableViewCell.identifier, for: indexPath) as? StopSearchResultTableViewCell else {
            return UITableViewCell()
        }
        
        let stopResult = stopSearchResults[indexPath.row]
        cell.configure(with: stopResult)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension StopSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let stopResult = stopSearchResults[indexPath.row]
        
        // Navigate to stop routes view
        showStopRoutes(stopResult: stopResult)
    }
    
    private func showStopRoutes(stopResult: StopSearchResult) {
        let stopRoutesVC = StopRoutesViewController(stopResult: stopResult)
        
        // Custom transition animation
        let transition = CATransition()
        transition.duration = 0.3
        transition.type = .moveIn
        transition.subtype = .fromRight
        navigationController?.view.layer.add(transition, forKey: kCATransition)
        
        navigationController?.pushViewController(stopRoutesVC, animated: false)
    }
}