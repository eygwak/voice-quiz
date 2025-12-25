# VoiceQuiz 개발 진행 현황 요약

**최종 업데이트**: 2025-12-25
**현재 단계**: Phase 2-2 (Persistence Layer) 완료, 빌드 테스트 대기 중

---

## 📊 전체 진행률

| Phase | 상태 | 완료일 | 비고 |
|-------|------|--------|------|
| Phase 0 | ✅ 완료 | 2024-12-23 | Backend + iOS 초기 설정 |
| Phase 1 | ✅ 완료 | 2024-12-24 | WebRTC 연결 및 기본 통신 |
| Phase 2-1 | ✅ 완료 | 2024-12-24 | Game Core Logic |
| Phase 2-2 | ✅ 완료 | 2024-12-25 | Persistence Layer (빌드 대기) |
| Phase 2-3 | ⏳ 대기 | - | Common UI Components |
| Phase 2-4 | ⏳ 대기 | - | Integration Testing |
| Phase 3A | ⏳ 대기 | - | Mode A 구현 |
| Phase 3B | ⏳ 대기 | - | Mode B 구현 |
| Phase 4 | ⏳ 대기 | - | UI/UX 완성 및 튜닝 |

---

## 🎯 Phase 0: 준비 및 기반 구축 (완료)

### Backend (Google Cloud Run)
✅ **구현 완료**
- Node.js/Express 서버 구축
- `POST /token` 엔드포인트 (Ephemeral Token 발급)
- Dynamic instructions 생성 (Mode A/B 분기)
- Rate limiting (express-rate-limit, deviceId 기반)
- Secret Manager 통합 (OPENAI_API_KEY)
- Cloud Run 배포 (`--max-instances=1`)
- Health check 엔드포인트 (`GET /health`)
- Logging (token 발급 성공/실패)

**배포 URL**: `https://voicequiz-server-985594867462.asia-northeast3.run.app`

### iOS Project Setup
✅ **구현 완료**
- GoogleWebRTC SDK 설치 (CocoaPods)
- 디렉토리 구조 생성
  - `UI/`, `ViewModels/`, `Game/`, `Realtime/`, `Audio/`, `Data/`
- Info.plist 권한 설정
  - `NSMicrophoneUsageDescription`
- .gitignore 설정 (Pods/, .env, DerivedData/)

### Data Models
✅ **구현 완료**
- [Word.swift](../VoiceQuiz/Data/Models/Word.swift) - 단어 모델 (Codable)
- [Category.swift](../VoiceQuiz/Data/Models/Category.swift) - 카테고리 모델
- [WordsLoader.swift](../VoiceQuiz/Data/WordsLoader.swift) - JSON 파싱
- [words.json](../VoiceQuiz/Data/words.json) - 5개 카테고리, 30개 단어

**검증 완료**:
- ✅ Backend `/token` 엔드포인트 정상 작동
- ✅ Ephemeral token 발급 성공
- ✅ Mode A/B instructions 동적 생성
- ✅ iOS 빌드 성공
- ✅ CocoaPods 통합 (GoogleWebRTC)
- ✅ words.json 로드 성공

**관련 이슈**: #1, #2, #3 (모두 closed)
**커밋**: `dc7b955`, `6a9e67d`, `28e5dd5`

---

## 🎯 Phase 1: WebRTC 연결 및 기본 통신 (완료)

### WebRTC Core
✅ **구현 완료**
- [WebRTCManager.swift](../VoiceQuiz/Realtime/WebRTCManager.swift)
  - RTCPeerConnection 생성 및 설정
  - Audio track 추가 (마이크 입력)
  - Remote audio track 수신 및 재생
  - Connection state 모니터링
  - Delegate 패턴으로 상태 전달

- [DataChannelManager.swift](../VoiceQuiz/Realtime/DataChannelManager.swift)
  - DataChannel 생성 ("oai-events")
  - JSON 메시지 송수신
  - Event parsing 및 delegate 전달
  - `session.update`, `response.cancel` 구현

- [RealtimeClient.swift](../VoiceQuiz/Realtime/RealtimeClient.swift) - Ephemeral Token 방식
  - **4-Step Connection Flow**:
    1. 서버에서 토큰 발급 (`POST /token`)
    2. WebRTC Offer 생성 및 setLocalDescription
    3. OpenAI에 SDP 전송 (`POST /v1/realtime/calls`)
    4. Answer SDP 수신 및 setRemoteDescription
  - Connection lifecycle 관리
  - Error handling
  - **Bug Fix**: DataChannel 초기화 후 100ms delay 추가 (첫 연결 실패 해결)

