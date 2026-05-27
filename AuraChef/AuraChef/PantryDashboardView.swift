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
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var preferences: [UserPreferences]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var isScanning = false
    @State private var activeScanningTask: Task<Void, Never>? = nil
    @State private var generatedRecipe: CookableRecipe? = nil
    @State private var isGeneratingRecipe = false
    
    @State private var cameraTokens: Set<String> = []
    @State private var streamTokensBuffer: Set<String> = []
    @State private var hasCapturedSnapshot = false
    
    // NEW: Duplicate Alert Handling States
    @State private var showDuplicateAlert = false
    @State private var duplicateItemName = ""
    @State private var pendingTokensToProcess: [String] = []
    @State private var isCleaningTextName = false
    private var currentUserPreferences: UserPreferences {
        preferences.first ?? UserPreferences()
    }
    
    var body: some View {
            NavigationStack {
                ZCoreMainLayout
                    .navigationTitle("AuraChef")
                    .toolbar {
                        // Left Side: Navigate to your brand-new selection checklist screen
                        ToolbarItem(placement: .topBarLeading) {
                            NavigationLink(destination: IngredientSelectionView()) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.title3)
                                    .foregroundColor(.auraSage)
                            }
                        }
                        
                        // Right Side: Camera Toggle Button (Kept intact)
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: toggleScanning) {
                                Image(systemName: isScanning ? "xmark.circle.fill" : "camera.circle")
                                    .font(.title2)
                                    .foregroundColor(.auraSage)
                            }
                        }
                    }
                    .sheet(item: $generatedRecipe) { recipe in
                        RecipeWizardView(recipe: recipe)
                    }
                    // Alert intercepting duplicates during processing loops
                    .alert("Item Already Present", isPresented: $showDuplicateAlert) {
                        Button("Add One More (+1)") {
                            incrementExistingItemQuantity(named: duplicateItemName)
                            processNextPendingToken()
                        }
                        Button("Skip", role: .cancel) {
                            processNextPendingToken()
                        }
                    } message: {
                        Text("'\(duplicateItemName.capitalized)' is already in your pantry. Would you like to increase its quantity?")
                    }
            }
        }
    
    
    @ViewBuilder
    private var ZCoreMainLayout: some View {
        VStack(spacing: 0) {
            if isScanning {
                CameraStreamOverlayView
                    .frame(height: 280)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if pantryItems.isEmpty && cameraTokens.isEmpty {
                EmptyStateLayoutView
            } else {
                VStack(spacing: 0) {
                    // Always show structured list row layouts for uniform counter access
                    PantryItemsListLayout
                    GenerationTriggerButtonLayout
                        .padding()
                }
            }
        }
        .background(Color.auraCream.ignoresSafeArea())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isScanning)
    }
    
    // MARK: - Live Camera Viewfinder Layer
        private var CameraStreamOverlayView: some View {
            ZStack {
                // FIXED: Swapped out Color.black for your live camera hardware viewfinder view!
                CameraPreviewView()
                    .ignoresSafeArea()
                    .cornerRadius(16)
                    .padding(.horizontal)
                
                // Subtle dark gradient mask across the top so white overlay text stays readable over light foods
                VStack {
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 60)
                    Spacer()
                }
                .padding(.horizontal)
                .allowsHitTesting(false)
                
                if !hasCapturedSnapshot {
                    Text("Align your ingredients...")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.bottom, 60)
                } else {
                    VStack(spacing: 8) {
                        Text("Captured Items (Review Below)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.auraApricot)
                            .cornerRadius(6)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(cameraTokens), id: \.self) { token in
                                    Text(token.capitalized)
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
                    }
                    .padding(.bottom, 60)
                }
                
                // Floating Shutter Controls HUD
                VStack {
                    Spacer()
                    HStack {
                        if !hasCapturedSnapshot {
                            Button(action: captureCurrentFrameSnapshot) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 54, height: 54)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                            .frame(width: 48, height: 48)
                                    )
                            }
                        } else {
                            Button(action: resetCameraScanSequence) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Retake")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            Button(action: acceptCapturedSnapshotAndClose) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Add to Pantry")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.auraSage)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - UPDATED: Clean List View with SF Symbols & Quantity Counter Controls
    private var PantryItemsListLayout: some View {
        List {
            ForEach(pantryItems) { item in
                HStack(spacing: 12) {
                    // Display descriptive contextual icon along with name text fields
                    Image(systemName: guessBestIcon(for: item.name))
                        .foregroundColor(.auraSage)
                        .font(.title3)
                        .frame(width: 30, alignment: .center)
                    
                    Text(item.name.capitalized)
                        .font(.body.bold())
                        .foregroundColor(.auraCharcoal)
                    
                    Spacer()
                    
                    // Quantity Adjustment Stepper Module
                    HStack(spacing: 14) {
                        Button(action: { decrementQuantity(of: item) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(item.quantity)")
                            .font(.body.bold())
                            .frame(minWidth: 24, alignment: .center)
                        
                        Button(action: { item.quantity += 1; try? modelContext.save() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.auraSage)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGroupedBackground))
                    .clipShape(Capsule())
                }
                .listRowBackground(Color.white)
            }
            .onDelete(perform: removeDatabaseItemDirectly)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var GenerationTriggerButtonLayout: some View {
        Button(action: processPantryWithAppleIntelligence) {
            HStack {
                if isGeneratingRecipe {
                    ProgressView().tint(.white).padding(.trailing, 8)
                }
                Text(isGeneratingRecipe ? "AuraChef is thinking..." : "Generate Magic Recipe").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(pantryItems.isEmpty || isGeneratingRecipe ? Color.gray : Color.auraSage)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(pantryItems.isEmpty || isGeneratingRecipe)
    }
    
    // MARK: - Core Logic Extensions
    
    private func toggleScanning() {
        if isScanning {
            deactivateCameraSession()
        } else {
            hasCapturedSnapshot = false
            cameraTokens.removeAll()
            streamTokensBuffer.removeAll()
            isScanning = true
            
            activeScanningTask = Task {
                do {
                    let tokenStream = await VisionService.shared.startScanning()
                    for try await tokens in tokenStream {
                        await MainActor.run {
                            for token in tokens where token.count > 2 {
                                self.streamTokensBuffer.insert(token.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                        }
                    }
                } catch {
                    print("Stream closed")
                }
            }
        }
    }
    
    private func captureCurrentFrameSnapshot() {
            let rawCapturedTokens = Array(streamTokensBuffer)
            
            // 1. Freeze and turn off the hardware camera sensor immediately
            activeScanningTask?.cancel()
            activeScanningTask = nil
            
            let currentFrameBuffer = VisionService.shared.currentSampleBuffer
            Task { await VisionService.shared.stopScanning() }
            
            hasCapturedSnapshot = true
            isCleaningTextName = true
            
            // 2. Start our unified photo triage decision execution pipeline
            Task {
                let aiService = await AIService.shared
                var finalDetectedItemName = ""
                
                if let sampleBuffer = currentFrameBuffer {
                    
                    // STEP 1: Look for Barcodes first
                    if let barcodePayload = await VisionService.shared.scanBarcodeInFrame(sampleBuffer) {
                        if let onlineMatchName = await VisionService.shared.fetchProductNameFromWeb(barCode: barcodePayload) {
                            finalDetectedItemName = onlineMatchName
                        }
                    }
                    
                    // STEP 2: Fallback to Labeled OCR Text if no barcode matches
                    if finalDetectedItemName.isEmpty && !rawCapturedTokens.isEmpty {
                        finalDetectedItemName = await aiService.extractMainItemName(from: rawCapturedTokens)
                    }
                    
                    // STEP 3: Fallback to Object Shape Classification (Fresh Fruits/Vegetables/Eggs)
                    if finalDetectedItemName.isEmpty {
                        if let visualMatch = await VisionService.shared.classifyImageFrame(sampleBuffer) {
                            finalDetectedItemName = visualMatch
                                .replacingOccurrences(of: "_", with: " ")
                                .capitalized
                        }
                    }
                }
                
                // Absolute baseline fallback safety wrapper
                if finalDetectedItemName.isEmpty {
                    finalDetectedItemName = "Scanned Item"
                }
                
                await MainActor.run {
                    // Display the single winner result on the screen inside our review capsule view
                    self.cameraTokens = [finalDetectedItemName]
                    self.isCleaningTextName = false
                }
            }
        }
    private func resetCameraScanSequence() {
        hasCapturedSnapshot = false
        cameraTokens.removeAll()
        streamTokensBuffer.removeAll()
        toggleScanning()
    }
    
    // MARK: - UPDATED: Safe Token Insertion Sequencing Engine
    private func acceptCapturedSnapshotAndClose() {
        // Enqueue verified camera snapshot array tokens into clean staging list
        pendingTokensToProcess = Array(cameraTokens)
        deactivateCameraSession()
        
        // Kick off recursive evaluation runner check
        processNextPendingToken()
    }
    
    private func processNextPendingToken() {
        guard !pendingTokensToProcess.isEmpty else { return }
        
        let currentToken = pendingTokensToProcess.removeFirst()
        
        // Scan standard context indices to look for an exact name match
        if let existingItem = pantryItems.first(where: { $0.name == currentToken }) {
            // Found a duplicate item: Pause loop sequence execution, trigger alert modal dialog
            duplicateItemName = currentToken
            showDuplicateAlert = true
        } else {
            // Safe clean record node item creation: insert entry directly
            let newItem = PantryItem(name: currentToken)
            modelContext.insert(newItem)
            try? modelContext.save()
            
            // Loop step callback to process any remaining tokens
            processNextPendingToken()
        }
    }
    
    private func incrementExistingItemQuantity(named name: String) {
        if let match = pantryItems.first(where: { $0.name == name }) {
            match.quantity += 1
            try? modelContext.save()
        }
    }
    
    private func decrementQuantity(of item: PantryItem) {
        if item.quantity > 1 {
            item.quantity -= 1
        } else {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
    
    private func removeDatabaseItemDirectly(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(pantryItems[index])
        }
        try? modelContext.save()
    }
    
    private func deactivateCameraSession() {
        isScanning = false
        hasCapturedSnapshot = false
        activeScanningTask?.cancel()
        activeScanningTask = nil
        Task { await VisionService.shared.stopScanning() }
    }
    
    /// Helper helper utility mapping item text categories onto beautiful system SF Symbols automatically
    private func guessBestIcon(for name: String) -> String {
        let cleanName = name.lowercased()
        if cleanName.contains("milk") || cleanName.contains("cheese") || cleanName.contains("yogurt") || cleanName.contains("dairy") { return "drop.milk.fill" }
        if cleanName.contains("chicken") || cleanName.contains("beef") || cleanName.contains("steak") || cleanName.contains("meat") || cleanName.contains("pork") { return "fork.knife" }
        if cleanName.contains("apple") || cleanName.contains("banana") || cleanName.contains("tomato") || cleanName.contains("orange") || cleanName.contains("lemon") || cleanName.contains("fruit") { return "carrot.fill" }
        if cleanName.contains("spinach") || cleanName.contains("salad") || cleanName.contains("lettuce") || cleanName.contains("vegetable") || cleanName.contains("broccoli") { return "leaf.fill" }
        if cleanName.contains("bread") || cleanName.contains("toast") || cleanName.contains("flour") || cleanName.contains("grain") { return "laurel" }
        if cleanName.contains("water") || cleanName.contains("juice") || cleanName.contains("soda") || cleanName.contains("drink") { return "popcorn.fill" }
        return "tag.fill" // Standard fallback icon tag shape
    }
    
    private func processPantryWithAppleIntelligence() {
        isGeneratingRecipe = true
        let ingredientsToProcess = pantryItems.map { "\($0.quantity)x \($0.name)" }
        
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
                }
            }
        }
    }
}

// MARK: - Supplementary Sheet Layout Identifiable Struct
extension CookableRecipe: Identifiable {
    public var id: String { title }
}
