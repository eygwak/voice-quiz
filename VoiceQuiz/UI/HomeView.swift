//
//  HomeView.swift
//  VoiceQuiz
//
//  Home screen with mode selection and category selection
//

import SwiftUI

struct HomeView: View {
    @State private var selectedMode: GameMode?
    @State private var showingHistory = false

    var body: some View {
        NavigationStack {
            if let mode = selectedMode {
                CategorySelectionView(selectedMode: mode, onBack: {
                    selectedMode = nil
                })
            } else {
                ModeSelectionView(
                    onModeSelected: { mode in
                        selectedMode = mode
                    },
                    onHistoryTapped: {
                        showingHistory = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingHistory) {
            GameHistoryView()
        }
    }
}

// MARK: - Mode Selection View

struct ModeSelectionView: View {
    let onModeSelected: (GameMode) -> Void
    let onHistoryTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 60)

                Text("VoiceQuiz")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.blue)

                Text("Choose Your Game Mode")
                    .font(.title3)
                    .foregroundColor(Color(white: 0.3))
            }
            .padding(.bottom, 40)

            Spacer()

            // Mode Cards
            VStack(spacing: 20) {
                ModeCard(
                    title: "You Guess",
                    subtitle: "AI describes, you guess the word",
                    icon: "brain.head.profile",
                    color: .blue
                ) {
                    onModeSelected(.modeA)
                }

                ModeCard(
                    title: "You Describe",
                    subtitle: "You describe, AI guesses the word",
                    icon: "person.wave.2.fill",
                    color: .purple
                ) {
                    onModeSelected(.modeB)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // History Button
            Button {
                onHistoryTapped()
            } label: {
                HStack {
                    Image(systemName: "clock.fill")
                    Text("Game History")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.primary)
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white.ignoresSafeArea())
    }
}

// MARK: - Category Selection View

struct CategorySelectionView: View {
    let selectedMode: GameMode
    let onBack: () -> Void

    @State private var selectedCategoryId: String = "food"
    @State private var categories: [Category] = []
    @State private var navigateToGame = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Title
            VStack(spacing: 12) {
                Text(selectedMode == .modeA ? "You Guess" : "You Describe")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(selectedMode == .modeA ? .blue : .purple)

                Text("Choose a Category")
                    .font(.title3)
                    .foregroundColor(selectedMode == .modeA ? .blue : .purple)
            }
            .padding(.bottom, 30)

            // Category Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(categories) { category in
                        CategoryCard(
                            category: category,
                            isSelected: selectedCategoryId == category.id,
                            modeColor: selectedMode == .modeA ? .blue : .purple
                        ) {
                            selectedCategoryId = category.id
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            // Start Button
            Button {
                navigateToGame = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Start Game")
                        .font(.system(size: 18, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(selectedMode == .modeA ? Color.blue : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: (selectedMode == .modeA ? Color.blue : Color.purple).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white.ignoresSafeArea())
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

// MARK: - Mode Card

struct ModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.3))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: Category
    let isSelected: Bool
    let modeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: categoryIcon(for: category.id))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(isSelected ? .white : modeColor)
                    .frame(height: 40)

                Text(category.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : modeColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? modeColor : Color.white)
            .cornerRadius(16)
            .shadow(
                color: isSelected ? modeColor.opacity(0.3) : Color.black.opacity(0.06),
                radius: isSelected ? 8 : 6,
                x: 0,
                y: isSelected ? 4 : 2
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
        case "places":
            return "mappin.and.ellipse"
        case "actions":
            return "figure.walk"
        case "emotions":
            return "face.smiling.fill"
        case "sports":
            return "sportscourt.fill"
        case "nature":
            return "cloud.sun.fill"
        case "minecraft":
            return "gamecontroller.fill"
        default:
            return "star.fill"
        }
    }
}

#Preview {
    HomeView()
}