- [RealtimeEvents.swift](../VoiceQuiz/Realtime/RealtimeEvents.swift)
  - Type-safe event definitions
  - Client Events: `SessionUpdate`, `ResponseCreate`, `ResponseCancel`
  - Server Events: `SessionCreated`, `InputAudioBufferSpeechStarted`, `ConversationItemInputAudioTranscriptionCompleted`, `ResponseAudioTranscriptDelta`, `ResponseAudioTranscriptDone`

### Audio Session
✅ **구현 완료**
- [AudioSessionManager.swift](../VoiceQuiz/Audio/AudioSessionManager.swift)
  - AVAudioSession 설정
    - Category: `.playAndRecord`
    - Mode: `.voiceChat`
    - Options: `[.defaultToSpeaker, .allowBluetooth]`
  - 권한 요청
  - Interruption 처리

### Test UI
✅ **구현 완료**
- [TestConnectionView.swift](../VoiceQuiz/UI/TestConnectionView.swift)
  - Connect/Disconnect 버튼
  - Connection state 표시
  - User/AI transcript 실시간 표시
  - Event log 표시
  - Enable Transcription 버튼
  - Cancel AI Response 버튼

**실제 기기 테스트 결과**:
- ✅ WebRTC 연결 성공 (`connected` state)
- ✅ 마이크 입력 → OpenAI 전송 확인
- ✅ AI 음성 응답 → 스피커 출력 확인
- ✅ DataChannel 이벤트 송수신 확인
- ✅ Transcription 실시간 수신 (delta)
- ✅ 첫 연결 시도 성공 (100ms delay 적용 후)

**관련 이슈**: #4 (closed)
**커밋**: `28e7877`

---

## 🎯 Phase 2-1: Game Core Logic (완료)

### Game Logic Components
✅ **구현 완료**
- [GameState.swift](../VoiceQuiz/Game/GameState.swift)
  - `GamePhase`: ready/playing/paused/finished
  - `GameMode`: modeA/modeB with displayName
  - `GameSessionState`: phase, currentWordIndex, passCount 관리
  - Max pass count: 2

- [GameTimer.swift](../VoiceQuiz/Game/GameTimer.swift)
  - 60초 countdown timer
  - Combine framework 사용 (`@Published`)
  - `remainingTime`, `isRunning`, `isWarning` 상태
  - Warning threshold: 10초
  - Pause/Resume 지원
  - Progress 계산 (0.0 ~ 1.0)
  - Formatted time (MM:SS)

- [WordManager.swift](../VoiceQuiz/Game/WordManager.swift)
  - words.json 로드 (WordsLoader 사용)
  - 카테고리 선택 (ID 또는 랜덤)
  - 중복 방지 랜덤 단어 선택 (usedWordIndices)
  - Pass 관리 (max 2회)
  - Progress tracking (wordsCompleted/totalWords)

- [AnswerJudge.swift](../VoiceQuiz/Game/AnswerJudge.swift)
  - **Judgment Logic** (Mode A용):
    - Correct: Similarity ≥ 0.90 or exact match or synonym match
    - Close: Similarity 0.80-0.89
    - Incorrect: Similarity < 0.80
  - **String Normalization**:
    - Lowercase
    - Remove punctuation
    - Trim whitespace
  - **Levenshtein Distance** 구현 (Dynamic Programming)
  - Similarity 계산 (normalized 0.0 ~ 1.0)

- [ScoreManager.swift](../VoiceQuiz/Game/ScoreManager.swift) - **리팩토링 완료**
  - 점수 계산 로직만 담당 (단일 책임 원칙)
  - 저장은 UserDefaultsManager에 위임
  - `currentScore` 추적
  - `incrementScore()`, `resetCurrentScore()`
  - `isNewRecord()` 체크

**검증 완료**:
- ✅ 빌드 성공
- ✅ 첫 연결 버그 수정 확인 (100ms delay)

**관련 이슈**: #5 (closed)
**커밋**: `a6567e8`

---

## 🎯 Phase 2-2: Persistence Layer (완료, 빌드 대기)

### Persistence Components
✅ **구현 완료**

