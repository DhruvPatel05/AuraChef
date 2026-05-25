//
//  RecipeWizardView.swift
//  AuraChef
//
//  Created by Dhruv Patel on 25/05/26.
//

import SwiftUI

struct RecipeWizardView: View {
    let recipe: CookableRecipe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Cook time panel
                    HStack {
                        Label("\(recipe.prepTimeMinutes + recipe.cookTimeMinutes) mins total", systemImage: "clock")
                            .font(.headline)
                            .foregroundColor(.auraSage)
                        Spacer()
                        if !recipe.allergensPresent.isEmpty {
                            Label("Allergens", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundColor(.auraApricot)
                        }
                    }
                    .padding()
                    .background(Color.auraSage.opacity(0.08))
                    .cornerRadius(10)
                    
                    Text("Cooking Steps")
                        .font(.title2.bold())
                        .foregroundColor(.auraCharcoal)
                    
                    ForEach(Array(recipe.steps.enumerated()), id: \.element) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.auraSage)
                                .clipShape(Circle())
                            
                            Text(step)
                                .font(.body)
                                .foregroundColor(.auraCharcoal)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
            .background(Color.auraCream.ignoresSafeArea())
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.auraSage)
                }
            }
        }
    }
}
