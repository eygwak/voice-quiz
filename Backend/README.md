# VoiceQuiz Token Server

Ephemeral token 발급을 위한 Cloud Run 백엔드 서버

## 로컬 개발

```bash
# 의존성 설치
npm install

# 환경 변수 설정
export OPENAI_API_KEY="sk-proj-..."

# 개발 서버 실행 (watch mode)
npm run dev

# 일반 실행
npm start
```

서버는 `http://localhost:8080`에서 실행됩니다.

## API 엔드포인트

### POST /token

Ephemeral token 발급

**요청:**
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

**응답:**
```json
{
  "value": "ek_68af296e8e408191a1120ab6383263c2",
  "expires_at": "2024-12-20T12:00:00Z"
}
```

### GET /health

Health check

**응답:**
```json
{
  "status": "ok",
  "timestamp": "2024-12-19T10:30:00.000Z"
}
```

## Docker 빌드

```bash
# 이미지 빌드
docker build -t voicequiz-server .

# 로컬 실행
docker run -p 8080:8080 -e OPENAI_API_KEY="sk-proj-..." voicequiz-server

# Health check
curl http://localhost:8080/health
```

## Cloud Run 배포

```bash
# gcloud CLI로 배포
gcloud run deploy voicequiz-server \
  --source . \
  --platform managed \
  --region asia-northeast3 \
  --allow-unauthenticated \
  --set-env-vars OPENAI_API_KEY="sk-proj-..."

# 또는 환경 변수를 Secret Manager에서 가져오기
gcloud run deploy voicequiz-server \
  --source . \
  --platform managed \
  --region asia-northeast3 \
  --allow-unauthenticated \
  --set-secrets OPENAI_API_KEY=openai-api-key:latest
```

## 환경 변수

- `OPENAI_API_KEY` (필수): OpenAI API 키
- `PORT` (옵션): 서버 포트 (기본값: 8080)
- `NODE_ENV` (옵션): 환경 (production/development)

## Rate Limiting 구현 (중요!)

Cloud Run은 자동으로 여러 인스턴스로 스케일되므로 **인메모리 rate limiting은 효과가 없습니다.**

### 옵션 1: 단일 인스턴스 + 인메모리 (MVP 간단)

**장점:**
- 구현 간단 (express-rate-limit 등)
- 추가 인프라 불필요

**단점:**
- 확장성 없음 (트래픽 증가 시 병목)
- Cold start 시 카운터 초기화

**설정:**
```bash
# Cloud Run 배포 시
gcloud run deploy voicequiz-server \
  --max-instances=1 \
  --min-instances=0 \
  # ... 기타 옵션
```

**코드 예시:**
```javascript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 100, // 최대 100 요청
  keyGenerator: (req) => {
    const deviceId = req.body.deviceId || 'unknown';
    return `${req.ip}-${deviceId}`;
  }
});

app.post("/token", limiter, async (req, res) => {
  // ...
});
```

### 옵션 2: Redis/Firestore 기반 (권장)

**장점:**
- 수평 확장 가능
- 여러 인스턴스 간 상태 공유
- 프로덕션 환경에 적합

**단점:**
- 추가 인프라 필요
- 비용 증가 (소량이지만)

#### A. Redis (Memorystore) 사용

**1. Memorystore 생성**
```bash
gcloud redis instances create voicequiz-redis \
  --size=1 \
  --region=asia-northeast3 \
  --tier=basic
```

**2. 의존성 추가**
```bash
npm install ioredis rate-limiter-flexible
```

**3. 코드 구현**
```javascript
import Redis from 'ioredis';
import { RateLimiterRedis } from 'rate-limiter-flexible';

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: 6379,
});

const rateLimiter = new RateLimiterRedis({
  storeClient: redis,
  keyPrefix: 'rl',
  points: 100, // 요청 수
  duration: 900, // 15분 (초 단위)
});

app.post("/token", async (req, res) => {
  const deviceId = req.body.deviceId || 'unknown';
  const key = `${req.ip}-${deviceId}`;

  try {
    await rateLimiter.consume(key);
    // 토큰 발급 로직...
  } catch (rejRes) {
    return res.status(429).json({
      error: "Too many requests",
      retryAfter: Math.ceil(rejRes.msBeforeNext / 1000)
    });
  }
});
```

#### B. Firestore 사용

**1. 의존성 추가**
```bash
npm install @google-cloud/firestore
```

**2. 코드 구현**
```javascript
import { Firestore } from '@google-cloud/firestore';

const firestore = new Firestore();

async function checkRateLimit(deviceId, ip) {
  const key = `${ip}-${deviceId}`;
  const now = Date.now();
  const windowMs = 15 * 60 * 1000; // 15분
  const maxRequests = 100;

  const docRef = firestore.collection('rate_limits').doc(key);

  return firestore.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);

    if (!doc.exists) {
      transaction.set(docRef, {
        count: 1,
        resetAt: now + windowMs
      });
      return true;
    }

    const data = doc.data();

    if (now > data.resetAt) {
      transaction.set(docRef, {
        count: 1,
        resetAt: now + windowMs
      });
      return true;
    }

    if (data.count >= maxRequests) {
      throw new Error('Rate limit exceeded');
    }

    transaction.update(docRef, {
      count: data.count + 1
    });
    return true;
  });
}

app.post("/token", async (req, res) => {
  try {
    await checkRateLimit(req.body.deviceId, req.ip);
    // 토큰 발급 로직...
  } catch (error) {
    if (error.message === 'Rate limit exceeded') {
      return res.status(429).json({ error: "Too many requests" });
    }
    throw error;
  }
});
```

### 권장 사항

| 단계 | 방법 | 이유 |
|------|------|------|
| MVP 초기 | 단일 인스턴스 + 인메모리 | 빠른 개발, 사용자 적음 |
| 베타 테스트 | Firestore | 설정 간단, GCP 통합 |
| 프로덕션 | Redis (Memorystore) | 성능 최적, 지연시간 낮음 |

## Session Config 참고

- **Audio format**: WebRTC SDP 협상에서 자동 결정 (Opus 코덱)
- **Turn detection**: `semantic_vad` (Server VAD 사용)
- **Transcription**: Whisper-1 모델
- **Voice**: marin

## 주의사항

1. **Format 필드**: WebRTC 환경에서는 `audio.input.format`, `audio.output.format` 필드를 **생략**하는 것이 권장됩니다. SDP 협상 과정에서 자동으로 코덱과 샘플링 레이트가 결정되며, 명시할 경우 충돌이 발생할 수 있습니다.

2. **Instructions**: `gameMode`에 따라 동적으로 생성되며, `currentWord`와 `tabooWords`가 포함됩니다. Mode A에서 단어가 변경될 때마다 새 토큰을 발급받아야 합니다.

3. **Rate Limiting**: MVP에서는 간단한 로깅만 구현되어 있습니다. 프로덕션에서는 IP + deviceId 기반 rate limiting 구현이 필요합니다.
