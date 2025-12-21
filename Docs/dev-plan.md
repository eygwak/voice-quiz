# VoiceQuiz 개발 계획서

## 📋 결정 사항 요약

### 기술 스택
- **클라이언트**: iOS Native (SwiftUI, MVVM)
- **서버**: Google Cloud Run (Node.js/Express)
- **연결**: WebRTC + DataChannel
- **음성 AI**: OpenAI Realtime API (gpt-realtime)
- **로컬 저장**: UserDefaults + JSON 파일

### 주요 결정
- ✅ Cloud Run 서버 새로 구축 필요
- ✅ **연결 방식**: Ephemeral Token 방식 사용
- ✅ Mode A와 Mode B 동시 진행 (공통 구조 먼저 개발)
- ✅ AI Instructions는 서버에서 관리 (session config에 포함)
- ✅ 단어 데이터는 이미 준비됨
- ✅ 개발: 시뮬레이터 + 실제 기기 병행
- ✅ 끼어들기: `response.cancel` 사용
- ✅ AI 추측: 고정 2초 타이머 (초기)
- ✅ 저장소: UserDefaults (설정/점수/인덱스) + JSON 파일 (히스토리)

---

## 🏗️ 프로젝트 구조

```
VoiceQuiz/
├── VoiceQuiz/
│   ├── VoiceQuizApp.swift
│   ├── UI/
│   │   ├── HomeView.swift
│   │   ├── GameView_ModeA.swift
│   │   ├── GameView_ModeB.swift
│   │   ├── ResultView.swift
│   │   └── Components/
│   │       ├── TranscriptView.swift
│   │       ├── TimerView.swift
│   │       ├── ScoreView.swift
│   │       └── JudgmentButtons.swift
│   ├── ViewModels/
│   │   ├── GameViewModel_ModeA.swift
│   │   ├── GameViewModel_ModeB.swift
│   │   └── HomeViewModel.swift
│   ├── Game/
│   │   ├── GameState.swift
│   │   ├── GameTimer.swift
│   │   ├── ScoreManager.swift
│   │   ├── WordManager.swift
│   │   └── AnswerJudge.swift
│   ├── Realtime/
│   │   ├── RealtimeClient.swift
│   │   ├── WebRTCManager.swift
│   │   ├── DataChannelManager.swift
│   │   └── RealtimeEvents.swift
│   ├── Audio/
│   │   ├── AudioSessionManager.swift
│   │   └── AudioPlayer.swift
│   ├── Data/
│   │   ├── Models/
│   │   │   ├── Word.swift
│   │   │   ├── Category.swift
│   │   │   ├── GameSession.swift
│   │   │   └── GameHistory.swift
│   │   ├── Persistence/
│   │   │   ├── UserDefaultsManager.swift
│   │   │   └── HistoryManager.swift
│   │   └── words.json
│   └── Utils/
│       ├── StringSimilarity.swift
│       └── Constants.swift
└── VoiceQuizTests/
```

---

## 📅 개발 로드맵 (4 Phases)

### **Phase 0: 준비 및 기반 구축** (1-2일)
**목표**: 프로젝트 초기 설정 및 Cloud Run 서버 구축

#### Backend (Cloud Run)
- [ ] Node.js/Express 프로젝트 생성
- [ ] **`POST /token` 엔드포인트 구현** (Ephemeral Token 발급)
  - 요청: `{ deviceId, platform, appVersion?, gameMode, currentWord?, tabooWords? }`
  - 내부에서 `POST https://api.openai.com/v1/realtime/client_secrets` 호출
  - Session config 생성:
    - `type: "realtime"`
    - `model: "gpt-realtime"`
    - `instructions`: gameMode에 따라 동적 생성 (currentWord, tabooWords 포함)
    - `audio.output.voice: "marin"`
    - `audio.input.turn_detection: { type: "semantic_vad" }`
  - 응답 JSON 그대로 iOS에 전달: `{ value: "ek_...", expires_at: "..." }`
