//
//  ResultView.swift
//  VoiceQuiz
//
//  Game result screen with score and stats
//

import SwiftUI

struct ResultView: View {
    let mode: GameMode
    let score: Int
    let totalTime: TimeInterval
    let gameSession: GameSession?

    @Environment(\.dismiss) private var dismiss
    @State private var showingConfetti = false
    @State private var navigateToHome = false
    @State private var showingTranscript = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Trophy Icon
            Image(systemName: score > 5 ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 80))
                .foregroundStyle(score > 5 ? .yellow : .blue)
                .scaleEffect(showingConfetti ? 1.2 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatCount(3), value: showingConfetti)

            // Title
            Text(score > 8 ? "Excellent!" : score > 5 ? "Good Job!" : "Nice Try!")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Score Card
            VStack(spacing: 20) {
                // Score
                VStack(spacing: 8) {
                    Text("Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("\(score)")
                            .font(.system(size: 60, weight: .bold))
                            .monospacedDigit()
                    }
                }

                Divider()

                // Stats
                HStack(spacing: 40) {
                    StatItem(
                        icon: "timer",
                        title: "Time",
                        value: "\(Int(totalTime))s"
                    )

                    StatItem(
                        icon: mode == .modeA ? "brain.head.profile" : "person.wave.2.fill",
                        title: "Mode",
                        value: mode.displayName
                    )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal)

            Spacer()

            // Buttons
            VStack(spacing: 16) {
                // View Transcript Button (Mode B only)
                if mode == .modeB, let session = gameSession {
                    Button {
                        showingTranscript = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("View Transcript")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                // Play Again Button
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Play Again")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Home Button
                Button {
                    navigateToHome = true
                } label: {
                    HStack {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToHome) {
            HomeView()
                .navigationBarBackButtonHidden(true)
        }
        .sheet(isPresented: $showingTranscript) {
            if let session = gameSession {
                TranscriptView(gameSession: session)
            }
        }
        .onAppear {
            showingConfetti = true
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Transcript View

struct TranscriptView: View {
    let gameSession: GameSession
    @Environment(\.dismiss) private var dismiss

    @State private var correction: String?
    @State private var isLoadingCorrection = false
    @State private var correctionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // SECTION 1: Word List with Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Words")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(gameSession.words) { wordResult in
                                HStack {
                                    // Word
                                    Text(wordResult.word)
                                        .font(.body)
                                        .fontWeight(.medium)

                                    Spacer()

                                    // Status badge
                                    Text(statusText(wordResult))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(judgmentColor(wordResult.judgment))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // SECTION 2: Full Transcript
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Description")
                            .font(.headline)
                            .padding(.horizontal)

                        if gameSession.fullTranscript.isEmpty {
                            Text("(No transcript recorded)")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .italic()
                                .padding(.horizontal)
                        } else {
                            Text(gameSession.fullTranscript)
                                .font(.body)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }

                    Divider()
                        .padding(.horizontal)

                    // SECTION 3: English Correction
                    VStack(alignment: .leading, spacing: 12) {
                        Text("English Correction")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            if isLoadingCorrection {
                                // Loading state
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Getting AI response...")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let error = correctionError {
                                // Error state
                                Text("Failed to get correction: \(error)")
                                    .font(.body)
                                    .foregroundStyle(.red)
                            } else if let correctionText = correction {
                                // Success state
                                Text(correctionText)
                                    .font(.body)
                            } else {
                                // No correction yet
                                Text("No correction available")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Game Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCorrection()
            }
        }
    }

    private func loadCorrection() {
        // Check if correction already exists (cached)
        if let existingCorrection = gameSession.correction {
            correction = existingCorrection
            return
        }

        // Only request correction if transcript is not empty
        guard !gameSession.fullTranscript.isEmpty else {
            correctionError = "No transcript available"
            return
        }

        // Extract word strings from WordResult array
        let words = gameSession.words.map { $0.word }

        // Request correction from API
        isLoadingCorrection = true
        correctionError = nil

        Task {
            do {
                let correctionText = try await APIClient.shared.requestCorrection(
                    transcript: gameSession.fullTranscript,
                    words: words
                )

                await MainActor.run {
                    self.correction = correctionText
                    self.isLoadingCorrection = false

                    // Save correction to storage
                    GameHistoryStorage.shared.updateSessionCorrection(
                        sessionId: gameSession.id,
                        correction: correctionText
                    )
                }
            } catch {
                await MainActor.run {
                    self.correctionError = error.localizedDescription
                    self.isLoadingCorrection = false
                }
            }
        }
    }

    private func statusText(_ wordResult: WordResult) -> String {
        if wordResult.isCorrect {
            return "Correct"
        } else if wordResult.passed {
            return "Passed"
        } else if wordResult.judgment == "penalty" {
            return "Penalty"
        } else {
            return "Incorrect"
        }
    }

    private func judgmentColor(_ judgment: String?) -> Color {
        switch judgment {
        case "correct": return .green
        case "penalty": return .red
        case "passed": return .orange
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        ResultView(mode: .modeA, score: 7, totalTime: 60.0, gameSession: nil)
    }
}
