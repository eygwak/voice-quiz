//
//  GameHistoryView.swift
//  VoiceQuiz
//
//  Game history view showing past game sessions
//

import SwiftUI

struct GameHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [GameSession] = []
    @State private var selectedSession: GameSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)

                        Text("No Game History")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Play Mode B games to see your transcripts here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // List of sessions
                    List {
                        ForEach(sessions) { session in
                            Button {
                                selectedSession = session
                            } label: {
                                SessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }
            }
            .navigationTitle("Game History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !sessions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(item: $selectedSession) { session in
                TranscriptView(gameSession: session)
            }
            .onAppear {
                loadSessions()
            }
        }
    }

    private func loadSessions() {
        sessions = GameHistoryStorage.shared.loadModeBSessions()
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            GameHistoryStorage.shared.deleteSession(id: session.id)
        }
        sessions.remove(atOffsets: offsets)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            VStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .frame(width: 44, height: 44)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.categoryName)
                        .font(.headline)

                    Spacer()

                    // Score badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("\(session.score)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                HStack(spacing: 8) {
                    // Date
                    Text(session.endTime, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    // Time
                    Text(session.endTime, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    // Word count
                    Text("\(session.words.count) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    GameHistoryView()
}