- [ ] Rate limiting 구현 (선택)
  - ⚠️ **중요**: Cloud Run은 여러 인스턴스로 스케일되므로 인메모리 방식 효과 없음
  - **MVP 옵션 1**: `max-instances=1` + express-rate-limit (간단, 확장성 낮음)
  - **권장 옵션 2**: Redis/Firestore 기반 분산 rate limiting (프로덕션 적합)
  - 상세 구현은 `Backend/README.md` 참고
- [ ] Cloud Run 배포 설정
- [ ] 환경 변수 설정 (OPENAI_API_KEY)
- [ ] 로깅 설정 (성공/실패/지연/429)
- [ ] Health check 엔드포인트 (`GET /health`)

#### iOS Project Setup
- [ ] GoogleWebRTC SDK 추가 (SPM 또는 CocoaPods)
- [ ] 디렉토리 구조 생성 (UI/, ViewModels/, Game/, etc.)
- [ ] Info.plist 권한 설정
  - NSMicrophoneUsageDescription: "VoiceQuiz needs access to your microphone to play the voice quiz game."

#### Data Models
- [ ] `Word.swift` 모델 정의
  ```swift
  struct Word: Codable {
      let word: String
      let synonyms: [String]
      let difficulty: Int
      let taboo: [String]
  }
  ```
- [ ] `Category.swift` 모델 정의
- [ ] `GameSession.swift` 모델 정의
- [ ] `words.json` 파일 번들에 추가 및 파싱 테스트

---

### **Phase 1: WebRTC 연결 및 기본 통신** (2-3일)
**목표**: OpenAI Realtime API와 WebRTC 연결 확립, 양방향 음성 통신 성공

#### WebRTC Core
- [ ] `WebRTCManager.swift` 구현
  - RTCPeerConnection 생성 및 설정
  - Audio track 추가 (마이크 입력)
  - Remote audio track 수신 및 재생
  - ICE candidate 처리
  - Connection state 모니터링

- [ ] `DataChannelManager.swift` 구현
  - DataChannel 생성 ("oai-events")
  - 메시지 송수신 인터페이스
  - JSON 직렬화/역직렬화

- [ ] `RealtimeClient.swift` 구현 (Ephemeral Token 방식)
  - **1단계**: 서버에서 토큰 발급 (`POST /token`)
    - 요청: `{ deviceId, platform, gameMode, currentWord, tabooWords }`
    - 응답: `{ value: "ek_...", expires_at: "..." }` 받기
  - **2단계**: WebRTC Offer 생성
    - `RTCPeerConnection.offer()` 호출
    - `setLocalDescription(offer)` 설정
  - **3단계**: OpenAI에 직접 SDP 전송
    - `POST https://api.openai.com/v1/realtime/calls`
    - Headers: `Authorization: Bearer {EPHEMERAL_KEY}`, `Content-Type: application/sdp`
    - Body: `offer.sdp` (텍스트)
  - **4단계**: Answer SDP 수신 및 설정
    - 응답 텍스트를 `answer.sdp`로 파싱
    - `setRemoteDescription(answer)` 호출
  - 연결 lifecycle 관리
  - 연결 에러 핸들링

- [ ] `RealtimeEvents.swift` 정의
  - Client Events (Codable structs)
    - `SessionUpdate`
    - `ConversationItemCreate`
    - `ResponseCreate`
    - `ResponseCancel`
  - Server Events
    - `SessionCreated`
    - `InputAudioBufferSpeechStarted`
    - `InputAudioBufferSpeechStopped`
    - `ConversationItemInputAudioTranscriptionCompleted`
    - `ResponseOutputAudioTranscriptDelta`
    - `ResponseOutputAudioTranscriptDone`

#### Audio Session
- [ ] `AudioSessionManager.swift` 구현
  - AVAudioSession 설정
    - Category: `.playAndRecord`
    - Mode: `.voiceChat`
    - Options: `[.defaultToSpeaker, .allowBluetooth]`
  - 오디오 interruption 처리
  - 권한 요청

