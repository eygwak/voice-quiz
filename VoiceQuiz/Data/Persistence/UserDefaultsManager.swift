//
//  UserDefaultsManager.swift
//  VoiceQuiz
//
//  Centralized UserDefaults manager - single source of truth
//

import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    private let userDefaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys: String {
        case bestScoreModeA = "bestScoreModeA"
        case bestScoreModeB = "bestScoreModeB"
        case selectedCategories = "selectedCategories"
        case soundEnabled = "soundEnabled"
        case gameHistoryMetadata = "gameHistoryMetadata"
    }

    private init() {}

    // MARK: - Best Scores

    func getBestScore(for mode: GameMode) -> Int {
        let key = mode == .modeA ? Keys.bestScoreModeA : Keys.bestScoreModeB
        return userDefaults.integer(forKey: key.rawValue)
    }

    func saveBestScore(_ score: Int, for mode: GameMode) {
        let key = mode == .modeA ? Keys.bestScoreModeA : Keys.bestScoreModeB
        userDefaults.set(score, forKey: key.rawValue)
        print("💾 Saved best score for \(mode.displayName): \(score)")
    }

    func resetBestScores() {
        userDefaults.removeObject(forKey: Keys.bestScoreModeA.rawValue)
        userDefaults.removeObject(forKey: Keys.bestScoreModeB.rawValue)
        print("🔄 All best scores reset")
    }

    // MARK: - Settings

    var soundEnabled: Bool {
        get {
            // Default to true if not set
            if userDefaults.object(forKey: Keys.soundEnabled.rawValue) == nil {
                return true
            }
            return userDefaults.bool(forKey: Keys.soundEnabled.rawValue)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.soundEnabled.rawValue)
        }
    }

    var selectedCategories: [String] {
        get {
            return userDefaults.stringArray(forKey: Keys.selectedCategories.rawValue) ?? []
        }
        set {
            userDefaults.set(newValue, forKey: Keys.selectedCategories.rawValue)
        }
    }

    // MARK: - Game History Metadata

    func getHistoryMetadata() -> [GameHistoryMetadata] {
        guard let data = userDefaults.data(forKey: Keys.gameHistoryMetadata.rawValue) else {
            return []
        }

        do {
            let metadata = try JSONDecoder().decode([GameHistoryMetadata].self, from: data)
            return metadata
        } catch {
            print("❌ Failed to decode history metadata: \(error)")
            return []
        }
    }

    func saveHistoryMetadata(_ metadata: [GameHistoryMetadata]) {
        do {
            let data = try JSONEncoder().encode(metadata)
            userDefaults.set(data, forKey: Keys.gameHistoryMetadata.rawValue)
        } catch {
            print("❌ Failed to encode history metadata: \(error)")
        }
    }

    func addHistoryMetadata(_ metadata: GameHistoryMetadata) {
        var existing = getHistoryMetadata()
        existing.insert(metadata, at: 0) // Add to front

        // Keep only last 100 games
        if existing.count > 100 {
            existing = Array(existing.prefix(100))
        }

        saveHistoryMetadata(existing)
    }

    func clearHistoryMetadata() {
        userDefaults.removeObject(forKey: Keys.gameHistoryMetadata.rawValue)
    }

    // MARK: - Reset All

    func resetAll() {
        resetBestScores()
        clearHistoryMetadata()
        selectedCategories = []
        soundEnabled = true
        print("🔄 All settings reset to defaults")
    }
}

// MARK: - Game History Metadata Model

struct GameHistoryMetadata: Codable, Identifiable {
    let id: String
    let mode: String
    let score: Int
    let date: Date
    let categoryName: String

    init(id: String, mode: GameMode, score: Int, date: Date, categoryName: String) {
        self.id = id
        self.mode = mode.rawValue
        self.score = score
        self.date = date
        self.categoryName = categoryName
    }
}
