//
//  GameView_ModeA.swift
//  VoiceQuiz
//
//  Mode A: AI describes → User guesses
//

import SwiftUI

struct GameView_ModeA: View {
    @StateObject private var viewModel: GameViewModel_ModeA
    @Environment(\.dismiss) private var dismiss
    @State private var showingResult = false

    init(categoryId: String) {
        _viewModel = StateObject(wrappedValue: GameViewModel_ModeA(categoryId: categoryId))
    }

    var body: some View {
        ZStack {
            // Main Game Content
            VStack(spacing: 0) {
                // Header
                headerView
                    .padding()
                    .background(Color.blue.opacity(0.1))

                Spacer()

                // Main Content
                mainContentView

                Spacer()

                // User Transcript
                transcriptView

                // Controls
                controlsView
                    .padding()
            }

            // Loading Overlay
            if viewModel.isLoadingHint {
                LoadingOverlay(message: "Getting hint...")
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.endGame()
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
        .onChange(of: viewModel.gamePhase) { newPhase in
            if newPhase == .finished {
                showingResult = true
            }
        }
        .navigationDestination(isPresented: $showingResult) {
            ResultView(
                mode: .modeA,
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
            .foregroundStyle(viewModel.remainingPasses > 0 ? .blue : .gray)
        }
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 30) {
            // Status Indicator
            VStack(spacing: 12) {
                if viewModel.isTTSSpeaking {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("AI is speaking...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.isSTTListening {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Listening...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // AI Description
            VStack(spacing: 16) {
                Text("AI's Hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.aiDescription.isEmpty ? "Waiting for hint..." : viewModel.aiDescription)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.05))
                    )
            }
            .padding(.horizontal)

            // Judgment Result
            if let result = viewModel.judgmentResult {
                JudgmentBadge(result: result)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Answer")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(viewModel.userTranscript.isEmpty ? "Speak your answer..." : viewModel.userTranscript)
                .font(.headline)
                .foregroundStyle(viewModel.userTranscript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
        }
        .padding()
    }

    // MARK: - Controls

    private var controlsView: some View {
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
                        .fill(viewModel.remainingPasses > 0 ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(.white)
            }
            .disabled(viewModel.remainingPasses == 0)
        }
    }
}

// MARK: - Judgment Badge

struct JudgmentBadge: View {
    let result: JudgmentResult

    var body: some View {
        Text(result.feedback)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }

    private var backgroundColor: Color {
        switch result {
        case .correct:
            return .green
        case .close:
            return .orange
        case .incorrect:
            return .red
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
}

#Preview {
    NavigationStack {
        GameView_ModeA(categoryId: "food")
    }
}
