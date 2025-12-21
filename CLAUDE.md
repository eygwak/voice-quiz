# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceQuiz is an iOS native app built with SwiftUI that implements a voice-based speed quiz game. The app uses OpenAI's Realtime API via WebRTC for real-time voice interaction, where either AI or the user can be the quiz host/guesser.

**Key characteristics:**
- All UI text, voice prompts, and quiz content are in English
- Real-time voice communication using WebRTC
- Two game modes: AI describes/user guesses (Mode A) and user describes/AI guesses (Mode B)
- 60-second rounds with pass functionality (2 passes per round)

## Development Commands

### Build and Run
- Open `VoiceQuiz.xcodeproj` in Xcode
- Build: `Cmd+B` or Product > Build in Xcode
- Run: `Cmd+R` or Product > Run in Xcode

### Testing
- Run tests: `Cmd+U` or Product > Test in Xcode

## Architecture

### Tech Stack
- **Client:** iOS Native (SwiftUI, MVVM)
- **Real-time Connection:** WebRTC (GoogleWebRTC SDK)
- **Backend:** Google Cloud Run (ephemeral token issuance + rate limiting)
- **Voice AI:** OpenAI Realtime API
- **Storage:** Local (user defaults/file system for scores and history)

### Module Structure

The codebase follows an MVVM architecture organized into these directories:

- `UI/` - SwiftUI views (HomeView, GameView_ModeA, GameView_ModeB, ResultView)
- `ViewModels/` - View models for MVVM pattern
- `Game/` - Game logic (rules, timer, scoring, state machine)
- `Realtime/` - WebRTC integration (PeerConnection, DataChannel)
- `Audio/` - AVAudioSession configuration and audio handling
- `Data/` - Word data (words.json), persistence layer

### Game Flow Architecture

**Mode A (AI describes → User guesses):**
1. AI speaks clues continuously (English)
2. User can interrupt at any time to guess (Always-on + Server VAD)
3. When user speaks, AI output immediately stops
4. Local judgment: Correct (≥0.90 similarity) / Close (0.80-0.89) / Incorrect
5. On Correct: immediately move to next word
6. On Close/Incorrect: AI continues describing

State machine: `AI_SPEAKING` → `USER_INTERRUPT` → `JUDGING` → `NEXT_WORD` or back to `AI_SPEAKING`

**Mode B (User describes → AI guesses):**
1. User sees a word and describes it freely (continuous speech)
2. AI makes guess attempts at intervals (minimum 1.5s, maximum 3s wait)
3. User judges via buttons: Correct/Incorrect/Close
4. On Correct: score +1, next word
5. On Incorrect/Close: user continues describing

**Critical Rule (Both Modes):** The guesser role (whether AI or user) can ONLY make guesses, never ask questions. No "Is it...?" allowed, only direct answer attempts.

### WebRTC Setup

- Uses GoogleWebRTC SDK
- Establishes both Audio Track and DataChannel
- Audio session configuration:
  - Category: `.playAndRecord`
  - Mode: `.voiceChat`
  - Options: `[.defaultToSpeaker, .allowBluetooth]`

### Backend Architecture

Cloud Run backend provides:
- `POST /realtime/token` endpoint
  - Request: `{ deviceId, platform, appVersion? }`
  - Response: `{ token, expiresAt }`
- Rate limiting (IP + deviceId)
- OpenAI API key storage (never exposed to client)
- Minimal logging (success/failure/latency/429 errors)

### Word Data Structure

Words are stored in `assets/words.json` with structure:
```json
{
  "categories": [
    {
      "name": "Food",
      "words": [
        {
          "word": "apple",
          "synonyms": ["fruit", "..."],
          "difficulty": 1,
          "taboo": ["red", "fruit"]
        }
      ]
    }
  ]
}
```

Categories: Food, Animals, Jobs, Objects, Minecraft

### Answer Judgment Logic

Local judgment thresholds:
- **Correct:** similarity ≥ 0.90 or exact match (after normalization)
- **Close:** similarity 0.80-0.89
- **Incorrect:** similarity < 0.80

Normalization: lowercase, strip punctuation/whitespace
Similarity: Levenshtein distance (normalized)

## Development Roadmap

Current phases:
1. **Phase 1:** Server + WebRTC connection (token API, audio transmission, DataChannel events)
2. **Phase 2:** Mode A completion (60s timer, interruption, local judgment, feedback)
3. **Phase 3:** Mode B MVP (word display, continuous description, AI guessing with interval logic, button judgment)
4. **Phase 4:** Tuning (VAD false positive/latency, Mode B guess interval optimization)

## Important Implementation Notes

### Audio Handling
- Always-on input with Server VAD is the default strategy
- Can fall back to Push-to-talk if UX is poor
- Real-time transcription only (no post-processing transcription)
- Display captions with streaming delta updates

### AI Description Rules (Mode A)
- Cannot use the target word, spelling, or direct synonyms
- Must use indirect, natural English descriptions like "You use this when..." or "You usually see this in..."
- Descriptions should be short and delivered in multiple segments if needed

### State Management
- Use MVVM pattern consistently
- Game state machine should handle: Round timing, Score tracking, Pass count (max 2), Word progression
- Local storage for: Best scores, Game history, Review transcripts (post-MVP)

## Reference Documents

Key planning documents in `Docs/`:
- `PRD-v0_3_1.md` - Product requirements (Korean)
- `voice-speed-quiz-tech-plan-v0_3_2-cloudrun.md` - Technical plan (Korean)

These documents contain the authoritative specifications for game rules, UX requirements, and technical architecture decisions.
