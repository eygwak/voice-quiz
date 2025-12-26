//
//  GameViewModel_ModeA.swift
//  VoiceQuiz
//
//  Mode A: AI describes → User guesses
//  Uses STT to capture user's answer, TTS to speak AI descriptions
//

import Foundation
import Combine

@MainActor
class GameViewModel_ModeA: ObservableObject {
    // MARK: - Published State

    @Published private(set) var gamePhase: GamePhase = .ready
    @Published private(set) var score: Int = 0
    @Published private(set) var remainingTime: TimeInterval = 60.0
    @Published private(set) var currentWord: Word?
    @Published private(set) var remainingPasses: Int = 2

    @Published private(set) var userTranscript: String = ""
    @Published private(set) var aiDescription: String = ""
    @Published private(set) var judgmentResult: JudgmentResult?

    @Published private(set) var isTTSSpeaking: Bool = false
    @Published private(set) var isSTTListening: Bool = false
    @Published private(set) var isLoadingHint: Bool = false

    // MARK: - Services

    private let wordManager = WordManager()
    private let gameState: GameSessionState
    private let answerJudge = AnswerJudge()
    private let apiClient = APIClient.shared
    private let tts = SpeechSynthesizerService.shared
    private let stt = SpeechRecognizerService.shared

    // MARK: - Private State

    private var timer: Timer?
    private var previousHints: [String] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(categoryId: String) {
        self.gameState = GameSessionState(mode: .modeA, category: categoryId)

        // Observe STT transcripts
        stt.$partialTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: &$userTranscript)

        stt.$finalTranscript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                guard let self = self, !transcript.isEmpty else { return }
                Task { await self.handleUserAnswer(transcript) }
            }
            .store(in: &cancellables)

        // Observe TTS state and pause STT when AI is speaking
        tts.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSpeaking in
                guard let self = self else { return }
                self.isTTSSpeaking = isSpeaking

                // Pause STT when TTS starts, resume when TTS stops
                if isSpeaking {
                    self.stt.stopListening()
                } else if self.gamePhase == .playing {
                    // Resume STT after TTS finishes
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
        previousHints = []
        userTranscript = ""
        judgmentResult = nil

        // Request AI description
        await requestAIDescription()

        // Start STT listening
        try stt.startListening()
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

    // MARK: - AI Description

    private func requestAIDescription() async {
        guard let word = currentWord else { return }

        isLoadingHint = true

        do {
            let description = try await apiClient.requestDescription(
                word: word.word,
                taboo: word.taboo,
                previousHints: previousHints
            )

            previousHints.append(description)
            aiDescription = description

            // Speak the description
            tts.speak(text: description)

        } catch {
            print("❌ Failed to get AI description: \(error)")
            aiDescription = "Error getting hint"
        }

        isLoadingHint = false
    }

    // MARK: - User Answer Handling

    private func handleUserAnswer(_ answer: String) async {
        guard let word = currentWord else { return }
        guard gamePhase == .playing else { return }

        // Stop TTS immediately when user speaks
        tts.stop()

        // Judge the answer
        let result = answerJudge.judge(userAnswer: answer, correctWord: word)
        judgmentResult = result

        switch result {
        case .correct:
            // Increment score
            gameState.incrementScore()
            score = gameState.score

            // Speak feedback
            tts.speak(text: "Correct! The answer was \(word.word)")

            // Wait for TTS to finish, then load next word
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            try? await loadNextWord()

        case .close:
            // Give feedback
            tts.speak(text: "Close! Try again")

            // Wait, then give another hint
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await requestAIDescription()

        case .incorrect:
            // Give feedback
            tts.speak(text: "Not quite")

            // Wait, then give another hint
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await requestAIDescription()
        }
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
