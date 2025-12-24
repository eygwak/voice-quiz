//
//  AudioSessionManager.swift
//  VoiceQuiz
//
//  Manages AVAudioSession configuration for voice communication
//

import AVFoundation
import Foundation

enum AudioSessionError: Error {
    case permissionDenied
    case configurationFailed(Error)
    case activationFailed(Error)
}

class AudioSessionManager {
    static let shared = AudioSessionManager()

    private let audioSession = AVAudioSession.sharedInstance()
    private var isConfigured = false

    private init() {}

    // MARK: - Permission

    func checkPermission() -> AVAudioSession.RecordPermission {
        return audioSession.recordPermission
    }

    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Configuration

    func configure() throws {
        guard !isConfigured else { return }

        do {
            // Configure for voice chat
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            // Prefer high quality audio
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms for low latency

            isConfigured = true
            print("✅ AudioSession configured successfully")
        } catch {
            print("❌ AudioSession configuration failed: \(error)")
            throw AudioSessionError.configurationFailed(error)
        }
    }

    func activate() throws {
        do {
            try audioSession.setActive(true, options: [])
            print("✅ AudioSession activated")
        } catch {
            print("❌ AudioSession activation failed: \(error)")
            throw AudioSessionError.activationFailed(error)
        }
    }

    func deactivate() {
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ AudioSession deactivated")
        } catch {
            print("❌ AudioSession deactivation failed: \(error)")
        }
    }

    // MARK: - Interruption Handling

    func setupInterruptionObserver(onInterruption: @escaping (AVAudioSession.InterruptionType) -> Void) {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            onInterruption(type)

            switch type {
            case .began:
                print("⚠️ Audio session interrupted (began)")
            case .ended:
                print("✅ Audio session interruption ended")
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        print("🔄 Should resume audio session")
                    }
                }
            @unknown default:
                break
            }
        }
    }
}