#### Session Configuration Verification
- [ ] 연결 후 `session.created` 이벤트 확인
  - `session.audio.input.transcription` 필드 확인
  - `model: "whisper-1"` 설정 확인
- [ ] (필요시) `session.update`로 transcription 활성화
  ```swift
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
  dataChannel.send(event)
  ```

#### Test UI
- [ ] 간단한 테스트 화면 생성
  - 연결 버튼
  - 연결 상태 표시
  - 전사 텍스트 표시
  - 말하기 테스트
  - AI 응답 듣기 테스트

#### 검증 포인트
- ✓ WebRTC 연결 성공 (`connected` state)
- ✓ 마이크 입력이 OpenAI로 전송됨
- ✓ AI 음성 응답이 스피커로 출력됨
- ✓ DataChannel을 통해 이벤트 송수신 확인
- ✓ `session.created` 이벤트 수신 및 transcription 설정 확인
- ✓ `input_audio_buffer.speech_started` 이벤트 수신 (VAD 동작)
- ✓ `conversation.item.input_audio_transcription.completed` 이벤트 수신
- ✓ Realtime transcription delta 수신 및 표시

---

### **Phase 2: 게임 핵심 로직 및 공통 기능** (3-4일)
**목표**: 양쪽 모드에서 사용할 공통 게임 로직 구현

#### Game Core
- [ ] `GameState.swift` - 게임 상태 관리
  ```swift
  enum GamePhase {
      case ready
      case playing
      case paused
      case finished
  }

  enum GameMode {
      case modeA  // AI describes, user guesses
      case modeB  // User describes, AI guesses
  }
  ```

- [ ] `GameTimer.swift` - 60초 타이머
  - Countdown 로직
  - 남은 시간 이벤트
  - Pause/Resume
  - 시간 종료 알림

- [ ] `WordManager.swift` - 단어 관리
  - words.json 로드
  - 카테고리별 필터링
  - 랜덤 단어 선택
  - 단어 진행 상태 추적
  - Pass 카운트 (최대 2회)

- [ ] `AnswerJudge.swift` - 정답 판정 (Mode A용)
  - 문자열 정규화 (lowercase, trim, remove punctuation)
  - Levenshtein distance 계산
  - Similarity 점수 계산
  - 판정 로직:
    - Exact match or synonym → Correct
    - Similarity ≥ 0.90 → Correct
    - Similarity 0.80-0.89 → Close
    - Else → Incorrect

- [ ] `ScoreManager.swift` - 점수 관리
  - 현재 점수 추적
  - 최고 점수 로드/저장 (UserDefaults)
  - 모드별 최고 점수 분리

#### Persistence
- [ ] `UserDefaultsManager.swift`
  - Best scores (Mode A, Mode B)
  - Settings (선택된 카테고리 등)
  - History index (최근 100개 게임 메타데이터)

- [ ] `HistoryManager.swift`
  - 게임 세션을 JSON 파일로 저장
  - 파일명: `game_session_<timestamp>.json`
  - 저장 내용:
    - Mode, category, score
    - 각 단어별 transcript 및 판정
    - 시작/종료 시간

#### Common UI Components
- [ ] `TranscriptView.swift` - 실시간 자막 표시
  - Streaming delta updates
  - User/AI 구분 표시
  - Auto-scroll

- [ ] `TimerView.swift` - 타이머 표시
  - 원형 progress bar
  - 남은 시간 숫자 표시
  - 시간 경고 (10초 이하 빨간색)

- [ ] `ScoreView.swift` - 점수 표시
  - 현재 점수
  - 최고 점수 비교

#### 검증 포인트
- ✓ 60초 타이머 정확히 동작
- ✓ 단어 랜덤 선택 및 중복 방지
- ✓ Pass 기능 (최대 2회)
- ✓ 정답 판정 알고리즘 정확도 테스트
- ✓ 점수 저장/로드 정상 동작

---

### **Phase 3A: Mode A 구현 (AI 설명 → 사용자 맞히기)** (3-4일)
**목표**: 끼어들기와 실시간 판정이 포함된 Mode A 완성

