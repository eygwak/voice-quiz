# VoiceQuiz WebRTC 연결 흐름 (Ephemeral Token 방식)

## 📊 시퀀스 다이어그램

```
iOS 앱                Cloud Run 서버            OpenAI Realtime API
  │                         │                           │
  │  1. POST /token         │                           │
  │  (gameMode, word, ...)  │                           │
  ├────────────────────────>│                           │
  │                         │  2. POST /client_secrets  │
  │                         │  (session config)         │
  │                         ├─────────────────────────>│
  │                         │                           │
  │                         │  3. { value, expires_at } │
  │                         │<─────────────────────────┤
  │  4. { value, expires_at }│                          │
  │<────────────────────────┤                           │
  │                         │                           │
  │  5. createOffer()       │                           │
  │  setLocalDescription()  │                           │
  │                         │                           │
  │  6. POST /realtime/calls│                           │
  │  (Bearer token, SDP)    │                           │
  ├───────────────────────────────────────────────────>│
  │                         │                           │
  │  7. Answer SDP          │                           │
  │<───────────────────────────────────────────────────┤
  │                         │                           │
  │  8. setRemoteDescription()                          │
  │                         │                           │
  │  9. WebRTC Connected    │                           │
  │<═══════════════════════════════════════════════════>│
  │   (Audio + DataChannel) │                           │
```

---

## 🔄 단계별 상세 설명

### 1️⃣ iOS 앱 → Cloud Run: 토큰 요청

**엔드포인트**: `POST https://your-server.run.app/token`

**요청 Body**:
```json
{
  "deviceId": "ABC123...",
  "platform": "ios",
  "appVersion": "1.0.0",
  "gameMode": "modeA",
  "currentWord": "apple",
  "tabooWords": ["fruit", "red"]
}
```

**목적**:
- Ephemeral token 발급 요청
- 게임 모드와 현재 단어 정보 전달
- 서버가 적절한 instructions 생성하도록 함

---

### 2️⃣ Cloud Run → OpenAI: Session 생성

**엔드포인트**: `POST https://api.openai.com/v1/realtime/client_secrets`

**요청 Headers**:
```
Authorization: Bearer YOUR_OPENAI_API_KEY
Content-Type: application/json
```

**요청 Body**:
```json
{
  "session": {
    "type": "realtime",
    "model": "gpt-realtime",
    "instructions": "# Role\nYou are the host...\n[동적 생성된 instructions]",
    "audio": {
      "output": {
        "voice": "marin"
      },
      "input": {
        "turn_detection": {
          "type": "semantic_vad"
        }
      }
    }
  }
}
```

**핵심**:
- `instructions`에 `currentWord`와 `tabooWords` 포함
- 게임 모드에 따라 다른 instructions 사용
- 서버가 OpenAI API Key를 사용하므로 클라이언트에 노출 안 됨

---

### 3️⃣ OpenAI → Cloud Run: Ephemeral Token 응답

**응답 Body**:
```json
{
  "value": "ek_68af296e8e408191a1120ab6383263c2",
  "expires_at": "2024-12-20T12:00:00Z"
}
```

**특징**:
- `value`: 클라이언트가 사용할 임시 토큰 (접두사 `ek_`)
- `expires_at`: 토큰 만료 시간 (일반적으로 발급 후 몇 시간)

---

### 4️⃣ Cloud Run → iOS: Token 전달

서버는 OpenAI의 응답을 **그대로** iOS 앱에 전달합니다.

```json
{
  "value": "ek_68af296e8e408191a1120ab6383263c2",
  "expires_at": "2024-12-20T12:00:00Z"
}
```

---

### 5️⃣ iOS: WebRTC Offer 생성

```swift
// RTCPeerConnection 생성
let peerConnection = createPeerConnection()

// Offer 생성
let offer = try await peerConnection.offer(for: constraints)

// Local Description 설정
try await peerConnection.setLocalDescription(offer)
```

**생성되는 것**:
- SDP (Session Description Protocol) offer
- 로컬 오디오 track 정보
- ICE candidate 정보

---

### 6️⃣ iOS → OpenAI: SDP Offer 전송

**엔드포인트**: `POST https://api.openai.com/v1/realtime/calls`

**요청 Headers**:
```
Authorization: Bearer ek_68af296e8e408191a1120ab6383263c2
Content-Type: application/sdp
```

**요청 Body** (텍스트):
```
v=0
o=- 123456789 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
...
m=audio 9 UDP/TLS/RTP/SAVPF 111 103 104
...
```

