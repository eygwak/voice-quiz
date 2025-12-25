# Cost Analysis: Realtime API vs STT + TTS

## 1. 가격 비교 (2025년 기준)

### OpenAI Realtime API
- **Audio Input**: $0.06/분 ($32/1M tokens, cached: $0.40/1M)
- **Audio Output**: $0.24/분 ($64/1M tokens)
- **Text Input**: $5/1M tokens
- **Text Output**: $20/1M tokens

**60초 게임 라운드당 비용:**
- User 음성 입력 (60초): $0.06
- AI 음성 출력 (평균 40초): $0.24 × (40/60) = $0.16
- Text tokens (instructions + transcription): ~$0.02
- **라운드당 총 비용: ~$0.24**

### STT + TTS 조합

**Option 1: Whisper + TTS Standard**
- **STT (Whisper)**: $0.006/분
- **TTS (Standard)**: $15/1M characters = ~$0.0015/초 (150 chars/sec 기준)
- **LLM (GPT-4o mini)**: $0.15/1M input + $0.60/1M output

**60초 게임 라운드당 비용:**
- User 음성 입력 STT (60초): $0.006 × 1 = $0.006
- LLM processing (Mode A 시나리오):
  - Instructions + context: ~500 tokens input × $0.15/1M = $0.000075
  - Description output: ~200 tokens × $0.60/1M = $0.00012
- AI 음성 출력 TTS (40초, ~6,000 chars): 6,000 × $15/1M = $0.09
- **라운드당 총 비용: ~$0.096**

**Option 2: Whisper + TTS HD**
- TTS HD: $30/1M characters
- **라운드당 총 비용: ~$0.186**

## 2. 비용 시뮬레이션

### 사용량 시나리오

| 사용량 | Realtime API | STT + TTS (Standard) | STT + TTS (HD) |
|--------|--------------|---------------------|----------------|
| 100 게임/월 | $24 | $9.6 | $18.6 |
| 500 게임/월 | $120 | $48 | $93 |
| 1,000 게임/월 | $240 | $96 | $186 |
| 10,000 게임/월 | $2,400 | $960 | $1,860 |

**비용 절감률:**
- STT + TTS Standard: **60% 절감**
- STT + TTS HD: **22.5% 절감**

## 3. 기술적 트레이드오프

### Realtime API 장점
✅ **실시간 인터럽션**: 사용자가 AI 발화 중 즉시 끼어들기 가능 (Mode A 핵심 기능)
✅ **낮은 레이턴시**: End-to-end 300-500ms
✅ **Server VAD**: 서버 측 음성 활동 감지로 정확한 발화 구간 탐지
✅ **단순한 아키텍처**: WebRTC 단일 연결로 양방향 처리
✅ **스트리밍 응답**: Delta 단위로 실시간 텍스트/오디오 스트리밍

### Realtime API 단점
❌ **높은 비용**: STT+TTS 대비 2.5배
❌ **Audio token 과금**: 침묵 구간도 과금
❌ **제한적 커스터마이징**: Voice, 속도, 억양 제어 제한적

### STT + TTS 장점
✅ **비용 효율**: 60% 절감 (Standard TTS 기준)
✅ **유연한 음성 제어**: TTS HD, 다양한 voice 옵션 (alloy, echo, fable, nova, shimmer, onyx)
✅ **개별 최적화 가능**: STT, LLM, TTS 각각 최적화 가능
✅ **세밀한 과금 제어**: 실제 사용한 시간/문자만 과금
✅ **캐싱 활용**: LLM instructions 캐싱으로 추가 비용 절감

### STT + TTS 단점
❌ **높은 레이턴시**: 총 1.5-3초 (STT 500ms + LLM 500ms + TTS 500-1500ms)
❌ **인터럽션 구현 복잡**: 클라이언트 VAD + 수동 스트림 중단 필요
❌ **복잡한 아키텍처**: 3개 API 조율, 에러 처리 복잡
❌ **턴 기반 대화**: 실시간 끼어들기 어려움

## 4. VoiceQuiz 게임 모드별 적합성 분석

### Mode A (AI 설명 → User 추측)
**핵심 요구사항:**
- AI가 연속 설명 중 사용자가 **즉시 끼어들어 답변** 가능
- 사용자 발화 시 AI 출력 **즉시 중단**
- 낮은 레이턴시 (실시간 퀴즈 경험)

**결론:**
- **Realtime API 강력 추천**: 인터럽션이 핵심 UX
- STT+TTS로 구현 시 클라이언트 VAD + 수동 스트림 관리 필요 → 복잡도 급증