#### Mode A Game Logic
- [ ] `GameViewModel_ModeA.swift` 구현
  - State machine:
    ```
    WAITING_TO_START
    → AI_DESCRIBING
    → USER_SPEAKING (interrupt)
    → JUDGING
    → [Correct] NEXT_WORD
    → [Close/Incorrect] AI_DESCRIBING (continue)
    → ROUND_FINISHED
    ```
  - 게임 시작 시:
    - 첫 번째 단어 선택
    - AI에게 `session.update` + instructions 전송
    - AI에게 단어 설명 요청 (`response.create`)

  - 사용자 발화 감지 시:
    - `input_audio_buffer.speech_started` 수신
    - AI 응답 중단 (`response.cancel` 전송)
    - 로컬 오디오 출력 중단

  - 전사 완료 시:
    - `conversation.item.input_audio_transcription.completed` 수신
    - 정답 판정 실행 (AnswerJudge)
    - 판정 결과에 따른 처리:
      - **Correct**:
        - 점수 +1
        - 피드백 ("Correct!")
        - 다음 단어로 이동
      - **Close**:
        - 피드백 ("Close!")
        - AI가 계속 설명하도록 `response.create`
      - **Incorrect**:
        - 피드백 ("Try again!")
        - AI가 계속 설명하도록 `response.create`

  - Pass 버튼:
    - Pass 카운트 증가 (최대 2회)
    - AI 응답 중단
    - 다음 단어로 이동

#### Mode A UI
- [ ] `GameView_ModeA.swift` 구현
  - 타이머 표시 (상단)
  - 점수 표시
  - AI 전사 표시 (AI가 말하는 내용)
  - 사용자 전사 표시 (사용자가 말하는 내용)
  - Pass 버튼 (남은 횟수 표시)
  - 판정 피드백 애니메이션
  - 게임 종료 시 ResultView로 이동

#### AI Instructions for Mode A
서버에서 전달할 instructions (예시):
```markdown
# Role
You are the host of a speed quiz game. Your job is to describe words so the user can guess them.

# Rules
- NEVER say the target word, its spelling, or direct synonyms
- Use indirect, natural descriptions like "You use this when..." or "You usually see this in..."
- Keep descriptions SHORT (1-2 sentences at a time)
- If the user says something close, provide additional hints
- If the user is correct, immediately stop and wait for the next word
- The taboo words for the current word are: [TABOO_WORDS]

# Current Word
The word you need to describe is: [CURRENT_WORD]

# Language
- Speak only in English
- Use clear, natural pronunciation
```

#### 검증 포인트
- ✓ AI가 단어 설명 시작
- ✓ 사용자 발화 시 AI 즉시 중단
- ✓ 정답 판정 정확도
- ✓ Correct 시 다음 단어로 자동 이동
- ✓ Close/Incorrect 시 AI 설명 재개
- ✓ Pass 기능 정상 동작
- ✓ 60초 후 게임 종료 및 결과 화면 이동

---

### **Phase 3B: Mode B 구현 (사용자 설명 → AI 맞히기)** (3-4일)
**목표**: AI 추측 타이밍과 버튼 판정이 포함된 Mode B 완성

#### Mode B Game Logic
- [ ] `GameViewModel_ModeB.swift` 구현
  - State machine:
    ```
    WAITING_TO_START
    → SHOWING_WORD
    → USER_DESCRIBING
    → AI_GUESSING
    → WAITING_FOR_JUDGMENT
    → [Correct] NEXT_WORD
    → [Close/Incorrect] USER_DESCRIBING (continue)
    → ROUND_FINISHED
    ```

  - 게임 시작 시:
    - 첫 번째 단어 선택
    - 사용자에게 단어 표시
    - AI에게 `session.update` + instructions 전송
    - 사용자 설명 대기

  - AI 추측 타이밍 (2초 타이머):
    - 사용자 발화 시작 후 2초마다 AI 추측 트리거
    - `response.create` 전송 (AI가 추측하도록)
    - AI 추측 완료 대기

  - AI 추측 수신:
    - `response.output_audio_transcript.done` 수신
    - 판정 버튼 활성화 (Correct/Close/Incorrect)

  - 판정 버튼 클릭:
    - **Correct**:
      - 점수 +1
      - 다음 단어로 이동
    - **Close/Incorrect**:
      - AI에게 피드백 전달 (DataChannel)
      - 사용자가 계속 설명 가능
      - 2초 후 다시 AI 추측

  - Pass 버튼:
    - Pass 카운트 증가 (최대 2회)
    - 다음 단어로 이동

