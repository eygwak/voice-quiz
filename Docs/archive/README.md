# Archive - WebRTC/Realtime API 기반 문서

이 폴더는 MVP에서 제외된 WebRTC/OpenAI Realtime API 기반 설계 문서들을 보관합니다.

## 제외된 기능
- OpenAI Realtime API (WebRTC 기반)
- Ephemeral Token 방식 연결
- Server VAD
- Real-time bidirectional audio streaming

## 현재 MVP 방향 (v0.4)
- **STT**: Apple Speech Framework (온디바이스, 무료)
- **TTS**: AVSpeechSynthesizer (iOS 내장, 무료)
- **AI**: REST API 기반 텍스트 LLM 호출

## 보관된 문서 목록
- `PRD-v0_3_1.md` - Product Requirements (WebRTC 기반)
- `voice-speed-quiz-tech-plan-v0_3_2-cloudrun.md` - Technical Plan (WebRTC)
- `dev-plan.md` - Development Roadmap (4 Phases, WebRTC)
- `realtimeAPI_docs.txt` - OpenAI Realtime API documentation
- `audio-format-note.md` - WebRTC audio format notes
- `connection-flow.md` - WebRTC connection flow
- `implementation-notes.md` - WebRTC implementation details
- `ios-setup.md` - iOS WebRTC setup guide
- `transcription-verification.md` - Realtime transcription verification

## 향후 참고 용도
- Post-MVP에서 Realtime API 재도입 검토 시 참고
- 비용 효율성 분석 후 하이브리드 전환 시 참고
