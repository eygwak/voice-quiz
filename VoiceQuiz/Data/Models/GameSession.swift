//
//  GameSession.swift
//  VoiceQuiz
//
//  Game session data model for history persistence
//

import Foundation

struct GameSession: Codable, Identifiable {
    let id: String
    let mode: String
    let categoryId: String
    let categoryName: String
    let score: Int
    let maxScore: Int
    let passCount: Int
    let startTime: Date
    let endTime: Date
    let words: [WordResult]
    let fullTranscript: String
    var correction: String?  // AI-generated English correction

    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }

    var successRate: Double {
        guard maxScore > 0 else { return 0.0 }
        return Double(score) / Double(maxScore)
    }

    init(
        id: String = UUID().uuidString,
        mode: GameMode,
        categoryId: String,
        categoryName: String,
        score: Int,
        maxScore: Int,
        passCount: Int,
        startTime: Date,
        endTime: Date,
        words: [WordResult],
        fullTranscript: String = "",
        correction: String? = nil
    ) {
        self.id = id
        self.mode = mode.rawValue
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.score = score
        self.maxScore = maxScore
        self.passCount = passCount
        self.startTime = startTime
        self.endTime = endTime
        self.words = words
        self.fullTranscript = fullTranscript
        self.correction = correction
    }
}

struct WordResult: Codable, Identifiable {
    let id: String
    let word: String
    let attempts: Int
    let passed: Bool
    let isCorrect: Bool
    let aiTranscript: String?
    let judgment: String?
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        word: String,
        attempts: Int,
        passed: Bool,
        isCorrect: Bool,
        aiTranscript: String? = nil,
        judgment: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.attempts = attempts
        self.passed = passed
        self.isCorrect = isCorrect
        self.aiTranscript = aiTranscript
        self.judgment = judgment
        self.timestamp = timestamp
    }
}

// MARK: - Extensions

extension GameSession {
    func toMetadata() -> GameHistoryMetadata {
        return GameHistoryMetadata(
            id: id,
            mode: GameMode(rawValue: mode) ?? .modeA,
            score: score,
            date: endTime,
            categoryName: categoryName
        )
    }
}
