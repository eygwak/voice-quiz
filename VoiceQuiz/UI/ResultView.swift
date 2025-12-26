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

    @Environment(\.dismiss) private var dismiss
    @State private var showingConfetti = false

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
                    // Navigate to root (HomeView)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootViewController = window.rootViewController {
                        rootViewController.dismiss(animated: true)
                    }
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

#Preview {
    NavigationStack {
        ResultView(mode: .modeA, score: 7, totalTime: 60.0)
    }
}
