//
//  GameViewModel_ModeB.swift
//  VoiceQuiz
//
//  Mode B: User describes → AI guesses
//  Uses STT to capture user's description, TTS to speak AI guesses
//

import Foundation
import Combine

@MainActor
class GameViewModel_ModeB: ObservableObject {
    // MARK: - Published State

    @Published private(set) var gamePhase: GamePhase = .ready
    @Published private(set) var score: Int = 0
    @Published private(set) var remainingTime: TimeInterval = 60.0
    @Published private(set) var currentWord: Word?
    @Published private(set) var remainingPasses: Int = 2

    @Published private(set) var userTranscript: String = ""
    @Published private(set) var accumulatedTranscript: String = ""
    @Published private(set) var aiGuess: String = ""

    @Published private(set) var isTTSSpeaking: Bool = false
    @Published private(set) var isSTTListening: Bool = false
    @Published private(set) var isLoadingGuess: Bool = false

    // MARK: - Services

    private let wordManager = WordManager()
    private let gameState: GameSessionState
    private let apiClient = APIClient.shared
    private let tts = SpeechSynthesizerService.shared
    private let stt = SpeechRecognizerService.shared

    // MARK: - Private State

    private var timer: Timer?
    private var previousGuesses: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastGuessTime: Date?
    private let minGuessInterval: TimeInterval = 1.5
    private let maxGuessInterval: TimeInterval = 3.0

    // MARK: - Initialization

    init(categoryId: String) {
        self.gameState = GameSessionState(mode: .modeB, category: categoryId)

        // Observe STT transcripts
        stt.$partialTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: &$userTranscript)

        stt.$finalTranscript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                guard let self = self, !transcript.isEmpty else { return }
                self.handleUserDescription(transcript)
            }
            .store(in: &cancellables)

        // Observe TTS state and pause STT when AI is speaking (to prevent echo)
        tts.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSpeaking in
                guard let self = self else { return }
                self.isTTSSpeaking = isSpeaking

                // Pause STT when TTS starts, resume when TTS stops
                if isSpeaking {
                    self.stt.stopListening()
                } else if self.gamePhase == .playing && !self.aiGuess.isEmpty {
                    // Resume STT after AI speaks its guess
                    // User continues describing after hearing AI's guess
                    try? self.stt.startListening()
                }
            }
            .store(in: &cancellables)

        stt.$isListening
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSTTListening)
    }

    // MARK: - Game Control

    func startGame() async {
        do {
            // Configure and activate audio session
            let audioManager = AudioSessionManager.shared
            try audioManager.configure()
            try audioManager.activate()

            // Load words
            try wordManager.loadWords(categoryId: gameState.category)

            // Start game state
            gameState.start()
            gamePhase = .playing

            // Start timer
            startTimer()

            // Get first word
            try await loadNextWord()

        } catch {
            print("❌ Failed to start game: \(error)")
        }
    }

    func pauseGame() {
        gameState.pause()
        gamePhase = .paused
        stopTimer()
        tts.stop()
        stt.stopListening()
    }

    func resumeGame() {
        gameState.resume()
        gamePhase = .playing
        startTimer()

        // Resume STT
        do {
            try stt.startListening()
        } catch {
            print("❌ Failed to resume STT: \(error)")
        }
    }

    func endGame() {
        gameState.finish()
        gamePhase = .finished
        stopTimer()
        tts.stop()
        stt.stopListening()
    }

    // MARK: - Word Management

    private func loadNextWord() async throws {
        guard wordManager.hasMoreWords else {
            endGame()
            return
        }

        // Get next word
        let word = try wordManager.nextWord()
        currentWord = word
        previousGuesses = []
        userTranscript = ""
        accumulatedTranscript = ""
        aiGuess = ""
        lastGuessTime = nil

        // Start STT listening
        try stt.startListening()

        // Speak prompt
        tts.speak(text: "Describe this word: \(word.word)")
    }

    func usePass() async {
        guard gameState.canPass() else { return }

        gameState.usePass()
        remainingPasses = gameState.remainingPasses

        // Stop current TTS
        tts.stop()

        // Move to next word
        try? await loadNextWord()
    }

    // MARK: - User Description Handling

    private func handleUserDescription(_ newText: String) {
        // Accumulate transcript
        if !accumulatedTranscript.isEmpty {
            accumulatedTranscript += " " + newText
        } else {
            accumulatedTranscript = newText
        }

        // Check if enough time passed since last guess
        let now = Date()
        if let lastGuess = lastGuessTime {
            let elapsed = now.timeIntervalSince(lastGuess)
            if elapsed < minGuessInterval {
                // Too soon, wait
                return
            }
        }

        // Check if we have enough description
        let wordCount = accumulatedTranscript.components(separatedBy: .whitespaces).count
        if wordCount >= 5 || (lastGuessTime == nil && wordCount >= 3) {
            // Request AI guess
            Task { await requestAIGuess() }
        }
    }

    // MARK: - AI Guess

    private func requestAIGuess() async {
        guard !accumulatedTranscript.isEmpty else { return }
        guard !isLoadingGuess else { return }

        // Check max interval
        if let lastGuess = lastGuessTime {
            let elapsed = Date().timeIntervalSince(lastGuess)
            if elapsed > maxGuessInterval {
                // Force a guess
            }
        }

        isLoadingGuess = true
        lastGuessTime = Date()

        do {
            let guess = try await apiClient.requestGuess(
                transcriptSoFar: accumulatedTranscript,
                category: wordManager.categoryName,
                previousGuesses: previousGuesses
            )

            previousGuesses.append(guess)
            aiGuess = guess

            // Speak the guess
            tts.speak(text: guess)

        } catch {
            print("❌ Failed to get AI guess: \(error)")
            aiGuess = "Error getting guess"
        }

        isLoadingGuess = false
    }

    // MARK: - User Judgment

    func judgeCorrect() async {
        // Increment score
        gameState.incrementScore()
        score = gameState.score

        // Speak feedback
        tts.speak(text: "Yes! Moving to next word")

        // Stop STT temporarily
        stt.stopListening()

        // Wait for TTS, then load next word
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        try? await loadNextWord()
    }

    func judgeIncorrect() async {
        // Give feedback
        tts.speak(text: "Not quite, try another guess")

        // Continue listening (STT keeps running)
        // AI will guess again after more description
    }

    func judgeClose() async {
        // Give feedback
        tts.speak(text: "Close, but not exactly")

        // Continue listening
        // AI will try another guess
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(self.gameState.startTime ?? Date())
            let remaining = max(0, 60.0 - elapsed)

            self.gameState.updateElapsedTime(elapsed)
            self.remainingTime = remaining

            if remaining <= 0 {
                Task { await self.endGame() }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Cleanup

    nonisolated deinit {
        Task { @MainActor in
            stopTimer()
            tts.stop()
            stt.stopListening()
            cancellables.removeAll()
        }
    }
}
