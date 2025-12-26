# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VoiceQuiz is an iOS native app built with SwiftUI that implements a voice-based speed quiz game. The app uses local Speech Recognition (STT) and Text-to-Speech (TTS) with GPT-4o-mini for AI responses.

**Key characteristics:**
- All UI text, voice prompts, and quiz content are in English
- Local STT/TTS for cost optimization ($0/game vs $0.24/game with Realtime API)
- Two game modes: AI describes/user guesses (Mode A) and user describes/AI guesses (Mode B)
- 60-second rounds with pass functionality (2 passes per round)
- Minimum iOS 16.0 support

## Development Commands

### Build and Run
- Open `VoiceQuiz.xcodeproj` in Xcode (NOT .xcworkspace - CocoaPods removed)
- Build: `Cmd+B` or Product > Build in Xcode
- Run: `Cmd+R` or Product > Run in Xcode

### Testing
- Run tests: `Cmd+U` or Product > Test in Xcode

## Architecture

### Tech Stack
- **Client:** iOS Native (SwiftUI, MVVM)
- **Speech Recognition:** Apple Speech Framework (on-device + server)
- **Text-to-Speech:** AVSpeechSynthesizer (native iOS)
- **Backend:** Google Cloud Run (REST API for GPT-4o-mini text generation)
- **AI Model:** GPT-4o-mini (text-based, not Realtime API)
- **Storage:** Local (user defaults/file system for scores and history)
- **Minimum iOS:** 16.0

### Module Structure

The codebase follows an MVVM architecture organized into these directories:

- `UI/` - SwiftUI views (HomeView, GameView_ModeA, GameView_ModeB, ResultView)
- `ViewModels/` - View models for MVVM pattern
- `Game/` - Game logic (rules, timer, scoring, state machine)
- `Audio/` - Speech recognition (STT), speech synthesis (TTS), audio session management
- `Network/` - REST API client for backend communication
- `Data/` - Word data (words.json), persistence layer, models
- `Realtime_Archived/` - Deprecated WebRTC code (archived for future use)

### Game Flow Architecture

**Mode A (AI describes → User guesses):**
1. Backend generates AI description via GPT-4o-mini
2. TTS speaks the description (AVSpeechSynthesizer)
3. STT listens for user's answer (Apple Speech Framework)
4. Local judgment: Correct (≥0.90 similarity) / Close (0.80-0.89) / Incorrect
5. On Correct: immediately move to next word
6. On Close/Incorrect: request new hint from backend, TTS speaks it

State machine: `AI_SPEAKING` → `STT_LISTENING` → `JUDGING` → `NEXT_WORD` or request new hint

**Mode B (User describes → AI guesses):**
1. User sees a word and describes it (STT captures speech)
2. Accumulated transcript sent to backend for AI guess
3. Backend returns AI's guess via GPT-4o-mini
4. TTS speaks the guess
5. User judges via buttons: Correct/Incorrect/Close
6. On Correct: score +1, next word
7. On Incorrect/Close: user continues describing (STT accumulates more)

**Critical Rule (Both Modes):** The guesser role (whether AI or user) can ONLY make guesses, never ask questions. No "Is it...?" allowed, only direct answer attempts.

### Audio Stack

- **STT:** Apple Speech Framework
  - `SpeechRecognizerService.swift` - Manages speech recognition
  - Provides `partialTranscript` and `finalTranscript`
  - Works on-device or with server for better accuracy

- **TTS:** AVSpeechSynthesizer
  - `SpeechSynthesizerService.swift` - Manages speech synthesis
  - English (US) voice by default
  - Can be interrupted/stopped

- **Audio Session:** AVAudioSession
  - `AudioSessionManager.swift` - Manages audio configuration
  - Category: `.playAndRecord`
  - Mode: `.voiceChat`
  - Options: `[.defaultToSpeaker]` (Bluetooth HFP auto-enabled by .voiceChat mode)
  - iOS 17+ uses AVAudioApplication API with #available checks

### Backend Architecture

Cloud Run backend (Node.js + Express) provides:
- `POST /modeA/describe` - AI generates word description
  - Request: `{ word, taboo, previousHints }`
  - Response: `{ text }` (GPT-4o-mini generated hint)

- `POST /modeB/guess` - AI guesses word from user description
  - Request: `{ transcriptSoFar, category, previousGuesses }`
  - Response: `{ guessText }` (GPT-4o-mini generated guess)

- `GET /health` - Health check endpoint
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

**Current Status: Phase 0 Complete (MVP v0.4 - Local STT/TTS)**

Completed phases:
- **Phase 0:** Infrastructure setup
  - ✅ Backend REST API (GPT-4o-mini integration)
  - ✅ Local STT/TTS services (Apple Speech + AVSpeechSynthesizer)
  - ✅ iOS 16.0+ compatibility with #available checks
  - ✅ Network layer (APIClient for modeA/modeB endpoints)
  - ✅ Data models (GameSession, WordResult, storage layer)

Next phases:
1. **Phase 1:** GameState/ViewModel implementation
   - Mode A: AI describes → User guesses flow
   - Mode B: User describes → AI guesses flow
   - Integrate STT/TTS/APIClient services

2. **Phase 2:** UI implementation
   - HomeView (mode selection, category selection)
   - GameView_ModeA and GameView_ModeB
   - ResultView (score, history)

3. **Phase 3:** Integration and testing
   - End-to-end flow testing
   - UX tuning (STT accuracy, TTS timing)

## Important Implementation Notes

### Audio Handling
- STT runs continuously during game rounds
- TTS can be interrupted when user starts speaking (Mode A)
- Partial transcript updates shown in real-time
- Final transcript used for judgment/backend requests

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
