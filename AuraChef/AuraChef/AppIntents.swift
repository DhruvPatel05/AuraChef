
//
//  Untitled.swift
//  AppIntents
//
//  Created by Dhruv Patel on 25/05/26.
//
import Foundation
import AppIntents
import SwiftUI

// MARK: - Core Intent Discovery
struct ScanPantryIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Ingredients with AuraChef"
    static var description = IntentDescription("Launches the live camera scanner inside AuraChef to instantly track your kitchen items.")
    
    // Forces the app to open and come into the foreground when triggered via Siri or Shortcuts
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesNavigation {
        // Deep-link intent state execution: we request the system to open our primary view hierarchy context
        return .result(opensIntent: OpenPantryCameraIntent())
    }
}

// MARK: - Background Navigation Deep-Link Handler
struct OpenPantryCameraIntent: OpenIntent {
    static var title: LocalizedStringResource = "Open AuraChef Scanner"
    
    @Parameter(title: "Target Screen")
    var target: AppScreen
    
    init() {
        self.target = .cameraScanner
    }
}

enum AppScreen: String, AppEnum {
    case dashboard
    case cameraScanner
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "App Screen Navigation Targets"
    static var caseDisplayRepresentations: [AppScreen: DisplayRepresentation] = [
        .dashboard: "Main Dashboard View",
        .cameraScanner: "Live Camera Scanner View"
    ]
}

// MARK: - Shortcuts & Siri Vocal Command Registry
struct AuraChefShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanPantryIntent(),
            phrases: [
                "Scan my pantry with \(.applicationName)",
                "Look at my ingredients in \(.applicationName)",
                "Open the camera in \(.applicationName)"
            ],
            shortTitle: "Scan Ingredients",
            systemImageName: "camera.circle"
        )
    }
}
