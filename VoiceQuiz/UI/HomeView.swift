//
//  HomeView.swift
//  VoiceQuiz
//
//  Home screen with mode selection and category selection
//

import SwiftUI

struct HomeView: View {
    @State private var selectedMode: GameMode = .modeA
    @State private var selectedCategoryId: String = "food"
    @State private var categories: [Category] = []
    @State private var navigateToGame = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("VoiceQuiz")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Voice-based Speed Quiz")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                Spacer()

                // Mode Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Game Mode")
                        .font(.headline)

                    VStack(spacing: 12) {
                        ModeButton(
                            mode: .modeA,
                            title: "AI Describes",
                            subtitle: "Listen and guess the word",
                            icon: "brain.head.profile",
                            isSelected: selectedMode == .modeA
                        ) {
                            selectedMode = .modeA
                        }

                        ModeButton(
                            mode: .modeB,
                            title: "You Describe",
                            subtitle: "Describe and AI guesses",
                            icon: "person.wave.2.fill",
                            isSelected: selectedMode == .modeB
                        ) {
                            selectedMode = .modeB
                        }
                    }
                }
                .padding(.horizontal)

                // Category Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Category")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories) { category in
                                CategoryChip(
                                    category: category,
                                    isSelected: selectedCategoryId == category.id
                                ) {
                                    selectedCategoryId = category.id
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Start Button
                Button {
                    navigateToGame = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Game")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationDestination(isPresented: $navigateToGame) {
                if selectedMode == .modeA {
                    GameView_ModeA(categoryId: selectedCategoryId)
                } else {
                    GameView_ModeB(categoryId: selectedCategoryId)
                }
            }
            .onAppear {
                loadCategories()
            }
        }
    }

    private func loadCategories() {
        do {
            let wordsData = try WordsLoader.loadWords()
            categories = wordsData.categories
            if let firstCategory = categories.first {
                selectedCategoryId = firstCategory.id
            }
        } catch {
            print("❌ Failed to load categories: \(error)")
        }
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let mode: GameMode
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .frame(width: 50)
                    .foregroundStyle(isSelected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: categoryIcon(for: category.id))
                    .font(.system(size: 30))
                    .foregroundStyle(isSelected ? .blue : .gray)

                Text(category.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }

    private func categoryIcon(for id: String) -> String {
        switch id {
        case "food":
            return "fork.knife"
        case "animals":
            return "pawprint.fill"
        case "jobs":
            return "briefcase.fill"
        case "objects":
            return "cube.fill"
        case "minecraft":
            return "gamecontroller.fill"
        default:
            return "questionmark.circle"
        }
    }
}

#Preview {
    HomeView()
}