- [UserDefaultsManager.swift](../VoiceQuiz/Data/Persistence/UserDefaultsManager.swift) - **UserDefaults의 단일 진입점**
  - **Best Scores**:
    - `getBestScore(for:)` / `saveBestScore(_:for:)`
    - Mode A/B 분리 저장
    - `resetBestScores()`
  - **Settings**:
    - `soundEnabled: Bool` (default: true)
    - `selectedCategories: [String]`
  - **Game History Metadata**:
    - 최근 100개 게임 메타데이터 관리
    - `getHistoryMetadata()` / `saveHistoryMetadata(_:)`
    - `addHistoryMetadata(_:)` - 최근 항목 앞에 삽입
    - 100개 초과 시 자동 trim
  - **Type-safe Keys** (enum)
  - **Reset All** 기능

- [GameSession.swift](../VoiceQuiz/Data/Models/GameSession.swift) - **게임 세션 데이터 모델**
  - **GameSession** (Codable, Identifiable):
    - id, mode, categoryId, categoryName
    - score, maxScore, passCount
    - startTime, endTime
    - words: [WordResult]
    - Computed: duration, successRate
    - `toMetadata()` helper
  - **WordResult** (Codable, Identifiable):
    - id, word, attempts
    - passed, isCorrect
    - userTranscript, aiTranscript, judgment
    - timestamp

- [HistoryManager.swift](../VoiceQuiz/Data/Persistence/HistoryManager.swift) - **JSON 파일 기반 히스토리 관리**
  - **File Management**:
    - History directory 생성 (Documents/GameHistory/)
    - File naming: `game_session_{id}.json`
  - **Save Session**:
    - JSON encoding (ISO8601 dates, pretty printed)
    - Metadata 업데이트 (UserDefaultsManager)
  - **Load Session**:
    - By ID
    - Recent N sessions (metadata 기반)
  - **Delete Session**:
    - 단일 세션 삭제
    - 모든 세션 삭제
    - Metadata 동기화
  - **Storage Management**:
    - `cleanupOldSessions(keepCount:)` - 100개 초과 시 자동 삭제
    - `getStorageSize()` - 사용 공간 계산
  - **Debug Tools**:
    - `listAllSessions()` - 세션 목록 출력

### Refactoring
✅ **ScoreManager 리팩토링**
- 저장 로직 제거 → UserDefaultsManager에 위임
- 점수 계산 로직만 담당 (단일 책임 원칙)
- 기존 API 유지 (호환성)

**구조 개선**:
```
Before:
ScoreManager → UserDefaults (직접 접근)

After:
ScoreManager → UserDefaultsManager → UserDefaults
              ↑
HistoryManager → UserDefaultsManager → UserDefaults
```

**아직 UI 없음**: Phase 2-2는 백엔드 로직만 구현, UI는 Phase 2-3에서 구현 예정

**검증 대기 중**:
- [ ] 빌드 테스트 (사용자 확인 필요)

**관련 이슈**: #6 (closed)
**다음 커밋 예정**: Phase 2-2 완료 후

---

## 📋 구현 완료된 파일 목록

### Backend
- ✅ `Backend/index.js` - Token server with rate limiting
- ✅ `Backend/Dockerfile` - Cloud Run deployment
- ✅ `Backend/package.json` - Dependencies (express, dotenv)
- ✅ `Backend/.env.example` - Environment variables template

### iOS - Realtime
- ✅ `VoiceQuiz/Realtime/RealtimeClient.swift` - Ephemeral Token connection flow
- ✅ `VoiceQuiz/Realtime/WebRTCManager.swift` - RTCPeerConnection management
- ✅ `VoiceQuiz/Realtime/DataChannelManager.swift` - DataChannel events
- ✅ `VoiceQuiz/Realtime/RealtimeEvents.swift` - Event definitions

### iOS - Audio
- ✅ `VoiceQuiz/Audio/AudioSessionManager.swift` - AVAudioSession configuration

### iOS - Game
- ✅ `VoiceQuiz/Game/GameState.swift` - Game phase/mode/session state
- ✅ `VoiceQuiz/Game/GameTimer.swift` - 60-second timer
- ✅ `VoiceQuiz/Game/WordManager.swift` - Word selection logic
- ✅ `VoiceQuiz/Game/AnswerJudge.swift` - Levenshtein-based judgment
- ✅ `VoiceQuiz/Game/ScoreManager.swift` - Score calculation (refactored)

