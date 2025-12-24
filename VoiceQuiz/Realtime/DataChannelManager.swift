//
//  DataChannelManager.swift
//  VoiceQuiz
//
//  Manages WebRTC DataChannel for Realtime API events
//

import Foundation
import WebRTC

protocol DataChannelDelegate: AnyObject {
    func dataChannel(_ manager: DataChannelManager, didReceiveEvent event: RealtimeEvent)
    func dataChannel(_ manager: DataChannelManager, didChangeState state: RTCDataChannelState)
}

class DataChannelManager: NSObject {
    weak var delegate: DataChannelDelegate?

    private var dataChannel: RTCDataChannel?
    private let channelLabel = "oai-events"

    var isOpen: Bool {
        return dataChannel?.readyState == .open
    }

    // MARK: - Setup

    func createDataChannel(peerConnection: RTCPeerConnection) {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = true

        guard let channel = peerConnection.dataChannel(
            forLabel: channelLabel,
            configuration: config
        ) else {
            print("❌ Failed to create data channel")
            return
        }

        self.dataChannel = channel
        channel.delegate = self

        print("✅ DataChannel created: \(channelLabel)")
    }

    func setDataChannel(_ channel: RTCDataChannel) {
        self.dataChannel = channel
        channel.delegate = self
        print("✅ DataChannel set: \(channel.label)")
    }

    // MARK: - Send Events

    func send<T: Encodable>(_ event: T) {
        guard isOpen else {
            print("⚠️ DataChannel not open, cannot send event")
            return
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(event)

            let buffer = RTCDataBuffer(data: data, isBinary: false)
            dataChannel?.sendData(buffer)

            if let json = String(data: data, encoding: .utf8) {
                print("📤 Sent event: \(json)")
            }
        } catch {
            print("❌ Failed to encode event: \(error)")
        }
    }

    func sendRaw(_ jsonString: String) {
        guard isOpen else {
            print("⚠️ DataChannel not open, cannot send raw message")
            return
        }

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert string to data")
            return
        }

        let buffer = RTCDataBuffer(data: data, isBinary: false)
        dataChannel?.sendData(buffer)

        print("📤 Sent raw message: \(jsonString)")
    }

    // MARK: - Session Control

    func updateSession(enableTranscription: Bool = true) {
        let event = SessionUpdateEvent(
            session: SessionUpdateEvent.SessionConfig(
                audio: SessionUpdateEvent.SessionConfig.AudioConfig(
                    input: SessionUpdateEvent.SessionConfig.AudioConfig.InputConfig(
                        transcription: SessionUpdateEvent.SessionConfig.AudioConfig.InputConfig.TranscriptionConfig(
                            model: "whisper-1"
                        )
                    )
                )
            )
        )

        send(event)
        print("📤 Sent session.update with transcription enabled")
    }

    func cancelResponse() {
        send(ResponseCancelEvent())
        print("📤 Sent response.cancel")
    }

    // MARK: - Cleanup

    func close() {
        dataChannel?.close()
        dataChannel = nil
        print("🔌 DataChannel closed")
    }
}

// MARK: - RTCDataChannelDelegate

extension DataChannelManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("📡 DataChannel state changed: \(dataChannel.readyState.description)")
        delegate?.dataChannel(self, didChangeState: dataChannel.readyState)

        if dataChannel.readyState == .open {
            print("✅ DataChannel is now OPEN")
        }
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard let data = buffer.data as Data? else {
            print("⚠️ Received invalid data")
            return
        }

        // Try to parse as JSON for logging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Received: \(jsonString)")
        }

        // Parse event
        if let event = RealtimeEvent.parse(from: data) {
            delegate?.dataChannel(self, didReceiveEvent: event)
        } else {
            print("⚠️ Failed to parse event")
        }
    }
}

// MARK: - RTCDataChannelState Extension

extension RTCDataChannelState {
    var description: String {
        switch self {
        case .connecting:
            return "connecting"
        case .open:
            return "open"
        case .closing:
            return "closing"
        case .closed:
            return "closed"
        @unknown default:
            return "unknown"
        }
    }
}
