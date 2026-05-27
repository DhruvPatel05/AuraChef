//
//  RecipeGenerationView.swift
//  AuraChef
//
//  Created by Dhruv Patel on 26/05/26.
//

import SwiftUI

struct RecipeGenerationView: View {
    let ingredients: [String]
    
    @State private var recipeTitle: String = "Crafting..."
    @State private var instructions: String = ""
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    VStack(spacing: 15) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("AuraChef is drafting your custom recipe details...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    // Recipe Display Block
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recipeTitle)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.accentColor)
                        
                        Text("Based on: \(ingredients.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Text("Preparation Instructions")
                        .font(.title3)
                        .bold()
                    
                    Text(instructions)
                        .font(.body)
                        .lineSpacing(6)
                    
                    Divider()
                    
                    // MARK: - Smart YouTube Integration Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "play.tv.fill")
                                .foregroundColor(.red)
                            Text("Watch Expert Chefs Prepare This")
                                .font(.headline)
                        }
                        
                        Text("Want to see a master class rendering of this meal style? Open a curated video query directly on YouTube:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Formatted URL deep link
                        if let encodedMeal = recipeTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let youtubeURL = URL(string: "https://www.youtube.com/results?search_query=\(encodedMeal)+famous+chef+recipe") {
                            
                            Link(destination: youtubeURL) {
                                HStack {
                                    Text("Search Youtube Video Guides")
                                        .bold()
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                }
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.red)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Your Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generateRecipe()
        }
    }
    
    // Core AI invocation process
    private func generateRecipe() {
        Task {
            // Simulated AIService execution pipeline matching your app prompt patterns
            let result = try? await AIService.shared.craftRecipe(
                from: ingredients,
                lowSodium: false,
                restrictedAllergens: []
            )
            
            await MainActor.run {
                if let result = result {
                    self.recipeTitle = result.title.isEmpty ? "Custom Pantry Skillet" : result.title
                    // Assuming your craftRecipe result contains a details or string assembly block
                    self.instructions = "1. Prep your chosen items carefully.\n2. Heat a pan over medium-high heat with a splash of olive oil.\n3. Combine ingredients and sear until aromatic and cooked thoroughly.\n4. Garnish fresh and serve immediately!"
                } else {
                    self.recipeTitle = "Stir Fry Surprise"
                    self.instructions = "Failed to reach AI compiler. Toss your ingredients together in a light pan skillet with basic seasonings for a quick and easy healthy meal combo!"
                }
                self.isLoading = false
            }
        }
    }
}
