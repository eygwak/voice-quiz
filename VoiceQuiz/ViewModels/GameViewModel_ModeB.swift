//
//  GameViewModel_ModeB.swift
//  VoiceQuiz
//
//  Mode B: User describes → AI guesses
//  Uses STT to capture user's description, TTS to speak AI guesses
//

import Foundation
import Combine
import AVFoundation

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
    @Published private(set) var aiGuessHistory: [String] = [] // Recent 5 guesses, newest first
    @Published private(set) var penaltyMessage: String = "" // "Oops! You said it!"
    @Published private(set) var showCorrectFeedback: Bool = false // Show success animation

    @Published private(set) var isTTSSpeaking: Bool = false
    @Published private(set) var isSTTListening: Bool = false
    @Published private(set) var isLoadingGuess: Bool = false

    // MARK: - Services

    private let wordManager = WordManager()
    private let gameState: GameSessionState
    private let answerJudge = AnswerJudge()

    // MARK: - Computed Properties

    var completedGameSession: GameSession? {
        guard gamePhase == .finished else { return nil }
        return gameState.toGameSession(categoryName: wordManager.categoryName)
    }
    private let apiClient = APIClient.shared
    private let tts = SpeechSynthesizerService.shared
    private let stt = SpeechRecognizerService.shared

    // MARK: - Private State

    private var timer: Timer?
    private var previousGuesses: [String] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastGuessTime: Date?
    private var wordStartTime: Date?
    private let firstGuessDelay: TimeInterval = 3.0 // First guess after 3 seconds
    private var lastTranscriptLength: Int = 0
    private var wordCountAtLastGuess: Int = 0
    private var lastSpeechTime: Date?
    private var silenceCheckTimer: Timer?

    // MARK: - Initialization

    init(categoryId: String) {
        self.gameState = GameSessionState(mode: .modeB, category: categoryId)

        // Observe STT listening state
        stt.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isListening in
                guard let self = self else { return }
                self.isSTTListening = isListening
                print("🎙️ [ModeB] STT listening state changed: \(isListening)")
            }
            .store(in: &cancellables)

        // Observe STT transcripts
        stt.$partialTranscript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                guard let self = self else { return }
                self.userTranscript = transcript
                if !transcript.isEmpty {
                    print("📝 [ModeB] Partial transcript: \(transcript)")
                }

                // Check if user said the answer word (penalty)
                if let currentWord = self.currentWord, !transcript.isEmpty {
                    // Normalize both transcript and answer for comparison
                    let normalizedTranscript = transcript.lowercased()
                        .components(separatedBy: .whitespacesAndNewlines)
                        .joined(separator: " ")
                    let normalizedAnswer = currentWord.word.lowercased()

                    // Check both exact match and contains
                    let result = self.answerJudge.judge(
                        userAnswer: transcript,
                        correctWord: currentWord
                    )

                    // Also check if transcript contains the answer as a whole word
                    let words = normalizedTranscript.components(separatedBy: .whitespaces)
                    let containsAnswerWord = words.contains { word in
                        // Remove punctuation from word
                        let cleanWord = word.filter { $0.isLetter }
                        return cleanWord == normalizedAnswer
                    }

                    if result == .correct || containsAnswerWord {
                        // User said the answer! Penalty - no points, skip to next word
                        print("⚠️ PENALTY: User said the answer word! (transcript: \"\(transcript)\")")
                        self.handlePenalty()
                        return
                    }
                }

                // Track transcript length for silence detection
                let wordCount = transcript.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count

                // If transcript changed, user is speaking
                if wordCount != self.lastTranscriptLength {
                    self.lastTranscriptLength = wordCount
                    self.lastSpeechTime = Date()

                    // Update accumulated transcript with latest partial
                    self.accumulatedTranscript = transcript

                    self.startSilenceDetection()

                    // Check word count trigger (even without silence)
                    if let lastGuess = self.lastGuessTime, !self.isLoadingGuess {
                        let newWordCount = wordCount - self.wordCountAtLastGuess

                        // Trigger on 7+ words
                        if newWordCount >= 7 {
                            print("🎯 7+ word-triggered guess (continuous speech) with \(newWordCount) new words")
                            Task { await self.requestAIGuess() }
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Observe TTS state (no pause/resume logic needed in Mode B)
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
            print("🎮 [ModeB] Loading words...")
            try wordManager.loadWords(categoryId: gameState.category)

            // Start game state
            print("🎮 [ModeB] Starting game state...")
            gameState.start()
            gamePhase = .playing

            // Start timer
            print("🎮 [ModeB] Starting timer...")
            startTimer()

            // Get first word
            print("🎮 [ModeB] Loading first word...")
            try await loadNextWord()

        } catch {
            print("❌ [ModeB] Failed to start game: \(error)")
        }
    }

    func pauseGame() {
        print("⏸️ [ModeB] Pausing game...")
        gameState.pause()
        gamePhase = .paused
        stopTimer()
        tts.stop()
        stt.stopListening()
        print("✅ [ModeB] Game paused")
    }

    func resumeGame() {
        print("▶️ [ModeB] Resuming game...")
        gameState.resume()
        gamePhase = .playing
        startTimer()

        // Resume STT
        do {
            print("🎙️ [ModeB] Attempting to restart STT...")
            try stt.startListening()
            print("✅ [ModeB] Game resumed successfully")
        } catch {
            print("❌ [ModeB] Failed to resume STT: \(error)")
        }
    }

    func endGame() {
        // Save any remaining transcript before finishing
        if !accumulatedTranscript.isEmpty {
            gameState.appendToTranscript(accumulatedTranscript)
            print("💾 Saved final transcript on game end: \(accumulatedTranscript)")
        }

        gameState.finish()
        gamePhase = .finished
        stopTimer()
        tts.stop()
        stt.stopListening()

        // Save game session to history
        if let session = completedGameSession {
            GameHistoryStorage.shared.saveSession(session)
            print("💾 Game session saved to history with full transcript: \(session.fullTranscript)")
        }
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
        aiGuessHistory = []
        penaltyMessage = ""
        showCorrectFeedback = false
        lastGuessTime = nil
        wordStartTime = Date()
        lastTranscriptLength = 0
        wordCountAtLastGuess = 0
        lastSpeechTime = nil

        // Start STT listening
        print("🎙️ [ModeB] Starting STT for word: \(word.word)")
        try stt.startListening()

        // Don't speak - Mode B is text-only for now
        print("📝 [ModeB] Next word loaded: \(word.word)")
    }

    func usePass() async {
        guard gameState.canPass() else { return }

        // Save current transcript to game state before passing
        if !accumulatedTranscript.isEmpty {
            gameState.appendToTranscript(accumulatedTranscript)
            print("💾 Saved transcript on pass: \(accumulatedTranscript)")
        }

        // Record word result before passing
        if let word = currentWord {
            let wordResult = WordResult(
                word: word.word,
                attempts: previousGuesses.count,
                passed: true,
                isCorrect: false,
                aiTranscript: aiGuess.isEmpty ? nil : aiGuess,
                judgment: "passed"
            )
            gameState.recordWordResult(wordResult)
        }

        gameState.usePass()
        remainingPasses = gameState.remainingPasses

        // Stop current TTS
        tts.stop()

        // Move to next word
        try? await loadNextWord()
    }

    private func handlePenalty() {
        // Save current transcript to game state before penalty
        if !accumulatedTranscript.isEmpty {
            gameState.appendToTranscript(accumulatedTranscript)
            print("💾 Saved transcript on penalty: \(accumulatedTranscript)")
        }

        // Record word result before penalty
        if let word = currentWord {
            let wordResult = WordResult(
                word: word.word,
                attempts: 0,
                passed: false,
                isCorrect: false,
                aiTranscript: nil,
                judgment: "penalty"
            )
            gameState.recordWordResult(wordResult)
        }

        // Show penalty message
        penaltyMessage = "Oops! You said it!"

        // Stop STT temporarily
        stt.stopListening()

        // Don't increment score - this is a penalty

        // Move to next word after brief delay
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            guard let self = self else { return }
            self.penaltyMessage = ""
            try? await self.loadNextWord()
        }
    }

    private func handleAICorrectGuess() async {
        // Save current transcript to game state before moving to next word
        if !accumulatedTranscript.isEmpty {
            gameState.appendToTranscript(accumulatedTranscript)
            print("💾 Saved transcript on correct: \(accumulatedTranscript)")
        }

        // Record word result
        if let word = currentWord {
            let wordResult = WordResult(
                word: word.word,
                attempts: previousGuesses.count,
                passed: false,
                isCorrect: true,
                aiTranscript: aiGuess,
                judgment: "correct"
            )
            gameState.recordWordResult(wordResult)
        }

        // Increment score
        gameState.incrementScore()
        score = gameState.score

        // Stop STT listening
        stt.stopListening()

        // Show success feedback
        showCorrectFeedback = true

        // Play success sound (system sound)
        AudioServicesPlaySystemSound(1057) // Tink sound

        // Brief delay to let user see the success
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second

        // Hide feedback
        showCorrectFeedback = false

        // Move to next word
        try? await loadNextWord()
    }

    // MARK: - Silence Detection & AI Guess Trigger

    private func startSilenceDetection() {
        // Cancel existing timer
        silenceCheckTimer?.invalidate()

        // Start new timer to check for silence after 1 second
        silenceCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.checkForSilence()
            }
        }
    }

    private func checkForSilence() {
        guard let lastSpeech = lastSpeechTime else { return }

        let now = Date()
        let silenceDuration = now.timeIntervalSince(lastSpeech)

        // If more than 1 second of silence, treat as pause
        if silenceDuration >= 1.0 {
            print("🤫 Silence detected after \(String(format: "%.1f", silenceDuration))s")
            handleSilenceDetected(accumulatedTranscript)
        }
    }

    private func handleSilenceDetected(_ currentTranscript: String) {
        // Check if already loading a guess
        guard !isLoadingGuess else { return }

        // Use the current accumulated transcript (don't add again)
        guard !currentTranscript.isEmpty else { return }

        let now = Date()
        let totalWordCount = accumulatedTranscript.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count

        // First guess: must wait at least 3 seconds from word start
        if lastGuessTime == nil {
            guard let startTime = wordStartTime else { return }
            let elapsed = now.timeIntervalSince(startTime)

            if elapsed < firstGuessDelay {
                print("⏱️ Waiting for first guess delay... (\(String(format: "%.1f", elapsed))s / \(firstGuessDelay)s)")
                return
            }

            // After 3 seconds, need at least some words
            if totalWordCount >= 1 {
                print("🎯 First guess triggered after \(String(format: "%.1f", elapsed))s with \(totalWordCount) words")
                Task { await requestAIGuess() }
            }
            return
        }

        // Subsequent guesses: check new words since last guess
        if lastGuessTime != nil {
            // Calculate words added since last guess
            let newWordCount = totalWordCount - wordCountAtLastGuess

            print("📊 Total words: \(totalWordCount), Words at last guess: \(wordCountAtLastGuess), New words: \(newWordCount)")

            // If user said 1+ new words and paused (silence detected), request guess
            if newWordCount >= 1 {
                print("🎯 Silence-triggered guess with \(newWordCount) new words")
                Task { await requestAIGuess() }
            }
        }
    }

    private func requestAIGuess() async {
        guard !accumulatedTranscript.isEmpty else { return }
        guard !isLoadingGuess else { return }

        isLoadingGuess = true
        lastGuessTime = Date()

        // Save current word count for next comparison
        let currentWordCount = accumulatedTranscript.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        wordCountAtLastGuess = currentWordCount

        // Log the transcript being sent to server
        print("📤 Sending to server - Transcript: \"\(accumulatedTranscript)\"")
        print("📤 Category: \(wordManager.categoryName), Previous guesses: \(previousGuesses)")

        do {
            let guess = try await apiClient.requestGuess(
                transcriptSoFar: accumulatedTranscript,
                category: wordManager.categoryName,
                previousGuesses: previousGuesses
            )

            previousGuesses.append(guess)
            aiGuess = guess

            // Add to history (newest first, keep max 5)
            aiGuessHistory.insert(guess, at: 0)
            if aiGuessHistory.count > 5 {
                aiGuessHistory.removeLast()
            }

            // Don't speak - Mode B is text-only for now
            print("🤖 AI guessed: \(guess)")

            // Check if AI guessed correctly
            if let currentWord = self.currentWord {
                let result = self.answerJudge.judge(
                    userAnswer: guess,
                    correctWord: currentWord
                )

                // Also check if the guess contains the answer word
                let normalizedGuess = guess.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedAnswer = currentWord.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let containsAnswer = normalizedGuess.contains(normalizedAnswer)

                if result == .correct || containsAnswer {
                    // AI got it right! Increment score and move to next word
                    print("✅ AI CORRECT! Moving to next word")
                    await self.handleAICorrectGuess()
                }
            }

        } catch {
            print("❌ Failed to get AI guess: \(error)")
            aiGuess = "Error getting guess"
        }

        isLoadingGuess = false
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
        silenceCheckTimer?.invalidate()
        silenceCheckTimer = nil
        tts.stop()
        stt.stopListening()
        cancellables.removeAll()
    }

    deinit {
        print("🗑️ GameViewModel_ModeB deallocating")
    }
}
