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
        print("🎙️ [STT] startListening() called")

        // Check authorization
        guard isAuthorized else {
            print("❌ [STT] Not authorized - status: \(authorizationStatus)")
            throw SpeechRecognizerError.notAuthorized
        }
        print("✅ [STT] Authorization OK")

        // Check if recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ [STT] Recognizer unavailable - recognizer exists: \(speechRecognizer != nil), available: \(speechRecognizer?.isAvailable ?? false)")
            throw SpeechRecognizerError.recognizerUnavailable
        }
        print("✅ [STT] Recognizer available")

        // Cancel any ongoing recognition
        if isListening {
            print("⚠️ [STT] Already listening, stopping first")
            stopListening()
        }

        // Reset transcripts
        partialTranscript = ""
        finalTranscript = ""
        print("✅ [STT] Transcripts reset")

        // Don't reconfigure audio session - use existing configuration from AudioSessionManager
        // The session is already configured as .playAndRecord with .voiceChat mode
        // which allows both STT input and TTS output simultaneously

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ [STT] Failed to create recognition request")
            throw SpeechRecognizerError.audioEngineError
        }
        print("✅ [STT] Recognition request created")

        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Use server for better accuracy
        print("✅ [STT] Request configured - partial results: true, on-device: false")

        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("✅ [STT] Audio format - sampleRate: \(recordingFormat.sampleRate), channels: \(recordingFormat.channelCount)")

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)

            // Check audio level to verify microphone input
            let channelData = buffer.floatChannelData?[0]
            let channelDataCount = Int(buffer.frameLength)

            if let channelData = channelData, channelDataCount > 0 {
                var sum: Float = 0
                for i in 0..<channelDataCount {
                    sum += abs(channelData[i])
                }
                let avgPower = sum / Float(channelDataCount)

                // Log audio level every ~0.5 seconds when there's actual sound
                if Int.random(in: 0..<21) == 0 && avgPower > 0.0005 {
                    print("🎙️ Audio input level: \(String(format: "%.4f", avgPower))")
                }
            }
        }

        // Prepare and start audio engine
        print("🎙️ [STT] Preparing audio engine...")
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("✅ [STT] Audio engine started successfully")
        } catch {
            print("❌ [STT] Audio engine failed to start: \(error.localizedDescription)")
            throw SpeechRecognizerError.audioEngineError
        }

        // Start recognition task
        print("🎙️ [STT] Starting recognition task...")
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.partialTranscript = result.bestTranscription.formattedString

                    if result.isFinal {
                        self.finalTranscript = result.bestTranscription.formattedString
                        print("✅ [STT] Final transcript: \(self.finalTranscript)")
                    }
                }
            }

            if let error = error {
                print("❌ [STT] Recognition error: \(error.localizedDescription)")
                self.stopListening()
            }
        }

        isListening = true
        print("✅ [STT] Started listening successfully - isListening: \(isListening)")
    }

    func stopListening() {
        print("⏹️ [STT] stopListening() called - isListening: \(isListening)")

        if !isListening {
            print("⚠️ [STT] Already stopped, returning")
            return
        }

        // Stop audio engine
        print("🎙️ [STT] Stopping audio engine...")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        print("✅ [STT] Audio engine stopped")

        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        print("✅ [STT] Recognition request ended")

        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        print("✅ [STT] Recognition task cancelled")

        isListening = false
        print("✅ [STT] Stopped listening - isListening: \(isListening)")
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