### iOS - Data
- ✅ `VoiceQuiz/Data/Models/Word.swift` - Word model
- ✅ `VoiceQuiz/Data/Models/Category.swift` - Category model
- ✅ `VoiceQuiz/Data/Models/GameSession.swift` - Game session model
- ✅ `VoiceQuiz/Data/WordsLoader.swift` - JSON loader
- ✅ `VoiceQuiz/Data/words.json` - 5 categories, 30 words
- ✅ `VoiceQuiz/Data/Persistence/UserDefaultsManager.swift` - UserDefaults singleton
- ✅ `VoiceQuiz/Data/Persistence/HistoryManager.swift` - JSON file manager

### iOS - UI
- ✅ `VoiceQuiz/UI/TestConnectionView.swift` - WebRTC test UI

### Documentation
- ✅ `CLAUDE.md` - Project overview and architecture
- ✅ `Docs/dev-plan.md` - Development roadmap
- ✅ `Docs/PRD-v0_3_1.md` - Product requirements
- ✅ `Docs/voice-speed-quiz-tech-plan-v0_3_2-cloudrun.md` - Technical plan
- ✅ `Docs/cost-analysis-realtime-vs-stt-tts.md` - Cost analysis (NEW)

---

## 🚧 다음 단계: Phase 2-3 (Common UI Components)

### 구현 예정
- [ ] `TranscriptView.swift` - 실시간 자막 표시 (User/AI 구분)
- [ ] `TimerView.swift` - 원형 progress bar with countdown
- [ ] `ScoreView.swift` - 현재 점수 + 최고 점수 표시
- [ ] `JudgmentFeedbackView.swift` - Correct/Close/Incorrect 피드백 애니메이션

### 예상 소요 시간
- 1일

---

## 📊 기술적 의사결정 히스토리

### 1. 연결 방식: Ephemeral Token
**결정**: Ephemeral Token 방식 사용
**이유**:
- Instructions를 서버에서 동적 생성 가능
- API Key 클라이언트 노출 방지
- Rate limiting 구현 가능

**구현**:
- Backend: `POST /token` 엔드포인트
- iOS: 4-step connection flow

### 2. Rate Limiting 방식
**결정**: `max-instances=1` + express-rate-limit
**이유**:
- MVP 단계에서 간단한 구현
- DeviceId 기반 제어 가능
- Redis/Firestore 불필요 (확장성 낮지만 초기엔 충분)

**제약**:
- Multi-instance scaling 불가
- 향후 Redis/Firestore로 전환 필요

### 3. Audio Format: WebRTC SDP Auto-negotiation
**결정**: Session config에서 audio format 필드 생략
**이유**:
- WebRTC가 SDP 협상 중 자동으로 최적 codec 선택
- 명시적 설정 불필요 (pcm16, g711_ulaw, g711_alaw 중 자동 선택)

### 4. Transcription 활성화
**결정**: `session.created` 이벤트에서 확인 후 필요시 `session.update`
**이유**:
- 서버에서 instructions에 transcription 설정 가능하지만
- iOS에서 명시적으로 활성화 보장

**구현**:
- `RealtimeClient.swift:227-236` - transcription check 로직

### 5. 점수 저장 아키텍처: UserDefaultsManager 중앙화
**결정**: UserDefaultsManager를 UserDefaults의 유일한 창구로 설정
**이유**:
- 단일 책임 원칙 (SRP) 준수
- ScoreManager는 점수 계산만, 저장은 위임
- Type-safe keys 관리
- 테스트 용이성 향상

**Before**:
```swift
ScoreManager → UserDefaults (직접 접근)
```

**After**:
```swift
ScoreManager → UserDefaultsManager → UserDefaults
HistoryManager → UserDefaultsManager (metadata)
```

### 6. 비용 최적화: Realtime API vs STT+TTS
**분석 완료**: [cost-analysis-realtime-vs-stt-tts.md](cost-analysis-realtime-vs-stt-tts.md)

**결정**: MVP 단계에서 Realtime API 유지
**이유**:
- Mode A의 핵심 UX: 실시간 인터럽션 필요
- 초기 사용량 낮음 (100-500 게임/월 → $24-120/월)
- 이미 구현 완료, 빠른 검증 필요
- STT+TTS는 구현 복잡도 4배 (⭐⭐⭐⭐)

**향후 계획**:
- 월 1,000+ 게임 시 하이브리드 전환 고려
- Mode B는 STT+TTS로 전환 가능 (턴 기반)
- Mode A는 Realtime API 유지

---

## 🐛 해결된 버그