**핵심**:
- 직접 OpenAI API를 호출 (서버를 거치지 않음)
- Ephemeral token을 Authorization 헤더에 사용
- Body는 SDP 텍스트 (JSON 아님)

---

### 7️⃣ OpenAI → iOS: SDP Answer 응답

**응답 Body** (텍스트):
```
v=0
o=- 987654321 2 IN IP4 10.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
...
m=audio 9 UDP/TLS/RTP/SAVPF 111
...
```

**특징**:
- OpenAI가 생성한 SDP answer
- OpenAI의 미디어 설정과 코덱 정보 포함

---

### 8️⃣ iOS: Remote Description 설정

```swift
let answerSDP = String(data: responseData, encoding: .utf8)!
let answer = RTCSessionDescription(type: .answer, sdp: answerSDP)
try await peerConnection.setRemoteDescription(answer)
```

**효과**:
- WebRTC 연결 협상 완료
- ICE candidate 교환 시작
- 곧 연결 상태가 `connected`로 변경됨

---

### 9️⃣ WebRTC 연결 완료

**연결된 후 사용 가능**:

1. **Audio Track** (자동 처리)
   - iOS 마이크 → OpenAI (자동 전송)
   - OpenAI 음성 → iOS 스피커 (자동 재생)

2. **DataChannel** (`oai-events`)
   - Client Events 전송 (JSON)
   - Server Events 수신 (JSON)

```swift
// DataChannel을 통해 메시지 전송
let event = ["type": "response.create"]
let data = try JSONSerialization.data(withJSONObject: event)
dataChannel.sendData(RTCDataBuffer(data: data, isBinary: false))
```

---

## 🔑 핵심 포인트

### 1. **두 단계 인증**
- 1단계: 서버가 OpenAI API Key로 Ephemeral Token 발급
- 2단계: iOS가 Ephemeral Token으로 WebRTC 연결

### 2. **서버 역할**
- ✅ Ephemeral Token 발급
- ✅ Instructions 동적 생성 (단어별)
- ✅ OpenAI API Key 보호
- ✅ Rate limiting
- ❌ WebRTC 트래픽은 처리 안 함 (iOS ↔ OpenAI 직접 연결)

### 3. **보안**
- OpenAI API Key는 절대 iOS 앱에 노출되지 않음
- Ephemeral Token은 시간 제한이 있음 (만료됨)
- Rate limiting으로 남용 방지

### 4. **비용 효율**
- WebRTC 트래픽이 서버를 거치지 않음 (P2P)
- 서버는 토큰 발급만 처리 (부하 낮음)
- Cloud Run은 요청당 과금 (idle 시 무료)

---

## 🚨 주의사항

### Token 만료 처리
```swift
// Token이 만료되면 새로 발급 필요
if ephemeralTokenExpired {
    let newToken = try await fetchEphemeralToken(...)
    // 새 연결 시작
    try await connect(...)
}
```

### 연결 실패 시나리오
1. **서버 응답 없음**: 네트워크 에러 또는 서버 다운
2. **OpenAI 429 에러**: Rate limit 초과
3. **WebRTC 연결 실패**: ICE candidate 문제, 방화벽

### Mode A에서 단어 변경 시
- 새 단어마다 **새 Token 발급 필요**
- 이유: Instructions에 `currentWord`와 `tabooWords`가 포함되므로
- 해결: 각 단어 시작 전에 `fetchEphemeralToken()` 재호출

---

## 📝 체크리스트

### 서버 구현
- [ ] `POST /token` 엔드포인트 생성
- [ ] gameMode에 따른 instructions 템플릿 작성
- [ ] OpenAI API 호출 및 에러 처리
- [ ] Rate limiting 구현
- [ ] 로깅 (성공/실패/지연)

### iOS 구현
- [ ] `fetchEphemeralToken()` 함수 구현
- [ ] RTCPeerConnection 생성 및 설정
- [ ] Offer 생성 및 setLocalDescription
- [ ] OpenAI `/realtime/calls` 호출
- [ ] Answer 수신 및 setRemoteDescription
- [ ] DataChannel 이벤트 핸들러
- [ ] 연결 상태 모니터링

### 테스트
- [ ] 토큰 발급 성공
- [ ] WebRTC 연결 성공
- [ ] 양방향 오디오 통신 확인
- [ ] DataChannel 메시지 송수신 확인
- [ ] Token 만료 후 재발급 테스트
- [ ] 네트워크 끊김 시나리오 테스트

---

**작성일**: 2025-12-19
**참고**: [dev-plan.md](dev-plan.md)
