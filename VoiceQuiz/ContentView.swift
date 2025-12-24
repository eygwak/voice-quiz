//
//  ContentView.swift
//  VoiceQuiz
//
//  Created by 곽은영 on 12/18/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var microphonePermission: AVAudioSession.RecordPermission = .undetermined

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .imageScale(.large)
                .foregroundStyle(microphonePermission == .granted ? .green : .red)
                .font(.system(size: 60))

            Text("VoiceQuiz")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(permissionStatus)
                .font(.headline)
                .foregroundStyle(microphonePermission == .granted ? .green : .orange)

            if microphonePermission != .granted {
                Button("Request Microphone Permission") {
                    requestMicrophonePermission()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            checkMicrophonePermission()
        }
    }

    private var permissionStatus: String {
        switch microphonePermission {
        case .granted:
            return "Microphone Access Granted ✅"
        case .denied:
            return "Microphone Access Denied ❌"
        case .undetermined:
            return "Microphone Permission Not Requested"
        @unknown default:
            return "Unknown Permission Status"
        }
    }

    private func checkMicrophonePermission() {
        microphonePermission = AVAudioSession.sharedInstance().recordPermission
    }

    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphonePermission = granted ? .granted : .denied
            }
        }
    }
}

#Preview {
    ContentView()
}