### Bug #1: 첫 연결 시도 실패
**증상**: Connect 버튼 첫 클릭 시 실패, 두 번째 클릭 시 성공
**원인**: DataChannel 생성 직후 offer 생성 시 초기화 미완료
**해결**: DataChannel 생성 후 100ms delay 추가
**파일**: `RealtimeClient.swift:78`
**커밋**: `a6567e8`

### Bug #2: RTCPeerConnection Optional Type Mismatch
**증상**: `peerConnectionFactory.peerConnection()` guard let 컴파일 에러
**원인**: 메서드가 non-optional 반환
**해결**: guard 문 제거, 직접 할당
**파일**: `WebRTCManager.swift:61`
**커밋**: `28e7877`

### Bug #3: Missing Combine Import
**증상**: TestConnectionView에서 ObservableObject/Published 사용 불가
**원인**: `import Combine` 누락
**해결**: import 추가
**파일**: `TestConnectionView.swift:10`
**커밋**: `28e7877`

---

## 📈 테스트 결과

### Phase 1 실제 기기 테스트 (완료)
**테스트 환경**: iPhone (실제 기기)
**테스트 날짜**: 2024-12-24
**결과**: ✅ 모든 테스트 통과

1. ✅ **WebRTC 연결**: Connected 상태 진입
2. ✅ **마이크 입력**: User 음성 → OpenAI 전송 확인
3. ✅ **AI 응답**: OpenAI 음성 → 스피커 출력 확인
4. ✅ **DataChannel**: Event 송수신 정상
5. ✅ **Transcription**: Real-time delta 수신

**사용자 피드백**: "테스트 성공"

---

## 🔄 Git 커밋 히스토리

```
a6567e8 [Phase 2-1] Implement game core logic (2024-12-24)
  - GameState, GameTimer, WordManager, AnswerJudge, ScoreManager
  - Bug fix: 첫 연결 실패 해결 (100ms delay)

28e7877 [Phase 1] Implement WebRTC connection and basic communication (2024-12-24)
  - RealtimeClient, WebRTCManager, DataChannelManager
  - RealtimeEvents, AudioSessionManager
  - TestConnectionView
  - 실제 기기 테스트 성공

28e5dd5 [Phase 0] Complete all optional tasks and iOS setup (2024-12-23)
  - Secret Manager integration
  - Rate limiting implementation
  - iOS microphone permission
  - Data models (Word, Category, WordsLoader)

2af1d5f Fix iOS build configuration for real device deployment (2024-12-23)

6a9e67d [Phase 0] Complete initial project setup (2024-12-23)
  - Backend server implementation
  - CocoaPods integration
  - words.json validation

dc7b955 Add comprehensive development documentation and backend implementation (2024-12-23)

b30c001 Initial Commit (2024-12-23)
```

---

## 📌 현재 상태 요약

### ✅ 완료
- Backend 서버 (Cloud Run 배포)
- WebRTC 연결 및 실시간 음성 통신
- Game Core Logic (타이머, 점수, 단어, 판정)
- Persistence Layer (UserDefaults + JSON 파일)
- 비용 분석 완료

### 🚧 진행 중
- Phase 2-2 빌드 테스트 대기

### ⏳ 다음 단계
- Phase 2-3: Common UI Components
  - TranscriptView, TimerView, ScoreView, JudgmentFeedbackView
- Phase 2-4: Integration Testing
- Phase 3A: Mode A 구현
- Phase 3B: Mode B 구현
- Phase 4: UI/UX 완성 및 튜닝

### 🎯 현재 우선순위
1. **Phase 2-2 빌드 테스트** (사용자 확인 필요)
2. Phase 2-3 Common UI Components 구현
3. Mode A 구현 (Phase 3A)

---

## 📚 문서 자료

### 기술 문서
- [CLAUDE.md](../CLAUDE.md) - 프로젝트 개요 및 아키텍처
- [dev-plan.md](dev-plan.md) - 개발 로드맵 (4 Phases)
- [cost-analysis-realtime-vs-stt-tts.md](cost-analysis-realtime-vs-stt-tts.md) - 비용 분석

### 기획 문서
- [PRD-v0_3_1.md](PRD-v0_3_1.md) - 제품 요구사항 (Korean)
- [voice-speed-quiz-tech-plan-v0_3_2-cloudrun.md](voice-speed-quiz-tech-plan-v0_3_2-cloudrun.md) - 기술 계획 (Korean)

---

**예상 남은 개발 기간**: 7-10일 (Phase 2-3 ~ Phase 4)
**예상 MVP 완성**: 2025-01-03 전후
