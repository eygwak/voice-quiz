//
//  RealtimeEvents.swift
//  VoiceQuiz
//
//  Realtime API Event definitions (Client & Server)
//

import Foundation

// MARK: - Client Events (Send to OpenAI)

struct ClientEvent: Codable {
    let type: String
}

struct SessionUpdateEvent: Codable {
    let type: String = "session.update"
    let session: SessionConfig

    struct SessionConfig: Codable {
        let type: String = "realtime"
        let audio: AudioConfig?

        struct AudioConfig: Codable {
            let input: InputConfig?

            struct InputConfig: Codable {
                let transcription: TranscriptionConfig?

                struct TranscriptionConfig: Codable {
                    let model: String
                }
            }
        }
    }
}

struct ConversationItemCreateEvent: Codable {
    let type: String = "conversation.item.create"
    let item: ConversationItem

    struct ConversationItem: Codable {
        let type: String
        let role: String?
        let content: [Content]?

        struct Content: Codable {
            let type: String
            let text: String?
        }
    }
}

struct ResponseCreateEvent: Codable {
    let type: String = "response.create"
    let response: ResponseConfig?

    struct ResponseConfig: Codable {
        let modalities: [String]?
        let instructions: String?
    }
}

struct ResponseCancelEvent: Codable {
    let type: String = "response.cancel"
}

// MARK: - Server Events (Receive from OpenAI)

enum ServerEventType: String, Codable {
    case sessionCreated = "session.created"
    case sessionUpdated = "session.updated"
    case conversationCreated = "conversation.created"
    case inputAudioBufferCommitted = "input_audio_buffer.committed"
    case inputAudioBufferCleared = "input_audio_buffer.cleared"
    case inputAudioBufferSpeechStarted = "input_audio_buffer.speech_started"
    case inputAudioBufferSpeechStopped = "input_audio_buffer.speech_stopped"
    case conversationItemCreated = "conversation.item.created"
    case conversationItemInputAudioTranscriptionCompleted = "conversation.item.input_audio_transcription.completed"
    case conversationItemInputAudioTranscriptionFailed = "conversation.item.input_audio_transcription.failed"
    case responseCreated = "response.created"
    case responseDone = "response.done"
    case responseOutputItemAdded = "response.output_item.added"
    case responseOutputItemDone = "response.output_item.done"
    case responseContentPartAdded = "response.content_part.added"
    case responseContentPartDone = "response.content_part.done"
    case responseAudioTranscriptDelta = "response.audio_transcript.delta"
    case responseAudioTranscriptDone = "response.audio_transcript.done"
    case responseAudioDelta = "response.audio.delta"
    case responseAudioDone = "response.audio.done"
    case rateLimitsUpdated = "rate_limits.updated"
    case error = "error"
}

struct ServerEvent: Codable {
    let type: String
    let eventId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
    }
}

struct SessionCreatedEvent: Codable {
    let type: String
    let eventId: String
    let session: Session

    struct Session: Codable {
        let id: String
        let object: String
        let model: String
        let modalities: [String]?
        let instructions: String?
        let voice: String?
        let inputAudioFormat: String?
        let outputAudioFormat: String?
        let inputAudioTranscription: InputAudioTranscription?
        let turnDetection: TurnDetection?

        struct InputAudioTranscription: Codable {
            let model: String?
        }

        struct TurnDetection: Codable {
            let type: String?
        }

        enum CodingKeys: String, CodingKey {
            case id, object, model, modalities, instructions, voice
            case inputAudioFormat = "input_audio_format"
            case outputAudioFormat = "output_audio_format"
            case inputAudioTranscription = "input_audio_transcription"
            case turnDetection = "turn_detection"
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case session
    }
}

struct InputAudioBufferSpeechStartedEvent: Codable {
    let type: String
    let eventId: String
    let audioStartMs: Int
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case audioStartMs = "audio_start_ms"
        case itemId = "item_id"
    }
}

struct InputAudioBufferSpeechStoppedEvent: Codable {
    let type: String
    let eventId: String
    let audioEndMs: Int
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case audioEndMs = "audio_end_ms"
        case itemId = "item_id"
    }
}

struct ConversationItemInputAudioTranscriptionCompletedEvent: Codable {
    let type: String
    let eventId: String
    let itemId: String
    let contentIndex: Int
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case itemId = "item_id"
        case contentIndex = "content_index"
        case transcript
    }
}

struct ResponseAudioTranscriptDeltaEvent: Codable {
    let type: String
    let eventId: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case delta
    }
}

struct ResponseAudioTranscriptDoneEvent: Codable {
    let type: String
    let eventId: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case transcript
    }
}

struct ErrorEvent: Codable {
    let type: String
    let eventId: String?
    let error: ErrorDetail

    struct ErrorDetail: Codable {
        let type: String?
        let code: String?
        let message: String?
        let param: String?
    }

    enum CodingKeys: String, CodingKey {
        case type
        case eventId = "event_id"
        case error
    }
}

// MARK: - Helper for parsing server events

enum RealtimeEvent {
    case sessionCreated(SessionCreatedEvent)
    case inputAudioBufferSpeechStarted(InputAudioBufferSpeechStartedEvent)
    case inputAudioBufferSpeechStopped(InputAudioBufferSpeechStoppedEvent)
    case conversationItemInputAudioTranscriptionCompleted(ConversationItemInputAudioTranscriptionCompletedEvent)
    case responseAudioTranscriptDelta(ResponseAudioTranscriptDeltaEvent)
    case responseAudioTranscriptDone(ResponseAudioTranscriptDoneEvent)
    case error(ErrorEvent)
    case unknown(ServerEvent)

    static func parse(from data: Data) -> RealtimeEvent? {
        let decoder = JSONDecoder()

        // First, decode the base event to get the type
        guard let baseEvent = try? decoder.decode(ServerEvent.self, from: data) else {
            return nil
        }

        // Then decode to specific event type
        switch baseEvent.type {
        case ServerEventType.sessionCreated.rawValue:
            if let event = try? decoder.decode(SessionCreatedEvent.self, from: data) {
                return .sessionCreated(event)
            }
        case ServerEventType.inputAudioBufferSpeechStarted.rawValue:
            if let event = try? decoder.decode(InputAudioBufferSpeechStartedEvent.self, from: data) {
                return .inputAudioBufferSpeechStarted(event)
            }
        case ServerEventType.inputAudioBufferSpeechStopped.rawValue:
            if let event = try? decoder.decode(InputAudioBufferSpeechStoppedEvent.self, from: data) {
                return .inputAudioBufferSpeechStopped(event)
            }
        case ServerEventType.conversationItemInputAudioTranscriptionCompleted.rawValue:
            if let event = try? decoder.decode(ConversationItemInputAudioTranscriptionCompletedEvent.self, from: data) {
                return .conversationItemInputAudioTranscriptionCompleted(event)
            }
        case ServerEventType.responseAudioTranscriptDelta.rawValue:
            if let event = try? decoder.decode(ResponseAudioTranscriptDeltaEvent.self, from: data) {
                return .responseAudioTranscriptDelta(event)
            }
        case ServerEventType.responseAudioTranscriptDone.rawValue:
            if let event = try? decoder.decode(ResponseAudioTranscriptDoneEvent.self, from: data) {
                return .responseAudioTranscriptDone(event)
            }
        case ServerEventType.error.rawValue:
            if let event = try? decoder.decode(ErrorEvent.self, from: data) {
                return .error(event)
            }
        default:
            return .unknown(baseEvent)
        }

        return .unknown(baseEvent)
    }
}
