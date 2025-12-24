//
//  GameState.swift
//  VoiceQuiz
//
//  Game state management
//

import Foundation

// MARK: - Game Phase

enum GamePhase {
    case ready      // 게임 시작 전
    case playing    // 게임 진행 중
    case paused     // 일시정지
    case finished   // 게임 종료
}

// MARK: - Game Mode

enum GameMode: String, Codable {
    case modeA  // AI describes, user guesses
    case modeB  // User describes, AI guesses

    var displayName: String {
        switch self {
        case .modeA:
            return "AI Describes"
        case .modeB:
            return "You Describe"
        }
    }

    var serverGameMode: String {
        return self.rawValue
    }
}

// MARK: - Game Session State

class GameSessionState {
    // Current state
    private(set) var phase: GamePhase = .ready
    private(set) var mode: GameMode

    // Word progress
    private(set) var currentWordIndex: Int = 0
    private(set) var passCount: Int = 0
    let maxPassCount: Int = 2

    // Time tracking
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var startTime: Date?
    private(set) var endTime: Date?

    // Score
    private(set) var score: Int = 0

    // Category
    private(set) var category: String

    init(mode: GameMode, category: String) {
        self.mode = mode
        self.category = category
    }

    // MARK: - Phase Control

    func start() {
        phase = .playing
        startTime = Date()
        currentWordIndex = 0
        passCount = 0
        score = 0
        elapsedTime = 0
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
    }

    func finish() {
        phase = .finished
        endTime = Date()
    }

    // MARK: - Word Progress

    func moveToNextWord() {
        currentWordIndex += 1
    }

    func canPass() -> Bool {
        return passCount < maxPassCount
    }

    func usePass() {
        guard canPass() else { return }
        passCount += 1
    }

    var remainingPasses: Int {
        return max(0, maxPassCount - passCount)
    }

    // MARK: - Score

    func incrementScore() {
        score += 1
    }

    // MARK: - Time

    func updateElapsedTime(_ time: TimeInterval) {
        elapsedTime = time
    }

    // MARK: - Session Summary

    var duration: TimeInterval {
        if let start = startTime, let end = endTime {
            return end.timeIntervalSince(start)
        }
        return elapsedTime
    }

    var isActive: Bool {
        return phase == .playing || phase == .paused
    }
}
