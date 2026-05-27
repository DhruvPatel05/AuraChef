//
//  IngredientSelectionView.swift
//  AuraChef
//
//  Created by Dhruv Patel on 26/05/26.
//

import SwiftUI
import SwiftData

struct IngredientSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    
    // RENAMED: Changed to a completely unique name to break any hidden shadowing loops
//    @State private var checkedIngredientIDs = Set<UUID>()
    @State private var checkedIngredientIDs = Set<PantryItem.ID>()
    @State private var navigateToRecipe = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("What are we cooking with?")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                
                if pantryItems.isEmpty {
                    ContentUnavailableView(
                        "Your Pantry is Empty",
                        systemImage: "basket",
                        description: Text("Go back to the dashboard and scan some ingredients first!")
                    )
                } else {
                    // Force the List to strictly bind to your SwiftData model types
                    List(pantryItems) { (item: PantryItem) in
                        HStack {
                            Text(item.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Checkbox Graphic Toggles
                            Image(systemName: checkedIngredientIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(checkedIngredientIDs.contains(item.id) ? .accentColor : .gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let targetedID = item.id
                            if checkedIngredientIDs.contains(targetedID) {
                                checkedIngredientIDs.remove(targetedID)
                            } else {
                                checkedIngredientIDs.insert(targetedID)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    if !checkedIngredientIDs.isEmpty {
                        navigateToRecipe = true
                    }
                }) {
                    Text("Generate Custom Recipe (\(checkedIngredientIDs.count))")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(checkedIngredientIDs.isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(12)
                }
                .disabled(checkedIngredientIDs.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Select Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToRecipe) {
                let chosenNames = pantryItems
                    .filter { checkedIngredientIDs.contains($0.id) }
                    .map { $0.name }
                
                RecipeGenerationView(ingredients: chosenNames)
            }
        }
    }
}
