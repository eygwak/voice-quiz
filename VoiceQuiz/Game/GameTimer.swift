//
//  GameTimer.swift
//  VoiceQuiz
//
//  60-second countdown timer for quiz rounds
//

import Foundation
import Combine

class GameTimer: ObservableObject {
    @Published private(set) var remainingTime: TimeInterval
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isWarning: Bool = false

    private let totalTime: TimeInterval
    private let warningThreshold: TimeInterval = 10.0

    private var timer: Timer?
    private var startDate: Date?
    private var pausedTime: TimeInterval?

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return remainingTime / totalTime
    }

    var isFinished: Bool {
        return remainingTime <= 0
    }

    init(totalTime: TimeInterval = 60.0) {
        self.totalTime = totalTime
        self.remainingTime = totalTime
    }

    // MARK: - Timer Control

    func start() {
        guard !isRunning else { return }

        isRunning = true
        startDate = Date()

        // If resuming from pause, adjust start date
        if let pausedTime = pausedTime {
            startDate = Date().addingTimeInterval(-pausedTime)
            self.pausedTime = nil
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }

        RunLoop.current.add(timer!, forMode: .common)
    }

    func pause() {
        guard isRunning else { return }

        isRunning = false
        pausedTime = totalTime - remainingTime
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        start()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        startDate = nil
        pausedTime = nil
    }

    func reset() {
        stop()
        remainingTime = totalTime
        isWarning = false
    }

    // MARK: - Private Methods

    private func tick() {
        guard let startDate = startDate else { return }

        let elapsed = Date().timeIntervalSince(startDate)
        remainingTime = max(0, totalTime - elapsed)

        // Update warning state
        isWarning = remainingTime <= warningThreshold && remainingTime > 0

        // Check if time is up
        if remainingTime <= 0 {
            stop()
            remainingTime = 0
        }
    }

    // MARK: - Formatting

    var formattedTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
