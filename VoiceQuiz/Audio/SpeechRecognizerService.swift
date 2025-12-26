//
//  SpeechRecognizerService.swift
//  VoiceQuiz
//
//  Apple Speech Framework-based STT service
//

import Foundation
import Speech
import AVFoundation
import Combine

enum SpeechRecognizerError: Error {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineError
    case recognitionFailed(String)
}

class SpeechRecognizerService: NSObject, ObservableObject {
    static let shared = SpeechRecognizerService()

    // Published state
    @Published private(set) var isListening: Bool = false
    @Published private(set) var partialTranscript: String = ""
    @Published private(set) var finalTranscript: String = ""
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // Speech recognition components
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        // Initialize with English (US) recognizer
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        super.init()

        self.speechRecognizer?.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    var isAuthorized: Bool {
        return authorizationStatus == .authorized
    }

    // MARK: - Start/Stop Listening

    func startListening() throws {
        // Check authorization
        guard isAuthorized else {
            throw SpeechRecognizerError.notAuthorized
        }

        // Check if recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        // Cancel any ongoing recognition
        if isListening {
            stopListening()
        }

        // Reset transcripts
        partialTranscript = ""
        finalTranscript = ""

        // Don't reconfigure audio session - use existing configuration from AudioSessionManager
        // The session is already configured as .playAndRecord with .voiceChat mode
        // which allows both STT input and TTS output simultaneously

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognizerError.audioEngineError
        }

        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Use server for better accuracy

        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.partialTranscript = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.finalTranscript = result.bestTranscription.formattedString
                        print("✅ STT final: \(self.finalTranscript)")
                    }
                }
            }

            if error != nil {
                self.stopListening()
            }
        }

        isListening = true
        print("🎤 STT started listening")
    }

    func stopListening() {
        if !isListening {
            return
        }

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        print("⏹️ STT stopped listening")
    }

    // MARK: - Reset

    func reset() {
        stopListening()
        partialTranscript = ""
        finalTranscript = ""
    }

    // MARK: - Utility

    func getRecognizerLocale() -> Locale? {
        return speechRecognizer?.locale
    }

    func printSupportedLocales() {
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        print("📋 Supported locales for speech recognition:")
        for locale in supportedLocales {
            print("  - \(locale.identifier)")
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognizerService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            print("⚠️ Speech recognizer became unavailable")
            stopListening()
        } else {
            print("✅ Speech recognizer became available")
        }
    }
}
