//
//  GameView_ModeB.swift
//  VoiceQuiz
//
//  Mode B: User describes → AI guesses
//

import SwiftUI

struct GameView_ModeB: View {
    @StateObject private var viewModel: GameViewModel_ModeB
    @Environment(\.dismiss) private var dismiss
    @State private var showingResult = false

    init(categoryId: String) {
        _viewModel = StateObject(wrappedValue: GameViewModel_ModeB(categoryId: categoryId))
    }

    var body: some View {
        ZStack {
            // Main Game Content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding()
                    .background(Color.purple.opacity(0.1))

                Spacer()

                // Main Content
                mainContentView

                Spacer()

                // User Transcript
                transcriptView

                // Pass Button (always visible)
                passButtonView
                    .padding()
            }

            // Loading Overlay
            if viewModel.isLoadingGuess {
                LoadingOverlay(message: "AI is thinking...")
            }

            // Correct Answer Feedback
            if viewModel.showCorrectFeedback {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 120))
                            .foregroundStyle(.green)

                        Text("Correct!")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.endGame()
                    viewModel.cleanup()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Exit")
                    }
                }
            }
        }
        .task {
            await viewModel.startGame()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.gamePhase) { newPhase in
            if newPhase == .finished {
                showingResult = true
            }
        }
        .navigationDestination(isPresented: $showingResult) {
            ResultView(
                mode: .modeB,
                score: viewModel.score,
                totalTime: 60.0,
                gameSession: viewModel.completedGameSession
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Timer
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text("\(Int(viewModel.remainingTime))s")
                    .font(.headline)
                    .monospacedDigit()
            }
            .foregroundStyle(viewModel.remainingTime < 10 ? .red : .primary)

            Spacer()

            // Score
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("\(viewModel.score)")
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer()

            // Passes
            HStack(spacing: 4) {
                Image(systemName: "forward.fill")
                Text("\(viewModel.remainingPasses)")
                    .font(.headline)
                    .monospacedDigit()
            }
            .foregroundStyle(viewModel.remainingPasses > 0 ? .purple : .gray)
        }
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 30) {
            // Status Indicator
            VStack(spacing: 12) {
                if viewModel.isSTTListening {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Listening to your description...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.isTTSSpeaking {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("AI is guessing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Current Word (shown to user)
            VStack(spacing: 16) {
                Text("Your Word")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let word = viewModel.currentWord {
                    Text(word.word.uppercased())
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.purple)
                } else {
                    Text("Loading...")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

                Text("Describe this word without saying it")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.1))
            )
            .padding(.horizontal)

            // Penalty Message
            if !viewModel.penaltyMessage.isEmpty {
                Text(viewModel.penaltyMessage)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
            }

            // AI's Guess History (Recent 5, newest first)
            if !viewModel.aiGuessHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI's Guesses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.aiGuessHistory.enumerated()), id: \.offset) { index, guess in
                            HStack(spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)

                                Text(guess)
                                    .font(index == 0 ? .title3 : .body)
                                    .fontWeight(index == 0 ? .semibold : .regular)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(index == 0 ? Color.blue.opacity(0.15) : Color.blue.opacity(0.05))
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Description")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(viewModel.accumulatedTranscript.isEmpty ? "Start describing..." : viewModel.accumulatedTranscript)
                    .font(.subheadline)
                    .foregroundStyle(viewModel.accumulatedTranscript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 80)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .padding()
    }

    // MARK: - Pass Button

    private var passButtonView: some View {
        HStack(spacing: 16) {
            // Pause Button
            Button {
                if viewModel.gamePhase == .playing {
                    viewModel.pauseGame()
                } else if viewModel.gamePhase == .paused {
                    viewModel.resumeGame()
                }
            } label: {
                Image(systemName: viewModel.gamePhase == .playing ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.gray.opacity(0.2)))
            }

            // Pass Button
            Button {
                Task {
                    await viewModel.usePass()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                    Text("Pass")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.remainingPasses > 0 ? Color.purple : Color.gray.opacity(0.2))
                )
                .foregroundColor(.white)
            }
            .disabled(viewModel.remainingPasses == 0)
        }
    }
}

#Preview {
    NavigationStack {
        GameView_ModeB(categoryId: "food")
    }
}
