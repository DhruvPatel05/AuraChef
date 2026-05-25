//
//  PantryDashboardView.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import SwiftUI
import SwiftData
import FoundationModels

struct PantryDashboardView: View {
    // Native SwiftData macro queries tracking data state directly
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var preferences: [UserPreferences]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    // UI State Management Envelopes
    @State private var isScanning = false
    @State private var activeScanningTask: Task<Void, Never>? = nil
    @State private var generatedRecipe: CookableRecipe? = nil
    @State private var isGeneratingRecipe = false
    @State private var cameraTokens: Set<String> = []
    
    // Fallback Mock Preferences instance if SwiftData isn't populated yet
    private var currentUserPreferences: UserPreferences {
        preferences.first ?? UserPreferences()
    }
    
    var body: some View {
        NavigationStack {
            ZCoreMainLayout
                .navigationTitle("AuraChef")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: toggleScanning) {
                            Image(systemName: isScanning ? "camera.circle.fill" : "camera.circle")
                                .font(.title2)
                                .foregroundColor(.auraSage)
                        }
                        .accessibilityLabel(isScanning ? "Stop scanning pantry" : "Scan pantry with camera")
                    }
                }
                .sheet(item: $generatedRecipe) { recipe in
                    RecipeWizardView(recipe: recipe)
                }
        }
    }
    
    // MARK: - Layout Hierarchy Switch
    @ViewBuilder
    private var ZCoreMainLayout: some View {
        VStack(spacing: 0) {
            if isScanning {
                CameraStreamOverlayView
                    .frame(height: 220)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if pantryItems.isEmpty && cameraTokens.isEmpty {
                EmptyStateLayoutView
            } else {
                // Adaptive layout matrix driven by Environment Text Scaling
                if dynamicTypeSize.isAccessibilitySize || currentUserPreferences.forceLargeTextLayout {
                    ScrollView {
                        VStack(spacing: 16) {
                            PantryItemsSectionLayout
                            GenerationTriggerButtonLayout
                        }
                        .padding()
                    }
                } else {
                    // Regular grid layout for normal vision profiles
                    VStack(spacing: 0) {
                        PantryItemsGridSelectionLayout
                        GenerationTriggerButtonLayout
                            .padding()
                    }
                }
            }
        }
        .background(Color.auraCream.ignoresSafeArea())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isScanning)
    }
    
    // MARK: - Subviews & Layout Modules
    private var CameraStreamOverlayView: some View {
        ZStack {
            Color.black
            Text("Scanning Fridge & Shelves...")
                .font(.subheadline)
                .foregroundColor(.white)
            
            // Render detected tokens horizontally above the layout stream
            VStack {
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(cameraTokens), id: \.self) { token in
                            Text(token)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.auraSage)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    private var EmptyStateLayoutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "refrigerator")
                .font(.system(size: 64))
                .foregroundColor(.auraSage.opacity(0.6))
            Text("Your pantry is empty")
                .font(.title3.bold())
                .foregroundColor(.auraCharcoal)
            Text("Tap the camera icon above to scan your ingredients without typing.")
                .font(.callout)
                .foregroundColor(.auraCharcoal.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var PantryItemsSectionLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Inventory")
                .font(.headline)
                .foregroundColor(.auraCharcoal)
            
            let itemsToDisplay = cameraTokens.isEmpty ? pantryItems.map { $0.name } : Array(cameraTokens)
            ForEach(itemsToDisplay, id: \.self) { itemName in
                HStack {
                    Text(itemName.capitalized)
                        .font(.body.bold())
                        .foregroundColor(.auraCharcoal)
                    Spacer()
                    Button(action: { removeTokenOrItem(itemName) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    private var PantryItemsGridSelectionLayout: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                let itemsToDisplay = cameraTokens.isEmpty ? pantryItems.map { $0.name } : Array(cameraTokens)
                ForEach(itemsToDisplay, id: \.self) { itemName in
                    VStack(alignment: .leading) {
                        Text(itemName.capitalized)
                            .font(.body)
                            .foregroundColor(.auraCharcoal)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                }
            }
            .padding()
        }
    }
    
    private var GenerationTriggerButtonLayout: some View {
        Button(action: processPantryWithAppleIntelligence) {
            HStack {
                if isGeneratingRecipe {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                Text(isGeneratingRecipe ? "AuraChef is thinking..." : "Generate Magic Recipe")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background((pantryItems.isEmpty && cameraTokens.isEmpty) || isGeneratingRecipe ? Color.gray : Color.auraSage)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(pantryItems.isEmpty && cameraTokens.isEmpty || isGeneratingRecipe)
    }
    
    // MARK: - Intent & Execution Processing
    private func toggleScanning() {
        if isScanning {
            isScanning = false
            activeScanningTask?.cancel()
            activeScanningTask = nil
            // Commit cameraTokens down to permanent SwiftData layer
            for token in cameraTokens {
                let newItem = PantryItem(name: token)
                modelContext.insert(newItem)
            }
            try? modelContext.save()
        } else {
            cameraTokens.removeAll()
            isScanning = true
            
            // Spawn concurrent observation consumer task pulling data stream frames
            activeScanningTask = Task {
                do {
                    let tokenStream = await VisionService.shared.startScanning()
                    for try await tokens in tokenStream {
                        // Batch insert items uniquely into current session set
                        await MainActor.run {
                            for token in tokens where token.count > 2 {
                                self.cameraTokens.insert(token.lowercased())
                            }
                        }
                    }
                } catch {
                    print("Stream failed or cancelled: \(error)")
                }
            }
        }
    }
    
    private func removeTokenOrItem(_ name: String) {
        if isScanning {
            cameraTokens.remove(name)
        } else {
            if let index = pantryItems.firstIndex(where: { $0.name == name }) {
                modelContext.delete(pantryItems[index])
                try? modelContext.save()
            }
        }
    }
    
    private func processPantryWithAppleIntelligence() {
        isGeneratingRecipe = true
        let ingredientsToProcess = cameraTokens.isEmpty ? pantryItems.map { $0.name } : Array(cameraTokens)
        
        Task {
            do {
                let aiService = await AIService.shared
                let recipeResult = try await aiService.craftRecipe(
                    from: ingredientsToProcess,
                    lowSodium: currentUserPreferences.isLowSodium,
                    restrictedAllergens: currentUserPreferences.allergens
                )
                
                await MainActor.run {
                    self.isGeneratingRecipe = false
                    self.generatedRecipe = recipeResult
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingRecipe = false
                    print("Generation pipeline failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Supplementary Sheet Layout Identifiable Struct
extension CookableRecipe: Identifiable {
    public var id: String { title }
}
