//
//  OpenAIRealtimeMessage.swift
//  AIProxy
//
//  Created by Lou Zell on 12/29/24.
//

public enum OpenAIRealtimeMessage {
    case error(String?)
    case sessionCreated // "session.created"
    case sessionUpdated // "session.updated"
    case responseCreated // "response.created"
    case responseAudioDelta(String) // "response.audio.delta"
    case inputAudioBufferSpeechStarted // "input_audio_buffer.speech_started"
    case responseFunctionCallArgumentsDone(String, String) // "response.function_call_arguments.done"
    
    // FIXED: Corrected event names to match OpenAI API
    case responseTranscriptDelta(String) // "response.audio_transcript.delta"
    case responseTranscriptDone(String) // "response.audio_transcript.done"
    case inputAudioBufferTranscript(String) // "input_audio_buffer.transcript"
    case inputAudioTranscriptionDelta(String) // "conversation.item.input_audio_transcription.delta"
    case inputAudioTranscriptionCompleted(String) // "conversation.item.input_audio_transcription.completed"
    
    // TRANSCRIPT EVENTS: Text output events for text-only responses
    case responseTextDelta(String) // "response.output_text.delta"
    case responseTextDone(String) // "response.output_text.done"
    
    // HIGH PRIORITY: Essential speech detection and completion events
    case inputAudioBufferSpeechStopped // "input_audio_buffer.speech_stopped"
    case inputAudioBufferCommitted // "input_audio_buffer.committed"
    case responseAudioDone // "response.audio.done"
    case responseDone // "response.done"
    
    // MEDIUM PRIORITY: Conversation management events
    case conversationItemCreated // "conversation.item.created"
    case conversationItemTruncated // "conversation.item.truncated"
    case responseOutputItemAdded // "response.output_item.added"
    case responseOutputItemDone // "response.output_item.done"
    case responseContentPartAdded // "response.content_part.added"
    case responseContentPartDone // "response.content_part.done"
    
    // MEDIUM PRIORITY: Failure handling events
    case conversationItemInputAudioTranscriptionFailed(String?) // "conversation.item.input_audio_transcription.failed"
    case responseAudioTranscriptFailed(String?) // "response.audio_transcript.failed"
    
    // LOW PRIORITY: System monitoring
    case rateLimitsUpdated // "rate_limits.updated"
}
