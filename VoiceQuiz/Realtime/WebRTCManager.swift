//
//  WebRTCManager.swift
//  VoiceQuiz
//
//  Manages WebRTC PeerConnection for real-time audio communication
//

import Foundation
import WebRTC

protocol WebRTCManagerDelegate: AnyObject {
    func webRTCManager(_ manager: WebRTCManager, didChangeConnectionState state: RTCPeerConnectionState)
    func webRTCManager(_ manager: WebRTCManager, didReceiveDataChannel channel: RTCDataChannel)
}

class WebRTCManager: NSObject {
    weak var delegate: WebRTCManagerDelegate?

    private var peerConnection: RTCPeerConnection?
    private let peerConnectionFactory: RTCPeerConnectionFactory
    private var audioTrack: RTCAudioTrack?

    var currentConnectionState: RTCPeerConnectionState {
        return peerConnection?.connectionState ?? .closed
    }

    override init() {
        // Initialize WebRTC factory
        RTCInitializeSSL()

        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()

        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: videoEncoderFactory,
            decoderFactory: videoDecoderFactory
        )

        super.init()
    }

    deinit {
        RTCCleanupSSL()
    }

    // MARK: - Peer Connection Setup

    func createPeerConnection() -> RTCPeerConnection {
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        let pc = peerConnectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )

        self.peerConnection = pc
        print("✅ PeerConnection created")

        return pc
    }

    // MARK: - Audio Track

    func addAudioTrack() {
        guard let peerConnection = peerConnection else {
            print("⚠️ PeerConnection not initialized")
            return
        }

        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        let audioSource = peerConnectionFactory.audioSource(with: audioConstraints)
        let audioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")

        peerConnection.add(audioTrack, streamIds: ["stream0"])
        self.audioTrack = audioTrack

        print("✅ Audio track added to peer connection")
    }

    // MARK: - SDP Offer/Answer

    func createOffer() async throws -> RTCSessionDescription {
        guard let peerConnection = peerConnection else {
            throw WebRTCError.noPeerConnection
        }

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true"
            ],
            optionalConstraints: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            peerConnection.offer(for: constraints) { sdp, error in
                if let error = error {
                    continuation.resume(throwing: WebRTCError.offerFailed(error))
                } else if let sdp = sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: WebRTCError.offerFailed(nil))
                }
            }
        }
    }

    func setLocalDescription(_ sdp: RTCSessionDescription) async throws {
        guard let peerConnection = peerConnection else {
            throw WebRTCError.noPeerConnection
        }

        return try await withCheckedThrowingContinuation { continuation in
            peerConnection.setLocalDescription(sdp) { error in
                if let error = error {
                    continuation.resume(throwing: WebRTCError.setLocalDescriptionFailed(error))
                } else {
                    print("✅ Local description set")
                    continuation.resume()
                }
            }
        }
    }

    func setRemoteDescription(_ sdp: RTCSessionDescription) async throws {
        guard let peerConnection = peerConnection else {
            throw WebRTCError.noPeerConnection
        }

        return try await withCheckedThrowingContinuation { continuation in
            peerConnection.setRemoteDescription(sdp) { error in
                if let error = error {
                    continuation.resume(throwing: WebRTCError.setRemoteDescriptionFailed(error))
                } else {
                    print("✅ Remote description set")
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Cleanup

    func close() {
        audioTrack = nil
        peerConnection?.close()
        peerConnection = nil
        print("🔌 PeerConnection closed")
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("📡 Signaling state: \(stateChanged.description)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("📡 Stream added: \(stream.streamId)")

        // Handle remote audio track
        if let audioTrack = stream.audioTracks.first {
            print("🔊 Remote audio track received")
            audioTrack.isEnabled = true
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("📡 Stream removed: \(stream.streamId)")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("📡 Should negotiate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("📡 ICE connection state: \(newState.description)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("📡 ICE gathering state: \(newState.description)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("📡 ICE candidate generated")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("📡 ICE candidates removed")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("📡 DataChannel opened: \(dataChannel.label)")
        delegate?.webRTCManager(self, didReceiveDataChannel: dataChannel)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        print("📡 Connection state: \(newState.description)")
        delegate?.webRTCManager(self, didChangeConnectionState: newState)
    }
}

// MARK: - State Extensions

extension RTCSignalingState {
    var description: String {
        switch self {
        case .stable: return "stable"
        case .haveLocalOffer: return "have-local-offer"
        case .haveLocalPrAnswer: return "have-local-pranswer"
        case .haveRemoteOffer: return "have-remote-offer"
        case .haveRemotePrAnswer: return "have-remote-pranswer"
        case .closed: return "closed"
        @unknown default: return "unknown"
        }
    }
}

extension RTCIceConnectionState {
    var description: String {
        switch self {
        case .new: return "new"
        case .checking: return "checking"
        case .connected: return "connected"
        case .completed: return "completed"
        case .failed: return "failed"
        case .disconnected: return "disconnected"
        case .closed: return "closed"
        case .count: return "count"
        @unknown default: return "unknown"
        }
    }
}

extension RTCIceGatheringState {
    var description: String {
        switch self {
        case .new: return "new"
        case .gathering: return "gathering"
        case .complete: return "complete"
        @unknown default: return "unknown"
        }
    }
}

extension RTCPeerConnectionState {
    var description: String {
        switch self {
        case .new: return "new"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .disconnected: return "disconnected"
        case .failed: return "failed"
        case .closed: return "closed"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Errors

enum WebRTCError: Error {
    case noPeerConnection
    case offerFailed(Error?)
    case setLocalDescriptionFailed(Error)
    case setRemoteDescriptionFailed(Error)
}
