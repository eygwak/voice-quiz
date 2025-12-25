//
//  SpeechSynthesizerService.swift
//  VoiceQuiz
//
//  AVSpeechSynthesizer-based TTS service for AI voice output
//

import Foundation
import AVFoundation
import Combine

class SpeechSynthesizerService: NSObject, ObservableObject {
    static let shared = SpeechSynthesizerService()

    private let synthesizer = AVSpeechSynthesizer()

    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var isPaused: Bool = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public Interface

    /// Speak text with customizable voice settings
    func speak(
        text: String,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        pitch: Float = 1.0,
        volume: Float = 1.0,
        voiceIdentifier: String? = nil
    ) {
        // Stop any ongoing speech
        if isSpeaking {
            stop()
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume

        // Set voice (default: English US)
        if let identifier = voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
        } else {
            // Default to English (US) voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }

        synthesizer.speak(utterance)
        print("🗣️ TTS speaking: \(text.prefix(50))...")
    }

    /// Stop speaking immediately
    func stop() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("⏹️ TTS stopped")
        }
    }

    /// Pause speaking
    func pause() {
        if isSpeaking && !isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
            print("⏸️ TTS paused")
        }
    }

    /// Resume speaking
    func resume() {
        if isPaused {
            synthesizer.continueSpeaking()
            print("▶️ TTS resumed")
        }
    }

    // MARK: - Utility

    /// Get available English voices
    func getAvailableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en")
        }
    }

    /// Print available voices for debugging
    func printAvailableVoices() {
        let voices = getAvailableEnglishVoices()
        print("📋 Available English voices:")
        for voice in voices {
            print("  - \(voice.name) (\(voice.language)) - \(voice.identifier)")
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthesizerService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.isPaused = false
        }
        print("🎙️ TTS started")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
        }
        print("✅ TTS finished")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = false
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
        }
        print("❌ TTS cancelled")
    }
}
