# Audio Format 설정 관련 중요 노트

## ⚠️ WebRTC 환경에서 format 필드 생략 권장

### 문제점

OpenAI Realtime API 문서에서는 `audio.input.format`과 `audio.output.format` 필드를 명시하도록 안내하지만, **WebRTC 환경**에서는 이 필드들을 **생략하는 것이 권장**됩니다.

### 이유

1. **SDP 협상의 자동 처리**
   - WebRTC는 SDP (Session Description Protocol) 협상 과정에서 코덱과 샘플링 레이트를 자동으로 결정합니다
   - 일반적으로 Opus 코덱이 선택됩니다 (고품질 음성 코덱)

2. **충돌 가능성**
   - Session config에서 `format: { type: "audio/pcm", rate: 24000 }`을 명시하면
   - SDP 협상 결과와 다를 경우 연결 실패 또는 오디오 문제가 발생할 수 있습니다

3. **환경별 차이**
   - iOS 시뮬레이터와 실제 기기에서 다른 코덱을 지원할 수 있습니다
   - 네트워크 환경에 따라 최적의 코덱이 달라질 수 있습니다

### 올바른 Session Config (WebRTC용)

```javascript
const sessionConfig = {
  session: {
    type: "realtime",
    model: "gpt-realtime",
    instructions: "...",
    audio: {
      input: {
        // ✅ format 필드 생략
        turn_detection: {
          type: "semantic_vad",
        },
        transcription: {
          model: "whisper-1",
        },
      },
      output: {
        // ✅ format 필드 생략
        voice: "marin",
      },
    },
  },
};
```

### WebSocket 환경에서는?

**WebSocket 연결**을 사용하는 경우에는 `format` 필드를 **명시**해야 합니다.

```javascript
// WebSocket용 session config
const sessionConfig = {
  session: {
    type: "realtime",
    model: "gpt-realtime",
    instructions: "...",
    audio: {
      input: {
        format: {
          type: "audio/pcm",  // ✅ WebSocket에서는 명시 필요
          rate: 24000,
        },
        turn_detection: {
          type: "semantic_vad",
        },
      },
      output: {
        format: {
          type: "audio/pcm",  // ✅ WebSocket에서는 명시 필요
          rate: 24000,
        },
        voice: "marin",
      },
    },
  },
};
```

### VoiceQuiz 프로젝트에서는?

- ✅ **WebRTC 사용** → `format` 필드 **생략**
- ✅ SDP 협상에서 자동으로 최적의 코덱 선택
- ✅ iOS 시뮬레이터와 실제 기기 모두 호환

## 참고 자료

- [OpenAI Realtime API - WebRTC Guide](https://platform.openai.com/docs/guides/realtime-webrtc)
- [WebRTC SDP 협상 과정](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Connectivity)
- 제공하신 실제 구현 코드 기반

## 추가 확인 사항

만약 오디오 품질 문제가 발생한다면:

1. **SDP 내용 확인**
   ```swift
   print("Local SDP:", pc.localDescription?.sdp)
   print("Remote SDP:", pc.remoteDescription?.sdp)
   ```

2. **코덱 확인**
   - SDP에서 `m=audio` 라인과 `a=rtpmap` 확인
   - Opus 코덱이 사용되는지 확인

3. **필요시 format 추가**
   - 특정 코덱이 필요한 경우에만 명시
   - 단, 반드시 SDP와 일치하도록 설정

---

**작성일**: 2025-12-19
**근거**: 실제 WebRTC 구현 경험 및 OpenAI 문서
