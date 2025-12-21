import express from "express";

const app = express();
app.use(express.json());

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) throw new Error("Missing OPENAI_API_KEY");

const PORT = process.env.PORT || 8080;

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
- The taboo words for the current word are: ${tabooWords?.join(", ") || "none"}

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
  return "You are a helpful assistant.";
}

app.post("/token", async (req, res) => {
  try {
    const { deviceId, platform, appVersion, gameMode, currentWord, tabooWords } = req.body;

    console.log(`[${new Date().toISOString()}] Token request - device: ${deviceId}, mode: ${gameMode}, word: ${currentWord}`);

    // TODO: Rate limiting 구현 필요
    // ⚠️ 주의: Cloud Run은 여러 인스턴스로 스케일되므로 인메모리 방식은 우회 가능
    // 옵션 1 (MVP 간단): max-instances=1 설정 + 인메모리 (확장성 낮음)
    // 옵션 2 (권장): Redis/Firestore 기반 분산 rate limiting
    // await checkRateLimit(deviceId, req.ip);

    // Session config - WebRTC 환경에서는 format 필드 생략 권장
    const sessionConfig = {
      session: {
        type: "realtime",
        model: "gpt-realtime",
        instructions: generateInstructions(gameMode, currentWord, tabooWords),
        audio: {
          input: {
            // ⚠️ format 필드 생략 - WebRTC SDP 협상에서 자동 결정됨
            turn_detection: {
              type: "semantic_vad",
              // threshold: 0.5,  // 기본값, 필요시 조정
              // silence_duration_ms: 200,
              // prefix_padding_ms: 300,
            },
            transcription: {
              model: "whisper-1",
            },
          },
          output: {
            // ⚠️ format 필드 생략 - WebRTC SDP 협상에서 자동 결정됨
            voice: "marin",
          },
        },
      },
    };

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
      const errText = await response.text();
      console.error("OpenAI API error:", response.status, errText);
      return res.status(response.status).json({
        error: "client_secrets failed",
        details: errText,
      });
    }

    const data = await response.json();
    console.log(`[${new Date().toISOString()}] Token issued - expires: ${data.expires_at}`);

    res.json(data);
  } catch (error) {
    console.error("Token generation error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
