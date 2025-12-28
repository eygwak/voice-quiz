# 📱 음성 스피드 퀴즈 앱 – 기술 계획서 (v0.3 / SwiftUI + (제외됨:WebRTC) + Cloud Run)

## 확정된 결정사항

- **Realtime API((제외됨:WebRTC))는 MVP 테스트 단계에서 제외**
- 음성 입력(STT): **Apple Speech Framework (온디바이스, 무료)**
- 음성 출력(TTS): **AVSpeechSynthesizer (iOS 내장, 무료)**
- AI 호출: **텍스트 기반 LLM 호출만 사용**
- 서버: **Cloud Run (REST API)**


- 클라이언트: **iOS Native (SwiftUI, MVVM)**
- Realtime 연결: **(제외됨:WebRTC)**
- 입력 방식(메인 모드): **Always-on (Server VAD) 우선**, UX가 나쁘면 Push-to-talk로 전환 가능
- 자막/전사: **Realtime 전사만 사용**
- 서버: **Google Cloud Run** (ephemeral token 발급 + 최소 정책)
- 데이터 저장: 결과/최고기록/리뷰는 **로컬 저장**
- 카테고리: Food / Animals / Jobs / Objects / Minecraft
- 로컬 판정 임계치:
  - **Correct ≥ 0.90**
  - **Close 0.80 ~ 0.89**
  - 그 외 Incorrect

---

## 1. 시스템 아키텍처

```
[iOS App (SwiftUI)]
  ├─ (제외됨:WebRTC) PeerConnection (Audio Track + (제외됨:DataChannel))
  ├─ Game State Machine (Round/Score/Pass/Timer)
  ├─ Captions UI (Realtime transcription)
  └─ Local Storage (best score, history)

        │ (1) HTTPS: ephemeral token 요청
        ▼
[Cloud Run Backend]
  ├─ POST /realtime/token
  ├─ rate limit (IP + deviceId)
  └─ OpenAI API Key 보관

        │ (2) (제외됨:WebRTC) SDP 교환(클라→OpenAI)
        ▼
[OpenAI Realtime API]
```

### 서버 역할(필수 최소)
- ephemeral token 발급 (클라이언트에 API Key 금지)
- rate limiting
- 최소 로깅(성공/실패/지연/429). 전사 본문 저장은 기본 OFF

---

## 2. 클라이언트 설계 (SwiftUI + MVVM)

### 2.1 모듈 구조(권장)
- `UI/` (Views)
- `ViewModels/`
- `Game/` (rules, timer, scoring, state machine)
- `Realtime/` ((제외됨:WebRTC), (제외됨:DataChannel))
- `Audio/` (AVAudioSession)
- `Data/` (words.json, persistence)

### 2.2 핵심 View 구성(MVP)
- `HomeView`: 모드 선택(Mode A / Mode B), 카테고리 선택, Start
- `GameView_ModeA`: AI 설명 → 사용자 맞히기
- `GameView_ModeB`: 사용자 설명 → AI 맞히기
- `ResultView`: 점수/최고기록/다시하기

---

## 3. 음성 처리 (MVP: Local STT/TTS)

### 3.1 STT (Speech-to-Text)
- Apple Speech Framework 사용
- partial + final transcript 활용
- 네트워크 비용 없음

### 3.2 TTS (Text-to-Speech)
- AVSpeechSynthesizer 사용
- AI 설명/추측 시에만 재생

### 3.3 끼어들기 처리
- TTS 재생 중 사용자 발화 감지 시 즉시 stop()


- Google(제외됨:WebRTC) 사용
- Audio track + (제외됨:DataChannel) 모두 사용
- 오디오 세션(권장):
  - `.playAndRecord`
  - `mode: .voiceChat`
  - `options: [.defaultToSpeaker, .allowBluetooth]`

---

## 4. 게임 모드별 입력/흐름

## 4.1 Mode A (AI 설명 → 사용자 맞히기)

### 입력 전략
- Always-on + Server VAD (기본)
- 사용자 발화 시작 감지 시:
  - AI 출력(스피커) 즉시 stop
  - 진행 중 생성 cancel
- 발화 종료(서버 VAD) 후 전사 수신 → 로컬 판정

### 추측자 규칙(공통)
- 정답을 맞히는 사용자(추측자)는 **질문 금지**, 오직 정답 후보 발화만 허용

