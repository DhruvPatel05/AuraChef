//
//  Untitled.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import Foundation
import FoundationModels

/// Type-safe model representing the exact structured recipe shape enforced via Guided Generation.
/// The @Generable macro guarantees that the on-device LLM will only populate these exact parameters.
@Generable
struct CookableRecipe: Codable, Sendable {
    @Guide(description: "A short, appetizing name for the recipe matching the input ingredients.")
    let title: String
    
    @Guide(description: "Estimated preparation time in minutes.")
    let prepTimeMinutes: Int
    
    @Guide(description: "Estimated actual cooking time in minutes.")
    let cookTimeMinutes: Int
    
    @Guide(description: "Chronological list of step-by-step cooking commands. Keep them crisp and clear.")
    let steps: [String]
    
    @Guide(description: "Any immediate allergens identified in the input ingredients (e.g., Peanut, Gluten, Dairy).")
    let allergensPresent: [String]
}

@globalActor
actor AIOrchestrationActor {
    static let shared = AIOrchestrationActor()
}

@AIOrchestrationActor
final class AIService {
    
    static let shared = AIService()

    private var session: LanguageModelSession?
    
    init() {
        // Pre-warming the model context ensures it is eagerly loaded into memory,
        // eliminating the initial 2-3 second latency lag when the user first triggers a scan.
        Task {
            guard SystemLanguageModel.default.isAvailable else { return }
            self.session = LanguageModelSession(model: SystemLanguageModel.default)
            try? await self.session?.prewarm()
        }
    }
    
    /// Orchestrates on-device inference using input ingredients filtered by historical dietary profiles
    func craftRecipe(from ingredients: [String], lowSodium: Bool, restrictedAllergens: [String]) async throws -> CookableRecipe {
        // Fallback check to ensure Apple Intelligence is active and accessible on the hardware
        guard SystemLanguageModel.default.isAvailable else {
            throw AIContextError.systemModelUnavailable
        }
        
        let currentSession = session ?? LanguageModelSession(model: SystemLanguageModel.default)
        if session == nil { self.session = currentSession }
        
        let inventoryList = ingredients.joined(separator: ", ")
        let sodiumRule = lowSodium ? "CRITICAL RULE: The recipe must be entirely low sodium. Do not include table salt or sodium-heavy sauces." : ""
        let allergenRule = !restrictedAllergens.isEmpty ? "EXCLUDE THESE ALLERGENS ABSOLUTELY: \(restrictedAllergens.joined(separator: ", "))." : ""
        
        let promptTemplate = """
        You are the backend engine of AuraChef, an elite culinary architect.
        Analyze this raw refrigerator array: [\(inventoryList)].
        
        \(sodiumRule)
        \(allergenRule)
        
        Generate a unique, optimized recipe that maximizes use of these items.
        """
        
        do {
            // Type-safe structured execution via Guided Generation.
            // This natively bypasses raw string parsing entirely.
            let response = try await currentSession.respond(generating: CookableRecipe.self) {
                Prompt(promptTemplate)
            }
            
            // The content parameter is natively mapped directly back into our CookableRecipe struct
            return response.content
            
        } catch {
            print("On-Device Generation Fault: \(error.localizedDescription)")
            throw AIContextError.generationFailed
        }
    }
}

enum AIContextError: Error {
    case systemModelUnavailable
    case generationFailed
}
