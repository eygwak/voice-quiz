//
//  GameHistoryStorage.swift
//  VoiceQuiz
//
//  Storage service for game session history
//

import Foundation

class GameHistoryStorage {
    static let shared = GameHistoryStorage()

    private let userDefaults = UserDefaults.standard
    private let historyKey = "gameHistory"
    private let maxHistoryCount = 50 // Keep last 50 games

    private init() {}

    // MARK: - Save

    func saveSession(_ session: GameSession) {
        var history = loadAllSessions()
        history.insert(session, at: 0) // Newest first

        // Keep only the most recent sessions
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }

    // MARK: - Load

    func loadAllSessions() -> [GameSession] {
        guard let data = userDefaults.data(forKey: historyKey),
              let sessions = try? JSONDecoder().decode([GameSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func loadModeBSessions() -> [GameSession] {
        return loadAllSessions().filter { $0.mode == GameMode.modeB.rawValue }
    }

    func loadRecentSessions(limit: Int = 10) -> [GameSession] {
        let all = loadAllSessions()
        return Array(all.prefix(limit))
    }

    // MARK: - Update

    func updateSessionCorrection(sessionId: String, correction: String) {
        var history = loadAllSessions()

        // Find and update the session
        if let index = history.firstIndex(where: { $0.id == sessionId }) {
            var updatedSession = history[index]
            // Create new session with updated correction (since properties are let)
            updatedSession = GameSession(
                id: updatedSession.id,
                mode: GameMode(rawValue: updatedSession.mode) ?? .modeB,
                categoryId: updatedSession.categoryId,
                categoryName: updatedSession.categoryName,
                score: updatedSession.score,
                maxScore: updatedSession.maxScore,
                passCount: updatedSession.passCount,
                startTime: updatedSession.startTime,
                endTime: updatedSession.endTime,
                words: updatedSession.words,
                fullTranscript: updatedSession.fullTranscript,
                correction: correction
            )
            history[index] = updatedSession

            // Save updated history
            if let encoded = try? JSONEncoder().encode(history) {
                userDefaults.set(encoded, forKey: historyKey)
            }
        }
    }

    // MARK: - Delete

    func deleteSession(id: String) {
        var history = loadAllSessions()
        history.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }

    func clearAll() {
        userDefaults.removeObject(forKey: historyKey)
    }
}
