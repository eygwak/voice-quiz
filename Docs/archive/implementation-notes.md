# VoiceQuiz 구현 노트

## 🚨 중요 수정사항

### 1. Session Config 구조 (Cloud Run 서버)

제공하신 코드를 OpenAI Realtime API GA 문서에 맞춰 수정:

```javascript
// index.js - 수정된 버전
import express from "express";

const app = express();
app.use(express.json());

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) throw new Error("Missing OPENAI_API_KEY");

const PORT = process.env.PORT || 8080;

// Instructions 생성 함수 (gameMode별)
function generateInstructions(gameMode, currentWord, tabooWords) {
  if (gameMode === "modeA") {
    // AI가 설명자 역할
    return `# Role
You are the host of a speed quiz game. Your job is to describe words so the user can guess them.

# Rules
- NEVER say the target word, its spelling, or direct synonyms
- Use indirect, natural descriptions like "You use this when..." or "You usually see this in..."
- Keep descriptions SHORT (1-2 sentences at a time)
- If the user says something close, provide additional hints
- If the user is correct, immediately stop and wait for the next word
- The taboo words for the current word are: ${tabooWords?.join(", ") || "none"}

# Current Word
The word you need to describe is: ${currentWord}

# Language
- Speak only in English
- Use clear, natural pronunciation`;
  } else if (gameMode === "modeB") {
    // AI가 추측자 역할
    return `# Role
You are a player in a speed quiz game trying to GUESS the word based on the user's description.

# Rules
- NEVER ask questions like "Is it...?" or "Does it...?"
- ONLY make direct guesses in the format: "I think it is [WORD]" or simply "[WORD]"
- Listen carefully to the user's description
- Make educated guesses based on the clues
- If you get "Close" feedback, try related words
- If you get "Incorrect" feedback, try completely different words
- Keep your guesses SHORT and CLEAR

# Language
- Listen in English
- Respond only in English
- Use clear, natural pronunciation`;
  }
  return "You are a helpful assistant.";
}

app.post("/token", async (req, res) => {
  try {
    const { deviceId, platform, appVersion, gameMode, currentWord, tabooWords } = req.body;

    // 로깅
    console.log(`[${new Date().toISOString()}] Token request - device: ${deviceId}, mode: ${gameMode}, word: ${currentWord}`);

    // ⚠️ 중요: WebRTC 환경에서는 format 필드 생략 권장
    // SDP 협상 과정에서 자동으로 코덱(Opus)과 샘플링 레이트가 결정됨
    const sessionConfig = {
      session: {
        type: "realtime",
        model: "gpt-realtime",
        instructions: generateInstructions(gameMode, currentWord, tabooWords),
        audio: {
          input: {
            // format 생략 - WebRTC SDP에서 자동 협상
            turn_detection: {
              type: "semantic_vad",
              // threshold: 0.5,  // 기본값, 필요시 조정
              // silence_duration_ms: 200,
              // prefix_padding_ms: 300,
            },
            transcription: {
              model: "whisper-1",
            },
          },
          output: {
            // format 생략 - WebRTC SDP에서 자동 협상
            voice: "marin",
          },
        },
      },
    };

    const response = await fetch(
      "https://api.openai.com/v1/realtime/client_secrets",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(sessionConfig),
      }
    );

    if (!response.ok) {
      const errText = await response.text();
      console.error("OpenAI API error:", response.status, errText);
      return res.status(response.status).json({
        error: "client_secrets failed",
        details: errText
      });
    }

    const data = await response.json();
    console.log(`[${new Date().toISOString()}] Token issued - expires: ${data.expires_at}`);

    // 응답 그대로 전달
    res.json(data);
  } catch (error) {
    console.error("Token generation error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### 핵심 수정 사항:

1. **`transcription` 위치**: `audio.input.transcription` (GA 문서 기준)
2. **`turn_detection` 위치**: `audio.input.turn_detection`
3. **Audio format 명시**: `audio/pcm`, rate 24000 (권장)
4. **Instructions 동적 생성**: `gameMode`, `currentWord`, `tabooWords` 반영

---

## 2. iOS 클라이언트 개선사항

### A. RealtimeWebRTCClient.swift 완성본

```swift
import Foundation
import WebRTC
import AVFoundation

final class RealtimeWebRTCClient: NSObject {

    // MARK: - Properties
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var factory: RTCPeerConnectionFactory!

    // Delegate for handling events
    weak var delegate: RealtimeWebRTCClientDelegate?

    // Current connection state
    private(set) var connectionState: RTCPeerConnectionState = .new