### 상태 머신(요약)
- `AI_SPEAKING` → `USER_INTERRUPT` → `JUDGING`
  - Correct → `NEXT_WORD` (즉시)
  - Close/Incorrect → `AI_SPEAKING` (설명 계속)

---

## 4.2 Mode B (사용자 설명 → AI 맞히기) — MVP 포함
### 추측자 규칙 (중요, 공통)

- **정답을 맞히는 역할은 질문을 할 수 없다.**
- 추측자는 항상 **정답 후보를 말하는 방식(guess)** 으로만 발화한다.
- **Close 판정이 발생해도 질문으로 좁히지 않으며, 다음 추측을 계속 수행**한다.


### 입력 전략
- 사용자: 연속 발화(Always-on)
- AI: “추측 발화”를 **간격 기반**으로 수행

### AI 추측 트리거(권장 기본값)
- **최소 간격 1.5초** (너무 자주 말하면 사용자 설명을 끊음)
- **최대 대기 3초** (너무 늦으면 답답함)
- 구현 방식:
  - (제외됨:DataChannel)로 들어오는 transcript delta를 관찰
  - “사용자 발화가 일정 길이/키워드 포함” 또는 “침묵 감지” 시 `response.create`로 추측 요청
  - 또는 간단하게: 2초 타이머 기반(초기 MVP) + 이후 개선

### 추측자 규칙(공통)
- 정답을 맞히는 AI(추측자)는 **질문 금지**, 오직 정답 후보 발화만 허용
- Close를 받아도 질문으로 좁히지 않고, 계속 추측만 수행

### UX/판정
- AI가 추측(음성) → 사용자가 버튼으로 Correct/Incorrect/Close
- Correct:
  - 점수 +1
  - 다음 단어로 즉시 전환
- Incorrect/Close:
  - 사용자는 계속 설명 가능(게임 흐름 유지)
- Pass:
  - 2회까지 가능(Mode A와 동일)

---

## 5. 전사/자막/정답 판정

### 5.1 전사(MVP: iOS 내장 STT)
- **Apple Speech Framework**로 전사
- 자막 UI는 **partial transcript(중간 결과)** 를 스트리밍 표시
- 정답 판정은 **final transcript(확정 결과)** 기준으로 로컬 판정
- TTS 재생 중에는 기본적으로 STT를 **일시 중지**(자기 음성 유입 방지)
"- (옵션) 이어폰/블루투스 사용 시에만 동시 STT/TTS 허용(실험)

### 5.2 로컬 판정 (Mode A 중심)
- normalize(소문자/구두점/공백)
- 완전일치 또는 synonyms 완전일치 → Correct
- similarity(Levenshtein 정규화)로:
  - ≥ 0.90 → Correct
  - 0.80~0.89 → Close
  - else → Incorrect

> Mode B는 “사용자가 버튼으로 판정”이므로 로컬 판정은 필수 아님(로그/통계용으로만 사용 가능)

---

## 6. 단어 데이터

- `assets/words.json` (번들)
- 구조: categories[] → words[]
- word 필드(권장):
  - `word`
  - `synonyms[]`
  - `difficulty` (테스트 단계 미사용)
  - `taboo[]`

---

## 7. 서버(Cloud Run) 최소 설계

### 7.1 Endpoint
- `POST /realtime/token`
  - req: `{ deviceId, platform, appVersion? }`
  - res: `{ token, expiresAt }`

### 7.2 운영 최소
- IP + deviceId rate limit
- Cloud Logging 기반 모니터링
- 리전: 한국 사용자 기준 가까운 리전 권장
- min instances:
  - 0(비용 최소) 또는 1(콜드스타트 감소)

---

## 8. 개발 로드맵(업데이트)

### Phase 1: 서버 + (제외됨:WebRTC) 연결
- token API
- (제외됨:WebRTC) 연결 성공(오디오 수신/송신)
- (제외됨:DataChannel) 이벤트 로그 확인

### Phase 2: Mode A 완성(게임 루프 + 끼어들기 + 로컬 판정)
- 60초/점수/Pass
- Correct/Close/Incorrect 피드백

### Phase 3: Mode B MVP 추가
- 단어 제시 UI
- 사용자 연속 설명
- AI 추측(간격 기반) + Correct/Incorrect/Close 버튼
- 다음 단어 전환/Pass 처리

### Phase 4: 튜닝
- VAD 오탐/지연 튜닝
- Mode B 추측 간격 최적화(사용자 이탈률 기준)

---