#### Mode B UI
- [ ] `GameView_ModeB.swift` 구현
  - 타이머 표시 (상단)
  - 점수 표시
  - **현재 단어 표시** (크게, 중앙)
  - 사용자 전사 표시 (사용자가 설명하는 내용)
  - AI 전사 표시 (AI가 추측하는 내용)
  - 판정 버튼 (Correct/Close/Incorrect)
    - AI 추측 완료 후에만 활성화
    - 명확한 색상 구분 (Green/Yellow/Red)
  - Pass 버튼 (남은 횟수 표시)
  - 게임 종료 시 ResultView로 이동

- [ ] `JudgmentButtons.swift` - 판정 버튼 컴포넌트
  - Correct (초록색)
  - Close (노란색)
  - Incorrect (빨간색)
  - 비활성화 상태 처리

#### AI Instructions for Mode B
서버에서 전달할 instructions (예시):
```markdown
# Role
You are a player in a speed quiz game trying to GUESS the word based on the user's description.

# Rules
- NEVER ask questions like "Is it...?" or "Does it...?"
- ONLY make direct guesses in the format: "I think it is [WORD]" or simply "[WORD]"
- Listen carefully to the user's description
- Make educated guesses based on the clues
- If you get "Close" feedback, try related words
- If you get "Incorrect" feedback, try completely different words
- Keep your guesses SHORT and CLEAR

# Current Game State
The user is describing a word from the category: [CATEGORY]

# Language
- Listen in English
- Respond only in English
- Use clear, natural pronunciation
```

#### 검증 포인트
- ✓ 사용자에게 단어가 명확히 표시됨
- ✓ 사용자 발화가 실시간으로 전사됨
- ✓ 2초마다 AI가 추측함
- ✓ AI 추측이 명확하게 들림
- ✓ 판정 버튼이 AI 추측 후에만 활성화
- ✓ Correct 판정 시 다음 단어로 이동
- ✓ Close/Incorrect 판정 시 게임 계속
- ✓ Pass 기능 정상 동작
- ✓ 60초 후 게임 종료

---

### **Phase 4: UI/UX 완성 및 튜닝** (2-3일)
**목표**: 최종 UI 개선, 피드백 효과, 결과 화면 구현

#### Home Screen
- [ ] `HomeView.swift` 구현
  - 앱 타이틀/로고
  - 모드 선택 (Mode A / Mode B)
    - 각 모드 설명 텍스트
  - 카테고리 선택 (Food/Animals/Jobs/Objects/Minecraft)
  - Best Score 표시 (모드별)
  - Start 버튼
  - Settings 버튼 (옵션)

- [ ] `HomeViewModel.swift` 구현
  - 선택 상태 관리
  - 최고 점수 로드
  - 네비게이션 로직

#### Result Screen
- [ ] `ResultView.swift` 구현
  - 최종 점수 (크게 표시)
  - 최고 점수와 비교
    - 신기록 달성 시 축하 애니메이션
  - 맞힌 단어 목록 (옵션)
  - 버튼:
    - Play Again (같은 모드/카테고리)
    - Home (홈으로)
    - View History (히스토리 보기, 옵션)

#### Feedback & Effects
- [ ] 판정 피드백 구현
  - **Correct**:
    - 음성: "Correct!" / "Great!" / "Yes!"
    - 시각: 초록색 플래시 애니메이션
    - 햅틱: Success feedback
  - **Close**:
    - 음성: "Close!" / "Almost!"
    - 시각: 노란색 애니메이션
    - 햅틱: Warning feedback
  - **Incorrect**:
    - 음성: "Try again!" / "Not quite!"
    - 시각: 부드러운 흔들림
    - 햅틱: Error feedback