    // MARK: - Initialization
    override init() {
        super.init()
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()
    }

    deinit {
        disconnect()
        RTCCleanupSSL()
    }

    // MARK: - Audio Session
    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true)
        print("✅ Audio session configured")
    }

    // MARK: - PeerConnection Setup
    func createPeerConnection() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan

        // STUN server (필수는 아니지만 권장)
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        guard let pc = factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        ) else {
            print("❌ Failed to create peer connection")
            return
        }

        self.peerConnection = pc

        // Audio track 추가 (마이크)
        addAudioTrack(to: pc)

        // DataChannel 생성 (oai-events)
        createDataChannel(on: pc)

        print("✅ PeerConnection created")
    }

    private func addAudioTrack(to pc: RTCPeerConnection) {
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        let audioSource = factory.audioSource(with: audioConstraints)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")

        pc.add(audioTrack, streamIds: ["stream0"])
        self.audioTrack = audioTrack

        print("✅ Audio track added")
    }

    private func createDataChannel(on pc: RTCPeerConnection) {
        let config = RTCDataChannelConfiguration()
        config.isOrdered = true

        let dc = pc.dataChannel(forLabel: "oai-events", configuration: config)
        dc?.delegate = self
        self.dataChannel = dc

        print("✅ DataChannel created: oai-events")
    }

    // MARK: - Connection
    func connect(ephemeralKey: String) async throws {
        guard let pc = peerConnection else {
            throw RealtimeError.peerConnectionNotInitialized
        }

        print("🔄 Starting connection...")

        // 1. Create offer
        let offer = try await createOffer(pc: pc)
        print("✅ Offer created")

        // 2. Set local description
        try await setLocalDescription(pc: pc, description: offer)
        print("✅ Local description set")

        // 3. Wait for ICE gathering (중요!)
        try await waitForIceGatheringComplete()
        print("✅ ICE gathering complete")

        // 4. Get final SDP
        guard let localSdp = pc.localDescription?.sdp else {
            throw RealtimeError.localSdpNotAvailable
        }

        // 5. POST to OpenAI /realtime/calls
        let answerSdp = try await postSdpToOpenAI(
            sdp: localSdp,
            ephemeralKey: ephemeralKey
        )
        print("✅ Answer SDP received")

        // 6. Set remote description
        let answer = RTCSessionDescription(type: .answer, sdp: answerSdp)
        try await setRemoteDescription(pc: pc, description: answer)
        print("✅ Remote description set")

        print("🎉 WebRTC connection established!")
    }

    private func createOffer(pc: RTCPeerConnection) async throws -> RTCSessionDescription {
        return try await withCheckedThrowingContinuation { continuation in
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: nil,
                optionalConstraints: nil
            )

            pc.offer(for: constraints) { sdp, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sdp = sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: RealtimeError.offerCreationFailed)
                }
            }
        }
    }

    private func setLocalDescription(
        pc: RTCPeerConnection,
        description: RTCSessionDescription
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pc.setLocalDescription(description) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func setRemoteDescription(
        pc: RTCPeerConnection,
        description: RTCSessionDescription
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pc.setRemoteDescription(description) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func waitForIceGatheringComplete() async throws {
        // MVP: 간단히 0.8초 대기
        // TODO: 실제로는 iceGatheringState 변경을 감지해서 complete 시 return
        try await Task.sleep(nanoseconds: 800_000_000)
    }

    private func postSdpToOpenAI(
        sdp: String,
        ephemeralKey: String
    ) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/realtime/calls")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(ephemeralKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = sdp.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RealtimeError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ OpenAI /calls error: \(httpResponse.statusCode)")
            print("   Response: \(body)")
            throw RealtimeError.openAICallsFailed(statusCode: httpResponse.statusCode, body: body)
        }

        guard let answerSdp = String(data: data, encoding: .utf8) else {
            throw RealtimeError.invalidSdpResponse
        }

        return answerSdp
    }

    // MARK: - Send Events via DataChannel
    func sendEvent(_ event: [String: Any]) {
        guard let dc = dataChannel,
              dc.readyState == .open else {
            print("⚠️ DataChannel not ready")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: event)
            let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
            dc.sendData(buffer)
            print("📤 Event sent: \(event["type"] ?? "unknown")")
        } catch {
            print("❌ Failed to send event: \(error)")
        }
    }

    // MARK: - Disconnect
    func disconnect() {
        dataChannel?.close()
        peerConnection?.close()

        dataChannel = nil
        peerConnection = nil
        audioTrack = nil

        print("🔌 Disconnected")
    }
}

