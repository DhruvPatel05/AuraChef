//
//  ContentView.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        // Swap out the default Apple sample project template
        // and instantly render your custom AI engine dashboard.
        PantryDashboardView()
    }
}

#Preview {
    ContentView()
        // Injects an in-memory test container mapping your custom schema
        // shapes so your Xcode canvas previews render flawlessly.
        .modelContainer(for: [PantryItem.self, UserPreferences.self, SavedRecipe.self], inMemory: true)
}
