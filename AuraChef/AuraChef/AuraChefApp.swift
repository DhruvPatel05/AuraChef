//
//  AuraChefApp.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import SwiftUI
import SwiftData

@main
struct AuraChefApp: App {
    @State private var scanTriggerRequested = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.absoluteString.contains("cameraScanner") {
                        scanTriggerRequested = true
                    }
                }
        }
        .modelContainer(PantryDataContainer.shared)
    }
}

// Add this color asset mapping extension to resolve compilation errors
extension Color {
    static let auraSage = Color(hex: "#2C5E43")
    static let auraApricot = Color(hex: "#F4A261")
    static let auraCream = Color(hex: "#FAF8F5")
    static let auraCharcoal = Color(hex: "#1A1D1A")
    
    // Hex Color Processing Engine
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 1, 1, 1)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