### Mode B (User 설명 → AI 추측)
**핵심 요구사항:**
- 사용자가 **연속 설명** (긴 발화)
- AI가 1.5-3초 간격으로 추측 시도
- 실시간 끼어들기 불필요

**결론:**
- **STT + TTS 적합**: 턴 기반 대화 구조
- 비용 절감 효과 높음 (60%)
- 레이턴시 허용 가능 (AI 응답 대기 시간 자연스러움)

## 5. 추천 아키텍처

### 전략 1: 하이브리드 (모드별 분리)
- **Mode A**: Realtime API (인터럽션 필수)
- **Mode B**: STT + TTS (비용 최적화)

**장점:**
- 각 모드의 특성에 맞는 최적 기술 선택
- Mode B의 높은 사용 빈도로 전체 비용 절감 효과

**단점:**
- 두 가지 아키텍처 유지보수
- 복잡도 증가

### 전략 2: Full Realtime API (현재)
- 모든 모드에서 Realtime API 사용

**장점:**
- 단일 아키텍처, 낮은 복잡도
- 일관된 사용자 경험
- 빠른 개발 속도

**단점:**
- 높은 비용
- 초기 MVP에서는 과도한 투자

### 전략 3: Full STT + TTS
- 모든 모드에서 STT + TTS 사용

**장점:**
- 최대 비용 절감 (60%)
- 유연한 커스터마이징

**단점:**
- Mode A 인터럽션 UX 저하
- 복잡한 구현 (클라이언트 VAD, 스트림 관리)
- 높은 레이턴시

## 6. 최종 추천

### MVP 단계 (현재)
**전략 2 (Full Realtime API) 유지 추천**

**이유:**
1. **빠른 검증**: 기술 복잡도 최소화로 게임 로직 검증에 집중
2. **UX 최우선**: Mode A의 인터럽션 경험이 게임의 핵심 차별점
3. **초기 사용량 낮음**: MVP 단계 100-500 게임/월 → $24-120/월 허용 가능
4. **이미 구현 완료**: Phase 1 완료 상태, 전환 비용 고려

### 성장 단계 (사용량 증가 시)
**전략 1 (하이브리드) 전환 고려**

**전환 기준:**
- 월 사용량 > 1,000 게임 ($240/월 초과 시)
- 사용자 피드백: Mode B에서 레이턴시 허용 확인 후

**구현 계획:**
1. Mode B부터 STT+TTS 전환 (상대적으로 간단)
2. 비용 절감 효과 측정
3. Mode A는 Realtime API 유지

### 장기 최적화
**커스텀 인프라 검토**
- Self-hosted Whisper + Custom TTS
- WebRTC + Custom VAD
- 월 10,000+ 게임 규모에서 검토

## 7. 구현 복잡도 비교

### Realtime API (현재)
```
Client (iOS)
  └─ WebRTC Connection
       ├─ Audio Track (bidirectional)
       └─ Data Channel (events)

Backend
  └─ Token Server (ephemeral token)
```
**구현 복잡도: ⭐⭐ (낮음)**

### STT + TTS
```
Client (iOS)
  ├─ AVAudioRecorder (record user speech)
  ├─ VAD (detect speech start/stop)
  ├─ Whisper API (STT)
  ├─ GPT-4o Mini API (LLM)
  ├─ TTS API (audio generation)
  └─ AVAudioPlayer (play AI response)

Backend
  ├─ Token/Auth management
  ├─ STT request handling
  ├─ LLM orchestration
  ├─ TTS streaming
  └─ State management (turn-based)
```
**구현 복잡도: ⭐⭐⭐⭐ (높음)**

## 8. 액션 아이템

### Immediate (MVP)
- [x] Realtime API 유지
- [ ] 비용 모니터링 설정 (Cloud Run logs)
- [ ] 사용량 대시보드 구현 (게임 횟수 추적)

### Short-term (사용량 증가 시)
- [ ] Mode B STT+TTS 전환 POC
- [ ] 비용/레이턴시 A/B 테스트
- [ ] 사용자 피드백 수집

### Long-term (Scale)
- [ ] 하이브리드 아키텍처 전환
- [ ] 커스텀 인프라 검토 (Self-hosted)
- [ ] Edge Computing 활용 검토

---

## References

- [OpenAI Pricing](https://openai.com/api/pricing/)
- [OpenAI Realtime API Pricing 2025](https://skywork.ai/blog/agent/openai-realtime-api-pricing-2025-cost-calculator/)
- [Whisper API Pricing](https://brasstranscripts.com/blog/openai-whisper-api-pricing-2025-self-hosted-vs-managed)
- [OpenAI API Pricing Guide](https://platform.openai.com/docs/pricing)
