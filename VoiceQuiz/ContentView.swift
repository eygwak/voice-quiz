//
//  ContentView.swift
//  VoiceQuiz
//
//  Temporary entry point - will be replaced with HomeView in Phase 2-3
//

import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
    @State private var microphonePermission: AVAudioSession.RecordPermission = .undetermined
    @State private var speechRecognitionPermission: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "mic.fill")
                    .imageScale(.large)
                    .foregroundStyle(allPermissionsGranted ? .green : .red)
                    .font(.system(size: 60))

                Text("VoiceQuiz")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("MVP - Local STT/TTS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text(microphonePermissionStatus)
                        .font(.headline)
                        .foregroundStyle(microphonePermission == .granted ? .green : .orange)

                    Text(speechRecognitionStatus)
                        .font(.headline)
                        .foregroundStyle(speechRecognitionPermission ? .green : .orange)
                }

                if !allPermissionsGranted {
                    Button("Request Permissions") {
                        requestPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("✅ Ready to Start")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)

                    Text("Home screen coming in Phase 2-3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .onAppear {
                checkPermissions()
            }
            .navigationTitle("VoiceQuiz")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var allPermissionsGranted: Bool {
        microphonePermission == .granted && speechRecognitionPermission
    }

    private var microphonePermissionStatus: String {
        switch microphonePermission {
        case .granted:
            return "🎤 Microphone: Granted"
        case .denied:
            return "🎤 Microphone: Denied"
        case .undetermined:
            return "🎤 Microphone: Not Requested"
        @unknown default:
            return "🎤 Microphone: Unknown"
        }
    }

    private var speechRecognitionStatus: String {
        speechRecognitionPermission
            ? "🗣️ Speech Recognition: Granted"
            : "🗣️ Speech Recognition: Not Granted"
    }

    private func checkPermissions() {
        // Check microphone permission
        // Note: We use AVAudioSession API for consistency across iOS 16+
        // iOS 17 introduced AVAudioApplication, but AVAudioSession still works
        microphonePermission = AVAudioSession.sharedInstance().recordPermission

        // Check speech recognition permission
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        speechRecognitionPermission = (authStatus == .authorized)
    }

    private func requestPermissions() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphonePermission = granted ? .granted : .denied
            }
        }

        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                self.speechRecognitionPermission = (authStatus == .authorized)
            }
        }
    }
}

#Preview {
    ContentView()
}
