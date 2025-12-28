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

                // Judgment Controls (only shown when AI has guessed)
                if !viewModel.aiGuess.isEmpty {
                    judgmentControlsView
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Pass Button
                    passButtonView
                        .padding()
                }
            }

            // Loading Overlay
            if viewModel.isLoadingGuess {
                LoadingOverlay(message: "AI is thinking...")
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
                totalTime: 60.0
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

            // AI's Guess
            if !viewModel.aiGuess.isEmpty {
                VStack(spacing: 12) {
                    Text("AI's Guess")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(viewModel.aiGuess)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .padding(.horizontal)
                .transition(.scale.combined(with: .opacity))
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

    // MARK: - Judgment Controls

    private var judgmentControlsView: some View {
        VStack(spacing: 12) {
            Text("Was the AI's guess correct?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                // Incorrect Button
                Button {
                    Task {
                        await viewModel.judgeIncorrect()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                        Text("Incorrect")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }

                // Close Button
                Button {
                    Task {
                        await viewModel.judgeClose()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.title)
                        Text("Close")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                }

                // Correct Button
                Button {
                    Task {
                        await viewModel.judgeCorrect()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                        Text("Correct")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(12)
                }
            }
        }
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