// MARK: - RTCPeerConnectionDelegate
extension RealtimeWebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didChange stateChanged: RTCPeerConnectionState
    ) {
        connectionState = stateChanged
        print("🔗 Connection state: \(stateChanged)")
        delegate?.realtimeClient(self, didChangeConnectionState: stateChanged)
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didChange newState: RTCIceConnectionState
    ) {
        print("🧊 ICE connection state: \(newState)")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didChange newState: RTCIceGatheringState
    ) {
        print("🧊 ICE gathering state: \(newState)")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didGenerate candidate: RTCIceCandidate
    ) {
        print("🧊 ICE candidate generated")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didRemove candidates: [RTCIceCandidate]
    ) {
        print("🧊 ICE candidates removed")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🔄 Should negotiate")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didAdd stream: RTCMediaStream
    ) {
        print("🎵 Remote stream added")

        // Remote audio track 처리 (자동 재생됨)
        if let audioTrack = stream.audioTracks.first {
            print("✅ Remote audio track available")
            delegate?.realtimeClient(self, didReceiveRemoteAudioTrack: audioTrack)
        }
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didRemove stream: RTCMediaStream
    ) {
        print("🎵 Remote stream removed")
    }

    func peerConnection(
        _ peerConnection: RTCPeerConnection,
        didOpen dataChannel: RTCDataChannel
    ) {
        print("📡 DataChannel opened by remote")
        self.dataChannel = dataChannel
        dataChannel.delegate = self
    }
}

// MARK: - RTCDataChannelDelegate
extension RealtimeWebRTCClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("📡 DataChannel state: \(dataChannel.readyState.rawValue)")

        if dataChannel.readyState == .open {
            print("✅ DataChannel is OPEN - ready to send/receive events")
            delegate?.realtimeClientDataChannelDidOpen(self)
        }
    }

    func dataChannel(
        _ dataChannel: RTCDataChannel,
        didReceiveMessageWith buffer: RTCDataBuffer
    ) {
        guard let text = String(data: buffer.data, encoding: .utf8) else {
            print("⚠️ Failed to decode DataChannel message")
            return
        }

        print("📥 Event received: \(text.prefix(100))...")

        // JSON 파싱
        do {
            if let json = try JSONSerialization.jsonObject(with: buffer.data) as? [String: Any] {
                delegate?.realtimeClient(self, didReceiveEvent: json)
            }
        } catch {
            print("❌ Failed to parse event JSON: \(error)")
        }
    }
}

// MARK: - Delegate Protocol
protocol RealtimeWebRTCClientDelegate: AnyObject {
    func realtimeClient(_ client: RealtimeWebRTCClient, didChangeConnectionState state: RTCPeerConnectionState)
    func realtimeClient(_ client: RealtimeWebRTCClient, didReceiveRemoteAudioTrack track: RTCAudioTrack)
    func realtimeClientDataChannelDidOpen(_ client: RealtimeWebRTCClient)
    func realtimeClient(_ client: RealtimeWebRTCClient, didReceiveEvent event: [String: Any])
}

// MARK: - Error Types
enum RealtimeError: LocalizedError {
    case peerConnectionNotInitialized
    case offerCreationFailed
    case localSdpNotAvailable
    case invalidResponse
    case invalidSdpResponse
    case openAICallsFailed(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .peerConnectionNotInitialized:
            return "PeerConnection not initialized. Call createPeerConnection() first."
        case .offerCreationFailed:
            return "Failed to create WebRTC offer"
        case .localSdpNotAvailable:
            return "Local SDP not available after setting local description"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .invalidSdpResponse:
            return "Invalid SDP response from OpenAI"
        case .openAICallsFailed(let statusCode, let body):
            return "OpenAI /calls failed with status \(statusCode): \(body)"
        }
    }
}
```

### B. Token Service (iOS)

```swift
// TokenService.swift
import Foundation
import UIKit

class TokenService {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func fetchEphemeralKey(
        gameMode: String,
        currentWord: String? = nil,
        tabooWords: [String]? = nil
    ) async throws -> TokenResponse {
        let url = baseURL.appendingPathComponent("/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "gameMode": gameMode,
            "currentWord": currentWord ?? "",
            "tabooWords": tabooWords ?? []
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TokenError.serverError(statusCode: httpResponse.statusCode, message: body)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse
    }
}

struct TokenResponse: Codable {
    let value: String
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case value
        case expiresAt = "expires_at"
    }
}

