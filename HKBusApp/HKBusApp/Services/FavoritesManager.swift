import Foundation
import CoreData
import UIKit

class FavoritesManager {
    static let shared = FavoritesManager()

    // Notification name for favorites changes
    static let favoritesDidChangeNotification = Notification.Name("FavoritesDidChangeNotification")

    private let coreDataStack = CoreDataStack.shared
    private var context: NSManagedObjectContext {
        return coreDataStack.viewContext
    }

    private init() {
        // No automatic initialization - let users build their own favorites
    }
    
    // MARK: - Favorites Management
    
    func getAllFavorites() -> [BusRoute] {
        let request: NSFetchRequest<BusRouteFavorite> = BusRouteFavorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "displayOrder", ascending: true)]

        do {
            let favorites = try context.fetch(request)
            return favorites.map { favorite in
                BusRoute(
                    stopId: favorite.stopId ?? "",
                    route: favorite.route ?? "",
                    companyId: favorite.companyId ?? "",
                    direction: favorite.direction ?? "",
                    subTitle: favorite.subTitle ?? ""
                )
            }
        } catch {
            print("Error fetching favorites: \(error)")
            return []
        }
    }
    
    func addFavorite(_ busRoute: BusRoute, subTitle: String = "其他") {
        // Check if already exists
        if isFavorite(busRoute) {
            return
        }

        let favorite = BusRouteFavorite(context: context)
        favorite.stopId = busRoute.stopId
        favorite.route = busRoute.route
        favorite.companyId = busRoute.companyId
        favorite.direction = busRoute.direction
        favorite.subTitle = subTitle
        favorite.dateAdded = Date()
        favorite.displayOrder = Int32(getNextDisplayOrder())

        saveContext()

        // Notify observers that favorites have changed
        NotificationCenter.default.post(name: FavoritesManager.favoritesDidChangeNotification, object: nil)
    }
    
    func removeFavorite(_ busRoute: BusRoute) {
        let request: NSFetchRequest<BusRouteFavorite> = BusRouteFavorite.fetchRequest()
        request.predicate = NSPredicate(
            format: "stopId == %@ AND route == %@ AND companyId == %@ AND direction == %@",
            busRoute.stopId, busRoute.route, busRoute.companyId, busRoute.direction
        )

        do {
            let favorites = try context.fetch(request)
            favorites.forEach { context.delete($0) }
            saveContext()

            // Notify observers that favorites have changed
            NotificationCenter.default.post(name: FavoritesManager.favoritesDidChangeNotification, object: nil)
        } catch {
            print("Error removing favorite: \(error)")
        }
    }
    
    func isFavorite(_ busRoute: BusRoute) -> Bool {
        let request: NSFetchRequest<BusRouteFavorite> = BusRouteFavorite.fetchRequest()
        request.predicate = NSPredicate(
            format: "stopId == %@ AND route == %@ AND companyId == %@ AND direction == %@",
            busRoute.stopId, busRoute.route, busRoute.companyId, busRoute.direction
        )
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Error checking favorite: \(error)")
            return false
        }
    }
    
    func updateFavoriteOrder(_ favorites: [BusRoute]) {
        let request: NSFetchRequest<BusRouteFavorite> = BusRouteFavorite.fetchRequest()
        
        do {
            let allFavorites = try context.fetch(request)
            
            for (index, busRoute) in favorites.enumerated() {
                if let favorite = allFavorites.first(where: {
                    $0.stopId == busRoute.stopId &&
                    $0.route == busRoute.route &&
                    $0.companyId == busRoute.companyId &&
                    $0.direction == busRoute.direction
                }) {
                    favorite.displayOrder = Int32(index)
                }
            }
            
            saveContext()
        } catch {
            print("Error updating favorite order: \(error)")
        }
    }
    
    func updateFavoriteSubTitle(_ busRoute: BusRoute, newSubTitle: String) {
        let request: NSFetchRequest<BusRouteFavorite> = BusRouteFavorite.fetchRequest()
        request.predicate = NSPredicate(
            format: "stopId == %@ AND route == %@ AND companyId == %@ AND direction == %@",
            busRoute.stopId, busRoute.route, busRoute.companyId, busRoute.direction
        )
        
        do {
            let favorites = try context.fetch(request)
            favorites.first?.subTitle = newSubTitle
            saveContext()
        } catch {
            print("Error updating favorite subtitle: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeDefaultFavoritesIfNeeded() {
        let request: NSFetchRequest<BusRouteFavorite> = BusRouteFavorite.fetchRequest()
        
        do {
            let count = try context.count(for: request)
            if count == 0 {
                // Add default routes as favorites
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
                saveContext()
            }
        } catch {
            print("Error initializing default favorites: \(error)")
        }
    }
    
    private func getNextDisplayOrder() -> Int {
        let request: NSFetchRequest<BusRouteFavorite> = BusRouteFavorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "displayOrder", ascending: false)]
        request.fetchLimit = 1
        
        do {
            let favorites = try context.fetch(request)
            return Int(favorites.first?.displayOrder ?? -1) + 1
        } catch {
            return 0
        }
    }
    
    private func saveContext() {
        coreDataStack.saveContext()
    }
}