- [ ] 효과음 추가 (옵션)
  - 정답 사운드
  - 시간 경고 사운드 (10초 남음)
  - 게임 종료 사운드

#### Polish & Optimization
- [ ] 에러 처리 개선
  - 네트워크 연결 실패
  - 마이크 권한 거부
  - WebRTC 연결 실패
  - 서버 오류 (rate limit, 429 등)
  - 사용자 친화적 에러 메시지

- [ ] 로딩 상태 표시
  - WebRTC 연결 중
  - AI 응답 대기 중
  - Skeleton UI

- [ ] 성능 최적화
  - 메모리 누수 체크
  - WebRTC 연결 정리
  - 불필요한 상태 업데이트 제거

- [ ] 다크 모드 지원 (옵션)

- [ ] 접근성 개선
  - VoiceOver 지원
  - 동적 타입 지원
  - 색상 대비 검증

#### 검증 포인트
- ✓ 모든 화면 간 네비게이션 정상 동작
- ✓ 최고 점수 저장/로드 확인
- ✓ 판정 피드백이 명확하고 직관적
- ✓ 에러 발생 시 앱이 크래시하지 않음
- ✓ 메모리 누수 없음
- ✓ 실제 기기에서 부드럽게 동작

---

## 🧪 테스트 전략

### Unit Tests
- [ ] `AnswerJudge` - 정답 판정 로직
- [ ] `StringSimilarity` - Levenshtein distance 계산
- [ ] `WordManager` - 단어 선택 로직
- [ ] `ScoreManager` - 점수 저장/로드

### Integration Tests
- [ ] WebRTC 연결 성공 시나리오
- [ ] DataChannel 메시지 송수신
- [ ] 게임 전체 플로우 (시작 → 종료)

### Manual Tests
- [ ] Mode A 완전한 라운드 플레이
- [ ] Mode B 완전한 라운드 플레이
- [ ] Pass 기능 (0, 1, 2회 사용)
- [ ] 네트워크 끊김 시나리오
- [ ] 백그라운드/포그라운드 전환
- [ ] 실제 기기에서 마이크/스피커 테스트

---

## 📝 개발 시 주의사항

### WebRTC
- RTCPeerConnection을 메인 스레드에서 생성해야 함
- DataChannel은 connection이 `connected` 상태일 때만 사용
- Audio session은 사용 전에 activate 필요
- 연결 종료 시 반드시 cleanup (메모리 누수 방지)

### Realtime API
- `session.update`는 세션 시작 후 언제든 가능
- `response.cancel`은 AI 응답 중에만 유효
- DataChannel 메시지는 JSON 문자열로 전송
- Server events는 비동기적으로 도착 (순서 보장 안 됨)

### iOS
- 마이크 권한은 런타임에 요청
- AVAudioSession 설정은 녹음 전에 완료
- Background mode에서 WebRTC 연결 유지 어려움 (MVP에서는 포그라운드만)
- Simulator에서는 마이크가 Mac의 마이크 사용

### Game Logic
- 타이머는 백그라운드에서 멈춤 (앱이 포그라운드로 돌아올 때 처리 필요)
- Pass는 새 단어로 이동하지만 점수는 오르지 않음
- 같은 단어가 한 라운드에서 반복되지 않도록 주의

---

## 🚀 다음 단계 (Post-MVP)

### Phase 5: 고급 기능
- [ ] 게임 히스토리 리뷰 페이지
  - 저장된 게임 세션 목록
  - 각 라운드의 transcript 보기
  - 통계 (정답률, 평균 점수 등)

- [ ] VAD 튜닝
  - `threshold`, `silence_duration_ms`, `prefix_padding_ms` 조정
  - 오탐/미탐 최소화

- [ ] Mode B AI 추측 타이밍 개선
  - Transcript 길이 기반
  - 침묵 감지 기반
  - 적응형 간격 (사용자 발화 패턴 학습)

