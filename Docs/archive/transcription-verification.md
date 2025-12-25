# Input Audio Transcription 활성화 검증

## 중요성

Session config에서 `audio.input.transcription`을 설정했더라도, 연결 후 실제로 활성화되었는지 **반드시 확인**해야 합니다. 전사가 활성화되지 않으면 게임의 핵심 기능(정답 판정)이 동작하지 않습니다.

## 검증 절차

### 1. Session Created 이벤트 확인

WebRTC 연결 직후 `session.created` 이벤트가 수신됩니다. 이 이벤트에서 transcription 설정을 확인합니다.

```swift
func handleServerEvent(_ event: [String: Any]) {
    guard let type = event["type"] as? String else { return }

    switch type {
    case "session.created":
        print("✅ Session created")

        // Transcription 설정 확인
        if let session = event["session"] as? [String: Any],
           let audio = session["audio"] as? [String: Any],
           let input = audio["input"] as? [String: Any],
           let transcription = input["transcription"] as? [String: Any],
           let model = transcription["model"] as? String {

            print("✅ Transcription enabled: \(model)")
            // 예상: "whisper-1"

        } else {
            print("⚠️ Transcription NOT enabled - will activate manually")
            // 수동으로 활성화 필요
            activateTranscription()
        }

    // ... other cases
    }
}
```

### 2. Session Created 이벤트 예시

**Transcription이 활성화된 경우:**

```json
{
  "type": "session.created",
  "event_id": "event_123",
  "session": {
    "id": "sess_abc123",
    "object": "realtime.session",
    "model": "gpt-realtime",
    "audio": {
      "input": {
        "turn_detection": {
          "type": "semantic_vad",
          "threshold": 0.5,
          "silence_duration_ms": 200,
          "prefix_padding_ms": 300
        },
        "transcription": {
          "model": "whisper-1"
        }
      },
      "output": {
        "voice": "marin"
      }
    }
  }
}
```

**Transcription이 활성화되지 않은 경우:**

```json
{
  "type": "session.created",
  "session": {
    "audio": {
      "input": {
        "turn_detection": { "type": "semantic_vad" }
        // transcription 필드 없음!
      },
      "output": { "voice": "marin" }
    }
  }
}
```

### 3. 수동으로 Transcription 활성화

만약 `session.created`에 transcription이 없다면, `session.update`로 활성화합니다.

```swift
func activateTranscription() {
    guard let dataChannel = dataChannel, dataChannel.readyState == .open else {
        print("❌ DataChannel not ready")
        return
    }

    let event: [String: Any] = [
        "type": "session.update",
        "session": [
            "type": "realtime",
            "audio": [
                "input": [
                    "transcription": [
                        "model": "whisper-1"
                    ]
                ]
            ]
        ]
    ]

    do {
        let jsonData = try JSONSerialization.data(withJSONObject: event)
        let buffer = RTCDataBuffer(data: jsonData, isBinary: false)
        dataChannel.sendData(buffer)
        print("📤 session.update sent to activate transcription")
    } catch {
        print("❌ Failed to send session.update: \(error)")
    }
}
```

### 4. Session Updated 이벤트 확인

`session.update`를 보낸 후 `session.updated` 이벤트가 수신되며, 업데이트된 설정을 확인할 수 있습니다.

```swift
case "session.updated":
    print("✅ Session updated")

    // 동일한 방식으로 transcription 확인
    if let session = event["session"] as? [String: Any],
       let audio = session["audio"] as? [String: Any],
       let input = audio["input"] as? [String: Any],
       let transcription = input["transcription"] as? [String: Any] {

        print("✅ Transcription now active: \(transcription)")
    }
```

## 전사 이벤트 확인

Transcription이 활성화되면 다음 이벤트들이 수신됩니다:

### A. Input Audio Transcription (사용자 발화)

```swift
case "conversation.item.input_audio_transcription.completed":
    if let transcript = event["transcript"] as? String {
        print("📝 User said: \(transcript)")
        // 게임 로직: 정답 판정
        judgeAnswer(userAnswer: transcript)
    }

case "conversation.item.input_audio_transcription.delta":
    // 실시간 전사 업데이트 (옵션)
    if let delta = event["delta"] as? String {
        print("📝 Delta: \(delta)")
        updateLiveTranscript(delta)
    }
```

### B. Output Audio Transcript (AI 발화)

