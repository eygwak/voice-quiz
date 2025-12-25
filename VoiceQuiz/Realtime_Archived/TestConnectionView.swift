//
//  TestConnectionView.swift
//  VoiceQuiz
//
//  Test UI for WebRTC connection and audio communication
//

import SwiftUI
import AVFoundation
import Combine

class TestConnectionViewModel: ObservableObject {
    @Published var connectionState: String = "Disconnected"
    @Published var userTranscript: String = ""
    @Published var aiTranscript: String = ""
    @Published var eventLog: [String] = []
    @Published var isConnected: Bool = false

    private var realtimeClient: RealtimeClient?
    private let audioSessionManager = AudioSessionManager.shared

    init() {
        setupRealtimeClient()
    }

    private func setupRealtimeClient() {
        realtimeClient = RealtimeClient()
        realtimeClient?.delegate = self
    }

    func connect() {
        Task {
            // Configure and activate audio session
            do {
                try audioSessionManager.configure()
                try audioSessionManager.activate()
                addLog("✅ Audio session configured")
            } catch {
                addLog("❌ Audio session error: \(error)")
                return
            }

            // Connect to Realtime API
            await realtimeClient?.connect(
                gameMode: "modeA",
                currentWord: "apple",
                tabooWords: ["fruit", "red"]
            )
        }
    }

    func disconnect() {
        realtimeClient?.disconnect()
        audioSessionManager.deactivate()
        addLog("🔌 Disconnected")
    }

    func cancelResponse() {
        realtimeClient?.cancelAIResponse()
        addLog("🛑 Cancelled AI response")
    }

    func clearTranscripts() {
        userTranscript = ""
        aiTranscript = ""
    }

    func clearLog() {
        eventLog.removeAll()
    }

    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            self.eventLog.append(message)
            // Keep only last 50 logs
            if self.eventLog.count > 50 {
                self.eventLog.removeFirst()
            }
        }
    }
}

// MARK: - RealtimeClientDelegate

extension TestConnectionViewModel: RealtimeClientDelegate {
    func realtimeClient(_ client: RealtimeClient, didChangeState state: ConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .disconnected:
                self.connectionState = "Disconnected"
                self.isConnected = false
                self.addLog("⚪️ Disconnected")
            case .connecting:
                self.connectionState = "Connecting..."
                self.isConnected = false
                self.addLog("🟡 Connecting...")
            case .connected:
                self.connectionState = "Connected"
                self.isConnected = true
                self.addLog("🟢 Connected")
            case .failed(let error):
                self.connectionState = "Failed: \(error.localizedDescription)"
                self.isConnected = false
                self.addLog("🔴 Failed: \(error.localizedDescription)")
            }
        }
    }

    func realtimeClient(_ client: RealtimeClient, didReceiveEvent event: RealtimeEvent) {
        // Log important events
        switch event {
        case .sessionCreated:
            addLog("📡 Session created")
        case .inputAudioBufferSpeechStarted:
            addLog("🎤 Speech started")
        case .inputAudioBufferSpeechStopped:
            addLog("🎤 Speech stopped")
        case .error(let errorEvent):
            addLog("❌ Error: \(errorEvent.error.message ?? "Unknown")")
        default:
            break
        }
    }

    func realtimeClient(_ client: RealtimeClient, didReceiveTranscript transcript: String, isFinal: Bool) {
        DispatchQueue.main.async {
            // Determine if it's user or AI transcript based on context
            // For now, we'll append to user transcript if it's final
            if isFinal {
                if !self.userTranscript.isEmpty {
                    self.userTranscript += "\n"
                }
                self.userTranscript += "User: \(transcript)"
                self.addLog("📝 User: \(transcript)")
            } else {
                // AI transcript delta
                self.aiTranscript += transcript
            }
        }
    }
}

// MARK: - TestConnectionView

struct TestConnectionView: View {
    @StateObject private var viewModel = TestConnectionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("WebRTC Connection Test")
                    .font(.title)
                    .fontWeight(.bold)

                // Connection Status
                VStack(spacing: 10) {
                    Image(systemName: viewModel.isConnected ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(viewModel.isConnected ? .green : .red)

                    Text(viewModel.connectionState)
                        .font(.headline)
                        .foregroundStyle(viewModel.isConnected ? .green : .primary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Control Buttons
                VStack(spacing: 12) {
                    if !viewModel.isConnected {
                        Button(action: viewModel.connect) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Connect")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        Button(action: viewModel.disconnect) {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("Disconnect")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }

                        Button(action: viewModel.cancelResponse) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Cancel AI Response")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: viewModel.clearTranscripts) {
                            Text("Clear Transcripts")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray4))
                                .foregroundStyle(.primary)
                                .cornerRadius(8)
                        }

                        Button(action: viewModel.clearLog) {
                            Text("Clear Log")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray4))
                                .foregroundStyle(.primary)
                                .cornerRadius(8)
                        }
                    }
                }

                // Transcripts
                VStack(alignment: .leading, spacing: 10) {
                    Text("User Transcript")
                        .font(.headline)

                    ScrollView {
                        Text(viewModel.userTranscript.isEmpty ? "Speak to see transcription..." : viewModel.userTranscript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 120)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    Text("AI Transcript")
                        .font(.headline)

                    ScrollView {
                        Text(viewModel.aiTranscript.isEmpty ? "AI responses will appear here..." : viewModel.aiTranscript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 120)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // Event Log
                VStack(alignment: .leading, spacing: 10) {
                    Text("Event Log")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.eventLog.reversed(), id: \.self) { log in
                                Text(log)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .frame(height: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    TestConnectionView()
}
