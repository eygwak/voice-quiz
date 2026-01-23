import "dotenv/config";
import express from "express";
import rateLimit from "express-rate-limit";

const app = express();
app.use(express.json());

// Rate limiting for API calls
const apiLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 100, // Max 100 requests per 10 min
  message: { error: "Too many requests, please try again later." },
  standardHeaders: true,
  legacyHeaders: false,
});

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) throw new Error("Missing OPENAI_API_KEY");

const PORT = process.env.PORT || 8080;

// Helper: Generate Mode A prompt (AI describes word)
function generateModeAPrompt(word, taboo, previousHints = []) {
  const tabooList = taboo.join(", ");
  const hintsContext = previousHints.length > 0
    ? `\n\nPrevious hints you gave:\n${previousHints.map((h, i) => `${i + 1}. ${h}`).join("\n")}`
    : "";

  return `You are the host of a speed quiz game. Describe the word "${word}" so the user can guess it.

Rules:
- NEVER say the target word, its spelling, or direct synonyms
- NEVER use these taboo words: ${tabooList}
- Use indirect, natural descriptions like "You use this when..." or "You usually see this in..."
- Keep descriptions SHORT (1-2 sentences)
- Give helpful hints based on what you said before${hintsContext}

Provide ONE additional hint in English.`;
}

// Helper: Generate Mode B prompt (AI guesses based on user description)
function generateModeBPrompt(transcript, category, previousGuesses = []) {
  const guessesContext = previousGuesses.length > 0
    ? `\n\nYour previous guesses (all were incorrect or close):\n${previousGuesses.join(", ")}`
    : "";

  return `You are a player in a speed quiz game. The user is describing a word from the "${category}" category.

User's description so far:
"${transcript}"${guessesContext}

Rules:
- NEVER ask questions.
- ONLY make ONE direct guess in the format: "Answer"
- Make educated guesses based on the clues.
- Try a different word if your previous guesses were wrong.
- If there is NOT enough information to make a new guess, respond with an EMPTY response (no text at all).
`;
}

// Mode A: AI describes word
app.post("/modeA/describe", apiLimiter, async (req, res) => {
  try {
    const { word, taboo, previousHints = [] } = req.body;

    if (!word || !Array.isArray(taboo)) {
      return res.status(400).json({ error: "Missing required fields: word, taboo" });
    }

    console.log(`[${new Date().toISOString()}] Mode A describe - word: ${word}`);

    const prompt = generateModeAPrompt(word, taboo, previousHints);

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7,
        max_tokens: 100,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error("OpenAI API error:", response.status, errText);
      return res.status(response.status).json({ error: "OpenAI API failed", details: errText });
    }

    const data = await response.json();
    const text = data.choices[0]?.message?.content || "";

    console.log(`[${new Date().toISOString()}] Mode A response: ${text.substring(0, 50)}...`);

    res.json({ text });
  } catch (error) {
    console.error("Mode A describe error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Mode B: AI guesses word
app.post("/modeB/guess", apiLimiter, async (req, res) => {
  try {
    const { transcriptSoFar, category, previousGuesses = [] } = req.body;

    if (!transcriptSoFar || !category) {
      return res.status(400).json({ error: "Missing required fields: transcriptSoFar, category" });
    }

    console.log(`[${new Date().toISOString()}] Mode B guess - category: ${category}, transcript: ${transcriptSoFar.substring(0, 50)}...`);

    const prompt = generateModeBPrompt(transcriptSoFar, category, previousGuesses);

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7,
        max_tokens: 50,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error("OpenAI API error:", response.status, errText);
      return res.status(response.status).json({ error: "OpenAI API failed", details: errText });
    }

    const data = await response.json();
    const guessText = data.choices[0]?.message?.content || "";

    console.log(`[${new Date().toISOString()}] Mode B guess: ${guessText}`);

    res.json({ guessText });
  } catch (error) {
    console.error("Mode B guess error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Mode B: English correction
app.post("/modeB/correct", apiLimiter, async (req, res) => {
  try {
    const { transcript, words } = req.body;

    if (!transcript || transcript.trim().length === 0) {
      return res.status(400).json({ error: "Missing or empty transcript" });
    }

    if (!words || !Array.isArray(words)) {
      return res.status(400).json({ error: "Missing or invalid words array" });
    }

    console.log(`[${new Date().toISOString()}] Mode B correction - transcript length: ${transcript.length}, words: ${words.length}`);

    const wordsList = words.join(", ");

    const prompt = `다음은 스피드퀴즈 게임 제시어와 출제자의 발화 내용이야. 출제자는 제시어를 직접 언급하지 않고 설명해야 해. 음성인식 오류가 있음을 감안하여 실제 발화내용을 예상하고, 예상한 내용을 기준으로 표현이 틀리거나 부자연스러운 영어는 자연스러운 영어 표현으로 고쳐줘. 고칠 것이 없다면 "모두 자연스러운 표현입니다." 라고 답해줘. 친근한 한국어 존댓말을 사용해줘.

제시어: ${wordsList}

출제자 발화 내용:
"${transcript}"`;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7,
        max_tokens: 500,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error("OpenAI API error:", response.status, errText);
      return res.status(response.status).json({ error: "OpenAI API failed", details: errText });
    }

    const data = await response.json();
    const correctionText = data.choices[0]?.message?.content || "";

    console.log(`[${new Date().toISOString()}] Mode B correction completed`);

    res.json({ correctionText });
  } catch (error) {
    console.error("Mode B correction error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
