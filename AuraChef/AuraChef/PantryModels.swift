
//
//  PantryModels.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import Foundation
import SwiftData

@Model
final class UserPreferences {
    var isLowSodium: Bool = false
    var allergens: [String] = []
    var forceLargeTextLayout: Bool = false
    
    init(isLowSodium: Bool = false, allergens: [String] = [], forceLargeTextLayout: Bool = false) {
        self.isLowSodium = isLowSodium
        self.allergens = allergens
        self.forceLargeTextLayout = forceLargeTextLayout
    }
}

@Model
final class PantryItem {
    var id: String = ""
    var name: String = ""
    var dateAdded: Date = Date()
    var approximateDaysLeft: Int = 7
    var quantity: Int = 1 // NEW: Tracks item count
    
    init(name: String, approximateDaysLeft: Int = 7, quantity: Int = 1) {
        self.id = UUID().uuidString
        self.name = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.dateAdded = Date()
        self.approximateDaysLeft = approximateDaysLeft
        self.quantity = quantity
    }
}

@Model
final class SavedRecipe {
    var id: String = ""
    var title: String = ""
    var prepTimeMinutes: Int = 0
    var cookTimeMinutes: Int = 0
    var steps: [String] = []
    var dateSaved: Date = Date()
    
    init(title: String, prepTimeMinutes: Int, cookTimeMinutes: Int, steps: [String]) {
        self.id = UUID().uuidString
        self.title = title
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.steps = steps
        self.dateSaved = Date()
    }
}

@MainActor
struct PantryDataContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            UserPreferences.self,
            PantryItem.self,
            SavedRecipe.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData Container stack: \(error.localizedDescription)")
        }
    }()
}
