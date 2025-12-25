//
//  ScoreManager.swift
//  VoiceQuiz
//
//  Score calculation and tracking logic
//

import Foundation

class ScoreManager {
    static let shared = ScoreManager()

    private init() {}

    // MARK: - Current Session Score

    private(set) var currentScore: Int = 0

    func incrementScore() {
        currentScore += 1
    }

    func resetCurrentScore() {
        currentScore = 0
    }

    // MARK: - Best Score (delegates to UserDefaultsManager)

    func getBestScore(for mode: GameMode) -> Int {
        return UserDefaultsManager.shared.getBestScore(for: mode)
    }

    func saveBestScore(_ score: Int, for mode: GameMode) {
        let currentBest = getBestScore(for: mode)

        if score > currentBest {
            UserDefaultsManager.shared.saveBestScore(score, for: mode)
            print("🏆 New best score for \(mode.displayName): \(score)")
        }
    }

    func isNewRecord(score: Int, for mode: GameMode) -> Bool {
        return score > getBestScore(for: mode)
    }

    // MARK: - Reset (for testing)

    func resetAllBestScores() {
        UserDefaultsManager.shared.resetBestScores()
    }
}