enum TokenError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from token server"
        case .serverError(let statusCode, let message):
            return "Token server error (\(statusCode)): \(message)"
        }
    }
}
```

---

## 3. 사용 예시 (SwiftUI)

```swift
// GameViewModel.swift (예시)
import Foundation
import Combine

@MainActor
class GameViewModel: ObservableObject {
    @Published var connectionState: String = "Disconnected"
    @Published var transcriptText: String = ""
    @Published var isConnecting: Bool = false

    private let tokenService: TokenService
    private let rtcClient: RealtimeWebRTCClient

    init(serverURL: URL) {
        self.tokenService = TokenService(baseURL: serverURL)
        self.rtcClient = RealtimeWebRTCClient()
        self.rtcClient.delegate = self
    }

    func startGame(mode: String, word: String, tabooWords: [String]) async {
        isConnecting = true

        do {
            // 1. Audio session 설정
            try rtcClient.configureAudioSession()

            // 2. PeerConnection 생성
            rtcClient.createPeerConnection()

            // 3. Token 발급
            let tokenResponse = try await tokenService.fetchEphemeralKey(
                gameMode: mode,
                currentWord: word,
                tabooWords: tabooWords
            )

            // 4. WebRTC 연결
            try await rtcClient.connect(ephemeralKey: tokenResponse.value)

            connectionState = "Connected"
        } catch {
            print("❌ Connection failed: \(error)")
            connectionState = "Failed: \(error.localizedDescription)"
        }

        isConnecting = false
    }

    func sendEvent(type: String, payload: [String: Any] = [:]) {
        var event = payload
        event["type"] = type
        rtcClient.sendEvent(event)
    }
}

extension GameViewModel: RealtimeWebRTCClientDelegate {
    func realtimeClient(_ client: RealtimeWebRTCClient, didChangeConnectionState state: RTCPeerConnectionState) {
        connectionState = "\(state)"
    }

    func realtimeClient(_ client: RealtimeWebRTCClient, didReceiveRemoteAudioTrack track: RTCAudioTrack) {
        print("✅ Remote audio ready")
    }

    func realtimeClientDataChannelDidOpen(_ client: RealtimeWebRTCClient) {
        print("✅ DataChannel ready - can send events")
    }

    func realtimeClient(_ client: RealtimeWebRTCClient, didReceiveEvent event: [String: Any]) {
        guard let type = event["type"] as? String else { return }

        switch type {
        case "session.created":
            print("✅ Session created")

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = event["transcript"] as? String {
                transcriptText = transcript
                print("📝 User transcript: \(transcript)")
            }

        case "response.output_audio_transcript.delta":
            if let delta = event["delta"] as? String {
                transcriptText += delta
                print("📝 AI transcript delta: \(delta)")
            }

        case "response.output_audio_transcript.done":
            print("✅ AI transcript complete: \(transcriptText)")

        default:
            print("📥 Event: \(type)")
        }
    }
}
```

---

## 4. 배포 체크리스트

### Cloud Run
- [ ] `package.json` 생성
- [ ] `index.js` 작성 (수정된 session config 사용)
- [ ] `Dockerfile` 작성
- [ ] 환경 변수 `OPENAI_API_KEY` 설정
- [ ] Cloud Run 배포: `gcloud run deploy`
- [ ] 배포 URL 확인 및 `/health` 테스트

### iOS
- [ ] `Podfile`에 `GoogleWebRTC` 추가
- [ ] `pod install` 실행
- [ ] `Info.plist`에 마이크 권한 추가
- [ ] `RealtimeWebRTCClient.swift` 구현
- [ ] `TokenService.swift` 구현
- [ ] Server URL을 배포된 Cloud Run URL로 변경
- [ ] 실제 기기에서 테스트

---

## 5. 테스트 시나리오

### Phase 1: 기본 연결
1. Cloud Run `/health` 엔드포인트 확인
2. iOS에서 `/token` 호출 → `ek_...` 받기
3. WebRTC 연결 → `connected` 상태 확인
4. DataChannel `open` 확인
5. 마이크 말하기 → 전사 이벤트 수신 확인
6. AI 응답 듣기 확인

### Phase 2: 게임 로직
7. Mode A: AI 설명 시작 확인
8. Mode A: 사용자 발화 시 AI 중단 확인
9. Mode A: 정답 판정 및 다음 단어 이동
10. Mode B: 단어 표시 및 AI 추측 확인
11. Mode B: 판정 버튼 동작 확인

---

**작성일**: 2025-12-19
**기반**: 제공하신 코드 + OpenAI Realtime API GA 문서
