//
//  BusRouteFavorite+CoreDataProperties.swift
//  
//
//  Created by David Wong on 3/9/2025.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension BusRouteFavorite {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BusRouteFavorite> {
        return NSFetchRequest<BusRouteFavorite>(entityName: "BusRouteFavorite")
    }

    @NSManaged public var companyId: String?
    @NSManaged public var direction: String?
    @NSManaged public var displayOrder: Int32
    @NSManaged public var route: String?
    @NSManaged public var stopId: String?
    @NSManaged public var subTitle: String?
    @NSManaged public var dateAdded: Date?

}

extension BusRouteFavorite : Identifiable {

}
