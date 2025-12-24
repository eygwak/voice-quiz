//
//  RealtimeClient.swift
//  VoiceQuiz
//
//  Realtime API client using Ephemeral Token method
//

import Foundation
import WebRTC
import UIKit

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(Error)
}

protocol RealtimeClientDelegate: AnyObject {
    func realtimeClient(_ client: RealtimeClient, didChangeState state: ConnectionState)
    func realtimeClient(_ client: RealtimeClient, didReceiveEvent event: RealtimeEvent)
    func realtimeClient(_ client: RealtimeClient, didReceiveTranscript transcript: String, isFinal: Bool)
}

class RealtimeClient: NSObject {
    weak var delegate: RealtimeClientDelegate?

    private let serverURL = "https://voicequiz-server-985594867462.asia-northeast3.run.app"
    private let openaiRealtimeURL = "https://api.openai.com/v1/realtime/calls"

    private var webRTCManager: WebRTCManager!
    private var dataChannelManager: DataChannelManager!

    private var currentState: ConnectionState = .disconnected {
        didSet {
            delegate?.realtimeClient(self, didChangeState: currentState)
        }
    }

    private var deviceId: String {
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    override init() {
        super.init()

        webRTCManager = WebRTCManager()
        webRTCManager.delegate = self

        dataChannelManager = DataChannelManager()
        dataChannelManager.delegate = self
    }

    // MARK: - Connection

    func connect(gameMode: String, currentWord: String? = nil, tabooWords: [String]? = nil) async {
        currentState = .connecting

        do {
            // Step 1: Get ephemeral token from server
            let token = try await fetchEphemeralToken(
                gameMode: gameMode,
                currentWord: currentWord,
                tabooWords: tabooWords
            )

            print("✅ Ephemeral token received: \(token.prefix(20))...")

            // Step 2: Create peer connection and add audio track
            let peerConnection = webRTCManager.createPeerConnection()

            webRTCManager.addAudioTrack()

            // Step 3: Create data channel
            dataChannelManager.createDataChannel(peerConnection: peerConnection)

            // Small delay to ensure DataChannel is ready
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Step 4: Create WebRTC offer
            let offer = try await webRTCManager.createOffer()
            try await webRTCManager.setLocalDescription(offer)

            print("✅ Offer created, SDP length: \(offer.sdp.count)")

            // Step 5: Send SDP to OpenAI and get answer
            let answer = try await sendSDPToOpenAI(token: token, sdp: offer.sdp)

            print("✅ Answer received, SDP length: \(answer.count)")

            // Step 6: Set remote description
            let answerDescription = RTCSessionDescription(type: .answer, sdp: answer)
            try await webRTCManager.setRemoteDescription(answerDescription)

            print("✅ Remote description set, connection established")

        } catch {
            print("❌ Connection failed: \(error)")
            currentState = .failed(error)
        }
    }

    func disconnect() {
        dataChannelManager.close()
        webRTCManager.close()
        currentState = .disconnected
        print("🔌 Disconnected from Realtime API")
    }

    // MARK: - Token Fetching

    private func fetchEphemeralToken(
        gameMode: String,
        currentWord: String?,
        tabooWords: [String]?
    ) async throws -> String {
        let url = URL(string: "\(serverURL)/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "deviceId": deviceId,
            "platform": "ios",
            "appVersion": "1.0.0",
            "gameMode": gameMode
        ]

        if let word = currentWord {
            body["currentWord"] = word
        }

        if let taboo = tabooWords {
            body["tabooWords"] = taboo
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RealtimeClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw RealtimeClientError.serverError(httpResponse.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.value
    }

    // MARK: - SDP Exchange

    private func sendSDPToOpenAI(token: String, sdp: String) async throws -> String {
        let url = URL(string: openaiRealtimeURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = sdp.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RealtimeClientError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ OpenAI error: \(errorBody)")
            throw RealtimeClientError.openAIError(httpResponse.statusCode, errorBody)
        }

        guard let answerSDP = String(data: data, encoding: .utf8) else {
            throw RealtimeClientError.invalidSDPResponse
        }

        return answerSDP
    }

    // MARK: - DataChannel Actions

    func enableTranscription() {
        dataChannelManager.updateSession(enableTranscription: true)
    }

    func cancelAIResponse() {
        dataChannelManager.cancelResponse()
    }
}

// MARK: - WebRTCManagerDelegate

extension RealtimeClient: WebRTCManagerDelegate {
    func webRTCManager(_ manager: WebRTCManager, didChangeConnectionState state: RTCPeerConnectionState) {
        switch state {
        case .connected:
            currentState = .connected
            print("✅ WebRTC connection CONNECTED")
        case .failed:
            currentState = .failed(RealtimeClientError.connectionFailed)
            print("❌ WebRTC connection FAILED")
        case .disconnected:
            currentState = .disconnected
            print("⚠️ WebRTC connection DISCONNECTED")
        default:
            break
        }
    }

    func webRTCManager(_ manager: WebRTCManager, didReceiveDataChannel channel: RTCDataChannel) {
        print("📡 Received data channel from server: \(channel.label)")
        dataChannelManager.setDataChannel(channel)
    }
}

// MARK: - DataChannelDelegate

extension RealtimeClient: DataChannelDelegate {
    func dataChannel(_ manager: DataChannelManager, didReceiveEvent event: RealtimeEvent) {
        // Forward event to delegate
        delegate?.realtimeClient(self, didReceiveEvent: event)

        // Handle specific events
        switch event {
        case .sessionCreated(let sessionEvent):
            print("✅ Session created: \(sessionEvent.session.id)")

            // Check if transcription is enabled
            if sessionEvent.session.inputAudioTranscription?.model != nil {
                print("✅ Transcription is enabled")
            } else {
                print("⚠️ Transcription not enabled, sending session.update")
                enableTranscription()
            }

        case .conversationItemInputAudioTranscriptionCompleted(let transcriptEvent):
            print("📝 Transcription: \(transcriptEvent.transcript)")
            delegate?.realtimeClient(self, didReceiveTranscript: transcriptEvent.transcript, isFinal: true)

        case .responseAudioTranscriptDelta(let deltaEvent):
            print("📝 AI transcript delta: \(deltaEvent.delta)")
            delegate?.realtimeClient(self, didReceiveTranscript: deltaEvent.delta, isFinal: false)

        case .responseAudioTranscriptDone(let doneEvent):
            print("📝 AI transcript complete: \(doneEvent.transcript)")
            delegate?.realtimeClient(self, didReceiveTranscript: doneEvent.transcript, isFinal: true)

        case .inputAudioBufferSpeechStarted:
            print("🎤 User started speaking")

        case .inputAudioBufferSpeechStopped:
            print("🎤 User stopped speaking")

        case .error(let errorEvent):
            print("❌ Server error: \(errorEvent.error.message ?? "Unknown")")

        case .unknown(let unknownEvent):
            print("⚠️ Unknown event type: \(unknownEvent.type)")
        }
    }

    func dataChannel(_ manager: DataChannelManager, didChangeState state: RTCDataChannelState) {
        if state == .open {
            print("✅ DataChannel is now open and ready")
        }
    }
}

// MARK: - Models

struct TokenResponse: Codable {
    let value: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case value
        case expiresAt = "expires_at"
    }
}

enum RealtimeClientError: Error {
    case invalidResponse
    case serverError(Int)
    case openAIError(Int, String)
    case invalidSDPResponse
    case connectionFailed
}
