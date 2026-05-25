//
//  AuraChefTests.swift
//  AuraChefTests
//
//  Created by Dhruv Patel on 25/05/26.
//

import Testing
import Foundation
import SwiftData
@testable import AuraChef

@Suite("AuraChef Core Engine Metrics")
struct AuraChefTests {
    
    // MARK: - Stage 1: Data Model Assertions
    @Test("Verify PantryItem string trimming and normalization constraints")
    func testPantryItemNormalization() async throws {
        // Given raw text payloads captured by the camera stream containing messy spaces and case variations
        let messyInputName = "   ORGANIC Free-Range Chicken Breast   "
        
        // When initialized into our SwiftData Model
        let item = PantryItem(name: messyInputName, approximateDaysLeft: 5)
        
        // Then assert data cleaners transformed the string into standard baseline data shapes
        #expect(item.name == "organic free-range chicken breast")
        #expect(item.approximateDaysLeft == 5)
        #expect(item.id.isEmpty == false)
    }
    
    // MARK: - Stage 1: SwiftData Stack In-Memory Concurrency Isolation Tests
    @Test("Verify local data store mutations remain safe and crash-free using isolated configurations")
    @MainActor
    func testSwiftDataContainerLifecycle() async throws {
        // Setup transient, isolated in-memory container configuration to ensure unit tests do not pollute user device disks
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PantryItem.self, configurations: configuration)
        let context = container.mainContext
        
        // Given isolated state
        let testIngredient = PantryItem(name: "spinach")
        
        // When inserting record updates down into context tracks
        context.insert(testIngredient)
        try context.save()
        
        // Then query context bounds to verify persistent mutation state exists accurately
        let fetchDescriptor = FetchDescriptor<PantryItem>()
        let items = try context.fetch(fetchDescriptor)
        
        #expect(items.count == 1)
        #expect(items.first?.name == "spinach")
    }
    
    // MARK: - Stage 2/3: Token Array Filtering & Validation
        @Test("Verify empty or short tokens drop out safely before being dispatched to Apple Intelligence parameters")
        func testTokenFilteringLogic() async throws {
            // Given raw OCR candidate arrays that might match noise artifacts
            let noisyRawCapturedTokens = ["egg", "a", "tomato", "   ", "chickn bst", "x"]
            
            // When applying the app's minimal length logic (length > 2 and stripped of spaces)
            let filteredTokens = noisyRawCapturedTokens
                .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 2 }
                
            // Then assert trivial artifacts drop out cleanly (Expected count: 3)
            #expect(filteredTokens.count == 3) // <-- FIXED FROM 4 TO 3
            #expect(filteredTokens.contains("egg"))
            #expect(filteredTokens.contains("tomato"))
            #expect(filteredTokens.contains("chickn bst"))
            #expect(!filteredTokens.contains("a"))
            #expect(!filteredTokens.contains("x"))
        }
}
