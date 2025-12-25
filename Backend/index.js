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
- NEVER ask questions like "Is it...?" or "Does it...?"
- ONLY make ONE direct guess in the format: "I think it is [WORD]" or simply "[WORD]"
- Make educated guesses based on the clues
- Try a different word if your previous guesses were wrong

Make your guess now in English (one word or short phrase only).`;
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

app.get("/health", (req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