```swift
case "response.output_audio_transcript.delta":
    if let delta = event["delta"] as? String {
        print("🤖 AI delta: \(delta)")
        updateAITranscript(delta)
    }

case "response.output_audio_transcript.done":
    if let transcript = event["transcript"] as? String {
        print("🤖 AI said: \(transcript)")
    }
```

## 디버깅 체크리스트

Phase 1에서 반드시 확인해야 할 사항:

- [ ] `session.created` 이벤트 수신
- [ ] `session.audio.input.transcription.model === "whisper-1"` 확인
- [ ] (필요시) `session.update` 전송 및 `session.updated` 수신
- [ ] 말하기 테스트 후 `input_audio_buffer.speech_started` 수신
- [ ] `conversation.item.input_audio_transcription.completed` 수신
- [ ] 전사된 텍스트가 UI에 표시됨
- [ ] AI 응답 후 `response.output_audio_transcript.delta` 수신

## 문제 해결

### 전사 이벤트가 수신되지 않는 경우

1. **Server config 확인**
   - Backend `index.js`에서 `transcription: { model: "whisper-1" }` 포함 확인

2. **DataChannel 상태 확인**
   ```swift
   print("DataChannel state: \(dataChannel.readyState.rawValue)")
   // 0: connecting, 1: open, 2: closing, 3: closed
   ```

3. **모든 서버 이벤트 로깅**
   ```swift
   func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
       let text = String(data: buffer.data, encoding: .utf8) ?? ""
       print("📥 RAW EVENT: \(text)")  // 모든 이벤트 출력

       // JSON 파싱...
   }
   ```

4. **VAD 동작 확인**
   - `input_audio_buffer.speech_started` 이벤트가 먼저 수신되어야 함
   - VAD가 동작하지 않으면 전사도 시작되지 않음

### VAD가 동작하지 않는 경우

```swift
// session.update로 VAD 재설정
let event: [String: Any] = [
    "type": "session.update",
    "session": [
        "type": "realtime",
        "audio": [
            "input": [
                "turn_detection": [
                    "type": "semantic_vad",
                    "threshold": 0.3,  // 더 민감하게 (기본 0.5)
                    "silence_duration_ms": 500,
                    "prefix_padding_ms": 300
                ]
            ]
        ]
    ]
]
```

## 코드 템플릿

완전한 검증 코드:

```swift
// RealtimeWebRTCClient.swift

var isTranscriptionActive = false

func handleServerEvent(_ event: [String: Any]) {
    guard let type = event["type"] as? String else { return }

    print("📥 Event: \(type)")

    switch type {
    case "session.created":
        verifyTranscriptionEnabled(in: event)

    case "session.updated":
        verifyTranscriptionEnabled(in: event)

    case "input_audio_buffer.speech_started":
        print("🎤 User started speaking")

    case "input_audio_buffer.speech_stopped":
        print("🎤 User stopped speaking")

    case "conversation.item.input_audio_transcription.completed":
        handleUserTranscript(event)

    case "response.output_audio_transcript.delta":
        handleAITranscriptDelta(event)

    default:
        break
    }
}

private func verifyTranscriptionEnabled(in event: [String: Any]) {
    if let session = event["session"] as? [String: Any],
       let audio = session["audio"] as? [String: Any],
       let input = audio["input"] as? [String: Any],
       let transcription = input["transcription"] as? [String: Any],
       let model = transcription["model"] as? String {

        print("✅ Transcription active: \(model)")
        isTranscriptionActive = true

    } else {
        print("⚠️ Transcription NOT active - activating now")
        isTranscriptionActive = false
        activateTranscription()
    }
}

private func handleUserTranscript(_ event: [String: Any]) {
    guard let transcript = event["transcript"] as? String else { return }

    print("📝 User transcript: \(transcript)")
    delegate?.realtimeClient(self, didReceiveUserTranscript: transcript)
}

private func handleAITranscriptDelta(_ event: [String: Any]) {
    guard let delta = event["delta"] as? String else { return }

    print("🤖 AI delta: \(delta)")
    delegate?.realtimeClient(self, didReceiveAITranscriptDelta: delta)
}
```

---

**작성일**: 2025-12-19
**Phase**: Phase 1 검증 단계
**중요도**: 🔴 Critical - 전사가 없으면 게임 동작 불가
