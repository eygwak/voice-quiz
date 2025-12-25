# Realtime_Archived - WebRTC/OpenAI Realtime API 모듈

## ⚠️ 비활성화 사유

**MVP 단계에서 비용 문제로 인해 제외됨**

- OpenAI Realtime API: $0.24/게임 (높은 비용)
- STT+TTS 대안: $0.096/게임 (60% 절감) 또는 온디바이스 무료

**현재 MVP 방향 (v0.4):**
- **STT**: Apple Speech Framework (온디바이스, 무료)
- **TTS**: AVSpeechSynthesizer (iOS 내장, 무료)
- **AI 호출**: REST API 기반 텍스트 LLM

## 📁 보관된 파일 목록

1. **RealtimeClient.swift** - Ephemeral Token 기반 WebRTC 연결 관리
   - 4-step connection flow
   - Token 발급 → Offer 생성 → SDP 전송 → Answer 수신
   - DataChannel/Audio Track 관리

2. **WebRTCManager.swift** - RTCPeerConnection 관리
   - PeerConnection 생성 및 설정
   - Audio track 추가 (마이크 입력)
   - Remote audio track 수신
   - Connection state 모니터링

3. **DataChannelManager.swift** - WebRTC DataChannel 관리
   - "oai-events" 채널 생성
   - JSON 메시지 송수신
   - Event parsing 및 delegate 전달
   - `session.update`, `response.cancel` 구현

4. **RealtimeEvents.swift** - Realtime API 이벤트 정의
   - Client Events: SessionUpdate, ResponseCreate, ResponseCancel
   - Server Events: SessionCreated, SpeechStarted, TranscriptionCompleted, etc.
   - Type-safe event models (Codable)

## 🔄 복귀 시점

**다음 조건 중 하나 이상 만족 시 재활성화 검토:**

1. **사용량 증가**: 월 1,000+ 게임 규모 도달
2. **Mode A UX 개선 필요**: 실시간 인터럽션이 핵심 가치로 입증됨
3. **Realtime API 가격 인하**: OpenAI 정책 변경
4. **하이브리드 전환**: Mode A는 Realtime, Mode B는 STT+TTS

**복귀 작업 체크리스트:**
- [ ] Xcode 타겟 멤버십 재활성화
- [ ] CocoaPods GoogleWebRTC SDK 재설치
- [ ] Backend `/token` 엔드포인트 재활성화
- [ ] RealtimeClient 통합 테스트
- [ ] 비용 모니터링 설정

## 📊 성능 비교 (참고)

### Realtime API (WebRTC)
✅ 실시간 인터럽션 (Mode A 핵심)
✅ 낮은 레이턴시 (300-500ms)
✅ Server VAD (정확한 발화 구간)
❌ 높은 비용 ($0.24/게임)

### STT + TTS (현재 MVP)
✅ 비용 효율 (온디바이스 무료)
✅ 유연한 음성 제어
❌ 높은 레이턴시 (1.5-3s)
❌ 인터럽션 구현 복잡

## 📚 관련 문서

- [cost-analysis-realtime-vs-stt-tts.md](../../Docs/cost-analysis-realtime-vs-stt-tts.md)
- [Docs/archive/](../../Docs/archive/) - WebRTC 기반 설계 문서들

---

**비활성화 날짜**: 2024-12-25
**Phase**: Phase 2-2 완료 후
**마지막 작동 커밋**: `a6567e8` (Phase 2-1)