- [ ] 난이도 시스템
  - 단어의 `difficulty` 필드 활용
  - Easy/Medium/Hard 모드

- [ ] 멀티플레이어 (원격)
  - 친구와 함께 플레이
  - 점수 경쟁

- [ ] 비디오 기능 (선택적)
  - 얼굴 표정 인식
  - 제스처 감지
  - Info.plist에 NSCameraUsageDescription 추가 필요

### Phase 6: 분석 및 최적화
- [ ] Analytics 연동
- [ ] A/B 테스트 (instructions 버전)
- [ ] 비용 모니터링 (OpenAI API)
- [ ] 서버 성능 최적화

---

## 📚 참고 자료

### OpenAI Realtime API
- [Realtime API Docs](https://platform.openai.com/docs/guides/realtime)
- [WebRTC Guide](https://platform.openai.com/docs/guides/realtime-webrtc)
- 로컬 문서: `/Docs/realtimeAPI_docs.txt`

### WebRTC
- [MDN WebRTC API](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API)
- [GoogleWebRTC iOS](https://github.com/webrtc-sdk/Specs)

### Swift/iOS
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [AVFoundation](https://developer.apple.com/av-foundation/)

---

## ✅ 완료 체크리스트

### Phase 0
- [ ] Cloud Run 서버 배포 완료
- [ ] iOS 프로젝트 초기 설정 완료
- [ ] words.json 로드 성공

### Phase 1
- [ ] WebRTC 연결 성공
- [ ] 양방향 음성 통신 확인
- [ ] DataChannel 이벤트 송수신 확인

### Phase 2
- [ ] 게임 타이머 동작
- [ ] 단어 관리 로직 완성
- [ ] 정답 판정 알고리즘 검증
- [ ] 점수 저장/로드 확인

### Phase 3A
- [ ] Mode A 게임 플레이 가능
- [ ] 끼어들기 동작
- [ ] 실시간 판정 동작

### Phase 3B
- [ ] Mode B 게임 플레이 가능
- [ ] AI 추측 타이밍 동작
- [ ] 버튼 판정 동작

### Phase 4
- [ ] 모든 화면 완성
- [ ] 피드백 효과 구현
- [ ] 에러 처리 완료
- [ ] 실제 기기 테스트 완료

---

## 💻 코드 예시

### Cloud Run 서버 (Node.js/Express)

```javascript
// server.js
import express from "express";

const app = express();
app.use(express.json());

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

// Instructions 템플릿
function generateInstructions(gameMode, currentWord, tabooWords) {
  if (gameMode === "modeA") {
    return `# Role
You are the host of a speed quiz game. Your job is to describe words so the user can guess them.

# Rules
- NEVER say the target word, its spelling, or direct synonyms
- Use indirect, natural descriptions like "You use this when..." or "You usually see this in..."
- Keep descriptions SHORT (1-2 sentences at a time)
- If the user says something close, provide additional hints
- If the user is correct, immediately stop and wait for the next word
- The taboo words for the current word are: ${tabooWords.join(", ")}

# Current Word
The word you need to describe is: ${currentWord}

# Language
- Speak only in English
- Use clear, natural pronunciation`;
  } else if (gameMode === "modeB") {
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
}

// POST /token - Ephemeral Token 발급
app.post("/token", async (req, res) => {
  try {
    const { deviceId, platform, appVersion, gameMode, currentWord, tabooWords } = req.body;

    // Rate limiting 체크 (IP + deviceId)
    // TODO: Implement rate limiting

    // Session config 생성
    const sessionConfig = {
      session: {
        type: "realtime",
        model: "gpt-realtime",
        instructions: generateInstructions(gameMode, currentWord, tabooWords || []),
        audio: {
          output: {
            voice: "marin",
          },
          input: {
            turn_detection: {
              type: "semantic_vad",
            },
          },
        },
      },
    };

    // OpenAI API 호출
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
      console.error("OpenAI API error:", response.status);
      return res.status(response.status).json({ error: "Failed to generate token" });
    }

    const data = await response.json();

    // 로깅
    console.log(`[${new Date().toISOString()}] Token issued - deviceId: ${deviceId}, mode: ${gameMode}`);

    // 응답 그대로 전달
    res.json(data);
  } catch (error) {
    console.error("Token generation error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// GET /health - Health check
app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

### iOS 클라이언트 (Swift)

```swift
// RealtimeClient.swift
import Foundation
import WebRTC

class RealtimeClient {
    private let serverURL = "https://your-cloud-run-url.run.app"
    private var peerConnection: RTCPeerConnection?
    private var ephemeralKey: String?

    // 1단계: 서버에서 토큰 발급
    func fetchEphemeralToken(
        gameMode: String,
        currentWord: String?,
        tabooWords: [String]?
    ) async throws -> String {
        let url = URL(string: "\(serverURL)/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "gameMode": gameMode,
            "currentWord": currentWord ?? "",
            "tabooWords": tabooWords ?? []
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "RealtimeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch token"])
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json["value"] as! String
    }

    // 2-4단계: WebRTC 연결
    func connect(
        gameMode: String,
        currentWord: String?,
        tabooWords: [String]?
    ) async throws {
        // 1단계: 토큰 발급
        ephemeralKey = try await fetchEphemeralToken(
            gameMode: gameMode,
            currentWord: currentWord,
            tabooWords: tabooWords
        )

        // 2단계: Offer 생성
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        peerConnection = createPeerConnection()

        let offer = try await peerConnection!.offer(for: constraints)
        try await peerConnection!.setLocalDescription(offer)

        // 3단계: OpenAI에 SDP 전송
        let url = URL(string: "https://api.openai.com/v1/realtime/calls")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(ephemeralKey!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = offer.sdp.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "RealtimeClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to OpenAI"])
        }

        // 4단계: Answer 수신 및 설정
        let answerSDP = String(data: data, encoding: .utf8)!
        let answer = RTCSessionDescription(type: .answer, sdp: answerSDP)
        try await peerConnection!.setRemoteDescription(answer)

        print("WebRTC connection established!")
    }

    private func createPeerConnection() -> RTCPeerConnection {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        let pc = RTCPeerConnectionFactory.sharedInstance().peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )

        // Audio track 추가
        let audioTrack = createAudioTrack()
        pc.add(audioTrack, streamIds: ["local-stream"])

        // DataChannel 생성
        let dataChannelConfig = RTCDataChannelConfiguration()
        let dataChannel = pc.dataChannel(forLabel: "oai-events", configuration: dataChannelConfig)
        dataChannel.delegate = self

        return pc
    }

    private func createAudioTrack() -> RTCAudioTrack {
        let audioSource = RTCPeerConnectionFactory.sharedInstance().audioSource(with: nil)
        return RTCPeerConnectionFactory.sharedInstance().audioTrack(with: audioSource, trackId: "audio0")
    }
}

// RTCPeerConnectionDelegate
extension RealtimeClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCPeerConnectionState) {
        print("Connection state: \(stateChanged)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("Remote stream added")
        if let audioTrack = stream.audioTracks.first {
            // Remote audio 재생
        }
    }

    // ... other delegate methods
}

// RTCDataChannelDelegate
extension RealtimeClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("DataChannel state: \(dataChannel.readyState)")
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let data = buffer.data
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            handleServerEvent(json)
        }
    }

    private func handleServerEvent(_ event: [String: Any]) {
        let type = event["type"] as? String
        print("Server event: \(type ?? "unknown")")

        // Handle different event types
        switch type {
        case "session.created":
            print("Session created!")
        case "input_audio_buffer.speech_started":
            print("User started speaking")
        case "conversation.item.input_audio_transcription.completed":
            let transcript = event["transcript"] as? String
            print("Transcript: \(transcript ?? "")")
        default:
            break
        }
    }
}
```

---

**마지막 업데이트**: 2025-12-19
**예상 개발 기간**: 13-18일 (약 3주)
