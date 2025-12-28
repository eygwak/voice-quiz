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
    @Published private(set) var isGuessButtonPressed: Bool = false

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
    private var autoJudgeTask: Task<Void, Never>?
    private var finalTranscriptTimeoutTask: Task<Void, Never>?

    // MARK: - Initialization

    init(categoryId: String) {
        self.gameState = GameSessionState(mode: .modeA, category: categoryId)

        // Observe STT transcripts
        stt.$partialTranscript
            .receive(on: DispatchQueue.main)
            .assign(to: &$userTranscript)

        // Observe TTS state
        tts.$isSpeaking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTTSSpeaking)

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

        // Don't start STT here - it's push-to-talk mode (Guess button controls STT)
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

    // MARK: - Guess Button (Push-to-Talk)

    func onGuessButtonPressed() {
        guard gamePhase == .playing else { return }

        isGuessButtonPressed = true

        // Pause TTS (not stop, so we can resume later)
        if tts.isSpeaking {
            tts.pause()
        }

        // Start STT
        userTranscript = ""
        do {
            try stt.startListening()
        } catch {
            print("❌ Failed to start STT: \(error)")
        }

        // Auto-judge after 2 seconds (for tap)
        autoJudgeTask?.cancel()
        autoJudgeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            guard let self = self, !Task.isCancelled else { return }
            await self.onGuessButtonReleased()
        }
    }

    func onGuessButtonReleased() async {
        guard isGuessButtonPressed else { return }

        isGuessButtonPressed = false
        autoJudgeTask?.cancel()

        // Stop STT
        stt.stopListening()

        // Wait for final transcript with 0.5s timeout
        finalTranscriptTimeoutTask?.cancel()
        finalTranscriptTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard let self = self, !Task.isCancelled else { return }

            // If no final transcript, use last partial
            let transcript = self.stt.finalTranscript.isEmpty ? self.stt.partialTranscript : self.stt.finalTranscript

            if !transcript.isEmpty {
                await self.handleUserAnswer(transcript, allowResume: true)
            } else {
                // No speech detected, resume TTS
                if self.gamePhase == .playing {
                    self.tts.resume()
                }
            }
        }
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

    private func handleUserAnswer(_ answer: String, allowResume: Bool = false) async {
        guard let word = currentWord else { return }
        guard gamePhase == .playing else { return }

        // Judge the answer
        let result = answerJudge.judge(userAnswer: answer, correctWord: word)
        judgmentResult = result

        switch result {
        case .correct:
            // Stop TTS
            tts.stop()

            // Increment score
            gameState.incrementScore()
            score = gameState.score

            // Show visual feedback (no TTS)
            // TODO: Add sound effect

            // Wait briefly to show feedback, then load next word
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            judgmentResult = nil
            try? await loadNextWord()

        case .close, .incorrect:
            // Show visual feedback (no TTS)
            // TODO: Add sound effect

            // Wait briefly to show feedback
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            judgmentResult = nil

            // Resume TTS if it was paused (from Guess button)
            if allowResume && !tts.isSpeaking {
                tts.resume()
            } else {
                // Continue with new hint
                await requestAIDescription()
            }
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

    func cleanup() {
        stopTimer()
        tts.stop()
        stt.stopListening()
        autoJudgeTask?.cancel()
        finalTranscriptTimeoutTask?.cancel()
        cancellables.removeAll()
    }

    deinit {
        print("🗑️ GameViewModel_ModeA deallocating")
    }
}
