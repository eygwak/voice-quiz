//
//  ScoreManager.swift
//  VoiceQuiz
//
//  Score tracking and best score persistence
//

import Foundation

class ScoreManager {
    static let shared = ScoreManager()

    private let userDefaults = UserDefaults.standard

    private let bestScoreModeAKey = "bestScoreModeA"
    private let bestScoreModeBKey = "bestScoreModeB"

    private init() {}

    // MARK: - Current Session Score

    private(set) var currentScore: Int = 0

    func incrementScore() {
        currentScore += 1
    }

    func resetCurrentScore() {
        currentScore = 0
    }

    // MARK: - Best Score

    func getBestScore(for mode: GameMode) -> Int {
        let key = bestScoreKey(for: mode)
        return userDefaults.integer(forKey: key)
    }

    func saveBestScore(_ score: Int, for mode: GameMode) {
        let key = bestScoreKey(for: mode)
        let currentBest = getBestScore(for: mode)

        if score > currentBest {
            userDefaults.set(score, forKey: key)
            print("🏆 New best score for \(mode.displayName): \(score)")
        }
    }

    func isNewRecord(score: Int, for mode: GameMode) -> Bool {
        return score > getBestScore(for: mode)
    }

    // MARK: - Helper

    private func bestScoreKey(for mode: GameMode) -> String {
        switch mode {
        case .modeA:
            return bestScoreModeAKey
        case .modeB:
            return bestScoreModeBKey
        }
    }

    // MARK: - Reset (for testing)

    func resetAllBestScores() {
        userDefaults.removeObject(forKey: bestScoreModeAKey)
        userDefaults.removeObject(forKey: bestScoreModeBKey)
        print("🔄 All best scores reset")
    }
}
